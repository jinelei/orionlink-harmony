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
  private client: OrionLinkClient = new OrionLinkClient();
  private lastX: number = 0;
  private lastY: number = 0;
  private isTouching: boolean = false;
  private moveCount: number = 0;
  private lastMoveTime: number = 0;

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

  private async handleTouchUp(): Promise<void> {
    if (!this.isTouching) {
      return;
    }
    this.isTouching = false;
    this.touchInfo = `UP (移动${this.moveCount}次)`;
    this.addLog('触摸', `抬起 (移动${this.moveCount}次)`);
    if (this.moveCount <= 2) {
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
          if (event.type === TouchType.Down) {
            let touch = event.touches[0];
            this.handleTouchDown(touch.x, touch.y);
          } else if (event.type === TouchType.Move) {
            let touch = event.touches[0];
            this.handleTouchMove(touch.x, touch.y);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.handleTouchUp();
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
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .height(32)
          .alignItems(VerticalAlign.Center)

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
        .width('100%')
        .backgroundColor($r('app.color.log_panel_background'))
        .border({ width: 1, color: $r('app.color.border') })
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
