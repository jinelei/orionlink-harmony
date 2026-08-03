import { ServerConfig } from '../model/ServerConfig';
import { OrionLinkClient } from '../utils/OrionLinkClient';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { window } from '@kit.ArkUI';

interface DebugLog {
  time: string;
  source: string;
  message: string;
}

@Component
struct MainContentPage {
  private pathStack: NavPathStack = new NavPathStack();
  @State serverConfig: ServerConfig = new ServerConfig('', '', '', 0);
  @State connected: boolean = false;
  @State debugLogs: Array<DebugLog> = [];
  @State touchInfo: string = '';
  @State logExpanded: boolean = true;
  @State showAccelDialog: boolean = false;
  @State localAccelFactor: number = 1.0;
  @State localScrollAccelFactor: number = 1.0;
  @State topSafeHeight: number = 0;
  @State bottomSafeHeight: number = 0;
  private client: OrionLinkClient = new OrionLinkClient();
  private lastX: number = 0;
  private lastY: number = 0;
  private downX: number = 0;
  private downY: number = 0;
  private downTime: number = 0;
  private isTouching: boolean = false;
  private moveCount: number = 0;
  private isTwoFinger: boolean = false;
  private twoFingerMoved: boolean = false;
  private lastFinger0X: number = 0;
  private lastFinger0Y: number = 0;
  private lastFinger1X: number = 0;
  private lastFinger1Y: number = 0;
  private twoFingerDown0X: number = 0;
  private twoFingerDown0Y: number = 0;
  private twoFingerDown1X: number = 0;
  private twoFingerDown1Y: number = 0;
  private twoFingerDownTime: number = 0;
  private lastMoveTime: number = 0;
  private lastTwoFingerMoveTime: number = 0;

  private readonly CLICK_DURATION_THRESHOLD: number = 150;
  private readonly CLICK_DISTANCE_THRESHOLD: number = 10;
  private readonly SIGMOID_V50: number = 0.5;
  private readonly SIGMOID_K: number = 10.0;

  aboutToAppear(): void {
    let context = getContext(this);
    let globalFactor = PreferencesUtil.loadGlobalAccelerationFactor(context);
    this.localAccelFactor = this.serverConfig.accelerationFactor > 0 ? this.serverConfig.accelerationFactor : globalFactor;
    let globalScrollFactor = PreferencesUtil.loadGlobalScrollAccelerationFactor(context);
    this.localScrollAccelFactor = this.serverConfig.scrollAccelerationFactor > 0 ? this.serverConfig.scrollAccelerationFactor : globalScrollFactor;
    window.getLastWindow(context).then((win: window.Window) => {
      let systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeHeight = px2vp(systemArea.topRect.height);
      let indicatorArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomSafeHeight = px2vp(indicatorArea.bottomRect.height);
    });
  }

  aboutToDisappear(): void {
    this.client.close();
  }

  private async doConnect(): Promise<void> {
    if (this.connected) {
      return;
    }
    let ok = await this.client.connect(this.serverConfig.ip, this.serverConfig.port);
    this.connected = ok;
    this.addLog('系统', ok ? `已连接 ${this.serverConfig.ip}:${this.serverConfig.port}` : `连接失败 ${this.serverConfig.ip}:${this.serverConfig.port}`);
  }

  private addLog(source: string, message: string): void {
    let now = new Date();
    let time = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}.${now.getMilliseconds().toString().padStart(3, '0')}`;
    let log: DebugLog = { time: time, source: source, message: message };
    this.debugLogs.unshift(log);
    if (this.debugLogs.length > 200) {
      this.debugLogs.splice(200);
    }
  }

  private computeEffectiveFactor(dx: number, dy: number, deltaTime: number, factor: number): number {
    if (deltaTime <= 0) {
      return 1.0;
    }
    let distance = Math.sqrt(dx * dx + dy * dy);
    let speed = distance / deltaTime;
    let t = 1.0 / (1.0 + Math.exp(-this.SIGMOID_K * (speed - this.SIGMOID_V50)));
    return 1.0 + (factor - 1.0) * t;
  }

  private async handleTouchDown(x: number, y: number): Promise<void> {
    this.lastX = x;
    this.lastY = y;
    this.downX = x;
    this.downY = y;
    this.downTime = Date.now();
    this.lastMoveTime = Date.now();
    this.isTouching = true;
    this.moveCount = 0;
    this.touchInfo = `DOWN (${x.toFixed(0)}, ${y.toFixed(0)})`;
    this.addLog('触摸', `按下 (${x.toFixed(0)}, ${y.toFixed(0)})`);
  }

  private handleTouchMove(x: number, y: number): void {
    if (!this.isTouching) {
      return;
    }
    let now = Date.now();
    let dx = x - this.lastX;
    let dy = y - this.lastY;
    let deltaTime = now - this.lastMoveTime;
    this.lastX = x;
    this.lastY = y;
    this.lastMoveTime = now;
    this.moveCount++;
    let effectiveFactor = this.computeEffectiveFactor(dx, dy, deltaTime, this.localAccelFactor);
    let accelDx = Math.round(dx * effectiveFactor);
    let accelDy = Math.round(dy * effectiveFactor);
    this.touchInfo = `MOVE #${this.moveCount} Δ(${accelDx}, ${accelDy}) ×${effectiveFactor.toFixed(2)}`;
    this.client.sendMove(accelDx, accelDy);
  }

  private async handleTouchUp(x: number, y: number): Promise<void> {
    if (!this.isTouching) {
      return;
    }
    this.isTouching = false;
    let elapsed = Date.now() - this.downTime;
    let dx = x - this.downX;
    let dy = y - this.downY;
    let distance = Math.sqrt(dx * dx + dy * dy);
    this.touchInfo = `UP (移动${this.moveCount}次)`;
    this.addLog('触摸', `抬起 (移动${this.moveCount}次)`);
    if (elapsed < this.CLICK_DURATION_THRESHOLD && distance < this.CLICK_DISTANCE_THRESHOLD) {
      let ok = await this.client.sendClick('left');
      let sendMsg = `ORIONLINK|{"t":"click","button":"left"}`;
      if (ok) {
        this.addLog('发送', sendMsg);
      } else {
        this.addLog('发送失败', sendMsg);
      }
    }
    this.moveCount = 0;
  }

  private handleTwoFingerMove(finger0X: number, finger0Y: number, finger1X: number, finger1Y: number): void {
    let now = Date.now();
    let dx0 = finger0X - this.lastFinger0X;
    let dy0 = finger0Y - this.lastFinger0Y;
    let dx1 = finger1X - this.lastFinger1X;
    let dy1 = finger1Y - this.lastFinger1Y;
    let avgDx = (dx0 + dx1) / 2;
    let avgDy = (dy0 + dy1) / 2;
    let deltaTime = now - this.lastTwoFingerMoveTime;
    this.lastFinger0X = finger0X;
    this.lastFinger0Y = finger0Y;
    this.lastFinger1X = finger1X;
    this.lastFinger1Y = finger1Y;
    this.lastTwoFingerMoveTime = now;
    let effectiveFactor = this.computeEffectiveFactor(avgDx, avgDy, deltaTime, this.localScrollAccelFactor);
    let sendDx = Math.round(avgDx * effectiveFactor);
    let sendDy = Math.round(avgDy * effectiveFactor);
    if (sendDy === 0 && sendDx === 0) {
      return;
    }
    this.twoFingerMoved = true;
    this.touchInfo = `SCROLL Δ(${sendDx}, ${sendDy}) ×${effectiveFactor.toFixed(2)}`;
    this.client.sendScroll(sendDx, sendDy);
  }

  private async handleTwoFingerUp(): Promise<void> {
    if (!this.isTwoFinger) {
      return;
    }
    this.isTwoFinger = false;
    let elapsed = Date.now() - this.twoFingerDownTime;
    let d0x = this.lastFinger0X - this.twoFingerDown0X;
    let d0y = this.lastFinger0Y - this.twoFingerDown0Y;
    let d1x = this.lastFinger1X - this.twoFingerDown1X;
    let d1y = this.lastFinger1Y - this.twoFingerDown1Y;
    let dist0 = Math.sqrt(d0x * d0x + d0y * d0y);
    let dist1 = Math.sqrt(d1x * d1x + d1y * d1y);
    if (!this.twoFingerMoved && elapsed < this.CLICK_DURATION_THRESHOLD &&
        dist0 < this.CLICK_DISTANCE_THRESHOLD && dist1 < this.CLICK_DISTANCE_THRESHOLD) {
      this.touchInfo = 'RIGHT CLICK';
      this.addLog('触摸', '双指点击→右键');
      let ok = await this.client.sendClick('right');
      let sendMsg = `ORIONLINK|{"t":"click","button":"right"}`;
      if (ok) {
        this.addLog('发送', sendMsg);
      } else {
        this.addLog('发送失败', sendMsg);
      }
    } else {
      this.touchInfo = 'SCROLL END';
      this.addLog('触摸', '双指滚动结束');
    }
    this.twoFingerMoved = false;
  }

  private saveAccelConfig(): void {
    let context = getContext(this);
    if (this.serverConfig.id.length > 0) {
      this.serverConfig.accelerationFactor = this.localAccelFactor;
      this.serverConfig.scrollAccelerationFactor = this.localScrollAccelFactor;
      let serverList = PreferencesUtil.loadServerList(context);
      for (let i = 0; i < serverList.length; i++) {
        if (serverList[i].id === this.serverConfig.id) {
          serverList[i].accelerationFactor = this.localAccelFactor;
          serverList[i].scrollAccelerationFactor = this.localScrollAccelFactor;
          break;
        }
      }
      PreferencesUtil.saveServerList(context, serverList);
    }
  }

  build() {
    NavDestination() {
      Column() {
        Column()
          .width('100%')
          .height(this.topSafeHeight)
          .backgroundColor($r('app.color.toolbar_background'))

        Row() {
          Row()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor(this.connected ? $r('app.color.status_connected') : $r('app.color.status_disconnected'))

          Text(this.connected ? '已连接' : '未连接')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 6 })

          Text(`${this.serverConfig.ip}:${this.serverConfig.port}`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 12 })

          Blank()

          Text(this.touchInfo)
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8, right: 8 })

          Text('⚙')
            .fontSize(22)
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.showAccelDialog = true;
            })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.toolbar_background'))
        .alignItems(VerticalAlign.Center)

        Column() {
          Text('触摸控制区')
            .fontSize(20)
            .fontColor($r('app.color.text_hint'))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.touch_area_background'))
        .onTouch((event: TouchEvent) => {
          let fingerCount = event.touches.length;
          if (fingerCount >= 2) {
            if (!this.isTwoFinger) {
              this.isTwoFinger = true;
              this.isTouching = false;
              this.twoFingerMoved = false;
              let t0 = event.touches[0];
              let t1 = event.touches[1];
              this.lastFinger0X = t0.x;
              this.lastFinger0Y = t0.y;
              this.lastFinger1X = t1.x;
              this.lastFinger1Y = t1.y;
              this.twoFingerDown0X = t0.x;
              this.twoFingerDown0Y = t0.y;
              this.twoFingerDown1X = t1.x;
              this.twoFingerDown1Y = t1.y;
              this.twoFingerDownTime = Date.now();
              this.lastTwoFingerMoveTime = Date.now();
              this.touchInfo = '2-FINGER DOWN';
              this.addLog('触摸', '双指按下');
            }
            if (event.type === TouchType.Move) {
              let t0 = event.touches[0];
              let t1 = event.touches[1];
              this.handleTwoFingerMove(t0.x, t0.y, t1.x, t1.y);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.handleTwoFingerUp();
            }
          } else {
            if (this.isTwoFinger) {
              this.handleTwoFingerUp();
              return;
            }
            if (event.type === TouchType.Down) {
              let touch = event.touches[0];
              this.handleTouchDown(touch.x, touch.y);
            } else if (event.type === TouchType.Move) {
              let touch = event.touches[0];
              this.handleTouchMove(touch.x, touch.y);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              let touch = event.touches[0];
              this.handleTouchUp(touch.x, touch.y);
            }
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
      .bindContentCover(this.showAccelDialog, this.accelConfigDialog(), {
        modalTransition: ModalTransition.NONE,
        onDisappear: () => {
          this.showAccelDialog = false;
        }
      })
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      let param = context.pathInfo.param as ServerConfig;
      if (param) {
        this.serverConfig = param;
      }
      this.doConnect();
    })
  }

  @Builder
  accelConfigDialog() {
    Column() {
      Column() {
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })
        Text(this.serverConfig.id.length > 0 ? `${this.serverConfig.name}` : '快速连接模式')
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ bottom: 20 })

        Text('加速度配置')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        Text('低速滑动保持1:1精准定位，高速滑动时系数逐步生效')
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ bottom: 16 })

        Row() {
          Text('移动加速度')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text(this.localAccelFactor.toFixed(2))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand'))
        }
        .width('100%')
        .margin({ bottom: 8 })

        Slider({
          value: this.localAccelFactor,
          min: 0.1,
          max: 5.0,
          step: 0.1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .trackColor($r('app.color.divider'))
          .selectedColor($r('app.color.brand'))
          .onChange((value: number) => {
            this.localAccelFactor = Math.round(value * 100) / 100;
          })

        Row() {
          Text('0.1')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
          Blank()
          Text('5.0')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .margin({ top: 4, bottom: 16 })

        Row() {
          Text('滚动加速度')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text(this.localScrollAccelFactor.toFixed(2))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand'))
        }
        .width('100%')
        .margin({ bottom: 8 })

        Slider({
          value: this.localScrollAccelFactor,
          min: 0.1,
          max: 5.0,
          step: 0.1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .trackColor($r('app.color.divider'))
          .selectedColor($r('app.color.brand'))
          .onChange((value: number) => {
            this.localScrollAccelFactor = Math.round(value * 100) / 100;
          })

        Row() {
          Text('0.1')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
          Blank()
          Text('5.0')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .margin({ top: 4 })

        Row() {
          Button('重置')
            .width('30%')
            .height(40)
            .fontSize(14)
            .type(ButtonType.Normal)
            .borderRadius(20)
            .backgroundColor($r('app.color.cancel_background'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.localAccelFactor = 1.0;
              this.localScrollAccelFactor = 1.0;
            })

          Button('保存')
            .width('30%')
            .height(40)
            .fontSize(14)
            .type(ButtonType.Normal)
            .borderRadius(20)
            .backgroundColor($r('app.color.brand'))
            .fontColor($r('app.color.brand_text'))
            .onClick(() => {
              this.saveAccelConfig();
              this.showAccelDialog = false;
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 24 })

        Divider()
          .margin({ top: 20, bottom: 12 })
          .color($r('app.color.divider'))

        Row() {
          Text('调试日志')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text(`共${this.debugLogs.length}条`)
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ right: 8 })
          Text(this.logExpanded ? '▼' : '▲')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .onClick(() => {
          this.logExpanded = !this.logExpanded;
        })

        if (this.logExpanded) {
          List() {
            ForEach(this.debugLogs, (log: DebugLog, index: number) => {
              ListItem() {
                Row() {
                  Text(log.time)
                    .fontSize(11)
                    .fontColor($r('app.color.log_time'))
                    .width(80)
                  Text(`[${log.source}]`)
                    .fontSize(11)
                    .fontColor(log.source === '发送失败' ? $r('app.color.log_source_error') : $r('app.color.log_source_normal'))
                    .width(60)
                  Text(log.message)
                    .fontSize(11)
                    .fontColor($r('app.color.log_message'))
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              }
            }, (log: DebugLog, index: number) => `${log.time}_${index}`)
          }
          .width('100%')
          .height(200)
          .divider({ strokeWidth: 0.5, color: $r('app.color.divider') })
          .margin({ top: 8 })
        }
      }
      .width('90%')
      .padding(20)
      .backgroundColor($r('app.color.dialog_background'))
      .borderRadius(16)
      .border({ width: 1, color: $r('app.color.dialog_border') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.modal_scrim'))
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showAccelDialog = false;
    })
  }
}

@Builder
export function MainContentPageBuilder() {
  MainContentPage()
}
