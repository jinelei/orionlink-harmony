import { ServerConfig } from '../model/ServerConfig';
import { OrionLinkClient } from '../utils/OrionLinkClient';

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
  private client: OrionLinkClient = new OrionLinkClient();
  private lastX: number = 0;
  private lastY: number = 0;
  private downX: number = 0;
  private downY: number = 0;
  private downTime: number = 0;
  private isTouching: boolean = false;
  private moveCount: number = 0;
  private isTwoFinger: boolean = false;
  private lastFinger0X: number = 0;
  private lastFinger0Y: number = 0;
  private lastFinger1X: number = 0;
  private lastFinger1Y: number = 0;

  private readonly CLICK_DURATION_THRESHOLD: number = 150;
  private readonly CLICK_DISTANCE_THRESHOLD: number = 10;

  aboutToAppear(): void {
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

  private async handleTouchDown(x: number, y: number): Promise<void> {
    this.lastX = x;
    this.lastY = y;
    this.downX = x;
    this.downY = y;
    this.downTime = Date.now();
    this.isTouching = true;
    this.moveCount = 0;
    this.touchInfo = `DOWN (${x.toFixed(0)}, ${y.toFixed(0)})`;
    this.addLog('触摸', `按下 (${x.toFixed(0)}, ${y.toFixed(0)})`);
  }

  private handleTouchMove(x: number, y: number): void {
    if (!this.isTouching) {
      return;
    }
    let dx = x - this.lastX;
    let dy = y - this.lastY;
    this.lastX = x;
    this.lastY = y;
    this.moveCount++;
    this.touchInfo = `MOVE #${this.moveCount} Δ(${dx.toFixed(0)}, ${dy.toFixed(0)})`;
    this.client.sendMove(Math.round(dx), Math.round(dy));
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
    let dx0 = finger0X - this.lastFinger0X;
    let dy0 = finger0Y - this.lastFinger0Y;
    let dx1 = finger1X - this.lastFinger1X;
    let dy1 = finger1Y - this.lastFinger1Y;
    let avgDy = Math.round((dy0 + dy1) / 2);
    let avgDx = Math.round((dx0 + dx1) / 2);
    this.lastFinger0X = finger0X;
    this.lastFinger0Y = finger0Y;
    this.lastFinger1X = finger1X;
    this.lastFinger1Y = finger1Y;
    if (avgDy === 0 && avgDx === 0) {
      return;
    }
    this.touchInfo = `SCROLL Δ(${avgDx}, ${avgDy})`;
    this.client.sendScroll(avgDx, avgDy);
  }

  build() {
    NavDestination() {
      Column() {
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
              let t0 = event.touches[0];
              let t1 = event.touches[1];
              this.lastFinger0X = t0.x;
              this.lastFinger0Y = t0.y;
              this.lastFinger1X = t1.x;
              this.lastFinger1Y = t1.y;
              this.touchInfo = 'SCROLL START';
              this.addLog('触摸', '双指滚动开始');
            }
            if (event.type === TouchType.Move) {
              let t0 = event.touches[0];
              let t1 = event.touches[1];
              this.handleTwoFingerMove(t0.x, t0.y, t1.x, t1.y);
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.isTwoFinger = false;
              this.touchInfo = 'SCROLL END';
              this.addLog('触摸', '双指滚动结束');
            }
          } else {
            if (this.isTwoFinger) {
              this.isTwoFinger = false;
              this.touchInfo = 'SCROLL END';
              this.addLog('触摸', '双指滚动结束');
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

        Column() {
          Row() {
            Text('调试日志')
              .fontSize(14)
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
          .padding({ left: 12, right: 12 })
          .height(32)
          .alignItems(VerticalAlign.Center)
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
                  .padding({ left: 12, right: 12, top: 2, bottom: 2 })
                }
              }, (log: DebugLog, index: number) => `${log.time}_${index}`)
            }
            .width('100%')
            .height(180)
            .divider({ strokeWidth: 0.5, color: $r('app.color.divider') })
          }
        }
        .width('100%')
        .backgroundColor($r('app.color.log_panel_background'))
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
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
}

@Builder
export function MainContentPageBuilder() {
  MainContentPage()
}
