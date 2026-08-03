import { ServerConfig } from '../model/ServerConfig';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { window } from '@kit.ArkUI';

@Component
struct ServerListPage {
  private pathStack: NavPathStack = new NavPathStack();
  @State serverList: Array<ServerConfig> = [];
  @State inputName: string = '';
  @State inputIp: string = '';
  @State inputPort: string = '';
  @State showDialog: boolean = false;
  @State topSafeHeight: number = 0;
  @State bottomSafeHeight: number = 0;

  aboutToAppear(): void {
    this.loadServers();
    let context = getContext(this);
    window.getLastWindow(context).then((win: window.Window) => {
      let systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeHeight = px2vp(systemArea.topRect.height);
      let indicatorArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomSafeHeight = px2vp(indicatorArea.bottomRect.height);
    });
  }

  private loadServers(): void {
    let context = getContext(this);
    this.serverList = PreferencesUtil.loadServerList(context);
  }

  private addServer(): void {
    if (this.inputIp === '' || this.inputPort === '') {
      return;
    }
    let port = parseInt(this.inputPort, 10);
    if (isNaN(port) || port <= 0 || port > 65535) {
      return;
    }
    let id = Date.now().toString();
    let name = this.inputName.length > 0 ? this.inputName : `${this.inputIp}:${this.inputPort}`;
    let config = new ServerConfig(id, name, this.inputIp, port);
    this.serverList.push(config);
    let context = getContext(this);
    PreferencesUtil.saveServerList(context, this.serverList);
    this.inputName = '';
    this.inputIp = '';
    this.inputPort = '';
    this.showDialog = false;
  }

  private deleteServer(index: number): void {
    this.serverList.splice(index, 1);
    let context = getContext(this);
    PreferencesUtil.saveServerList(context, this.serverList);
  }

  private connectServer(config: ServerConfig): void {
    this.pathStack.pushPathByName('MainContent', config);
  }

  private connectManual(): void {
    if (this.inputIp === '' || this.inputPort === '') {
      return;
    }
    let port = parseInt(this.inputPort, 10);
    if (isNaN(port) || port <= 0 || port > 65535) {
      return;
    }
    let config = new ServerConfig('', '', this.inputIp, port);
    this.pathStack.pushPathByName('MainContent', config);
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('OrionLink')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text('⚙')
            .fontSize(24)
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.pathStack.pushPathByName('AppSettings', null);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ top: 20, bottom: 8 })
        Text('选择服务器连接')
          .fontSize(16)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ bottom: 20 })

        if (this.serverList.length > 0) {
          List({ space: 12 }) {
            ForEach(this.serverList, (item: ServerConfig, index: number) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(item.name)
                      .fontSize(18)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${item.ip}:${item.port}`)
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Button('连接')
                    .fontSize(14)
                    .height(36)
                    .type(ButtonType.Normal)
                    .borderRadius(18)
                    .onClick(() => {
                      this.connectServer(item);
                    })

                  Button('删除')
                    .fontSize(14)
                    .height(36)
                    .type(ButtonType.Normal)
                    .borderRadius(18)
                    .backgroundColor($r('app.color.error'))
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.deleteServer(index);
                    })
                }
                .width('100%')
                .padding(16)
                .backgroundColor($r('app.color.card_background'))
                .borderRadius(12)
                .shadow({ radius: 2, color: $r('app.color.card_shadow'), offsetY: 1 })
              }
            }, (item: ServerConfig) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .margin({ bottom: 12 })
        } else {
          Column() {
            Text('暂无已保存的服务器')
              .fontSize(16)
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }

        Column() {
          Button('添加服务器')
            .width('100%')
            .height(48)
            .fontSize(16)
            .type(ButtonType.Normal)
            .borderRadius(24)
            .onClick(() => {
              this.showDialog = true;
            })

          Row() {
            TextInput({ placeholder: 'IP地址' })
              .type(InputType.Normal)
              .width('45%')
              .height(44)
              .fontColor($r('app.color.text_input'))
              .onChange((value: string) => {
                this.inputIp = value;
              })

            TextInput({ placeholder: '端口' })
              .type(InputType.Number)
              .width('45%')
              .height(44)
              .fontColor($r('app.color.text_input'))
              .onChange((value: string) => {
                this.inputPort = value;
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: 12 })

          Button('快速连接')
            .width('100%')
            .height(44)
            .fontSize(14)
            .type(ButtonType.Normal)
            .borderRadius(22)
            .backgroundColor($r('app.color.success'))
            .margin({ top: 12 })
            .onClick(() => {
              this.connectManual();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
      .padding({ top: this.topSafeHeight, bottom: this.bottomSafeHeight })
      .bindContentCover(this.showDialog, this.addServerDialog(), {
        modalTransition: ModalTransition.NONE,
        onDisappear: () => {
          this.showDialog = false;
        }
      })
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  @Builder
  addServerDialog() {
    Column() {
      Column() {
        Text('添加服务器')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })
        Text('配置服务器连接信息，名称可留空')
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ bottom: 20 })

        Text('服务器名称')
          .fontSize(14)
          .fontColor($r('app.color.text_label'))
          .margin({ bottom: 4 })
        TextInput({ placeholder: '例如：生产环境、测试服务器' })
          .width('100%')
          .height(48)
          .backgroundColor($r('app.color.input_background'))
          .fontColor($r('app.color.text_input'))
          .onChange((value: string) => {
            this.inputName = value;
          })

        Text('IP地址')
          .fontSize(14)
          .fontColor($r('app.color.text_label'))
          .margin({ top: 12, bottom: 4 })
        TextInput({ placeholder: '例如：192.168.1.100' })
          .width('100%')
          .height(48)
          .backgroundColor($r('app.color.input_background'))
          .fontColor($r('app.color.text_input'))
          .onChange((value: string) => {
            this.inputIp = value;
          })

        Text('端口号')
          .fontSize(14)
          .fontColor($r('app.color.text_label'))
          .margin({ top: 12, bottom: 4 })
        TextInput({ placeholder: '例如：8080' })
          .type(InputType.Number)
          .width('100%')
          .height(48)
          .backgroundColor($r('app.color.input_background'))
          .fontColor($r('app.color.text_input'))
          .onChange((value: string) => {
            this.inputPort = value;
          })

        Row() {
          Button('取消')
            .width('45%')
            .height(44)
            .fontSize(16)
            .type(ButtonType.Normal)
            .borderRadius(22)
            .backgroundColor($r('app.color.cancel_background'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.showDialog = false;
            })

          Button('保存')
            .width('45%')
            .height(44)
            .fontSize(16)
            .type(ButtonType.Normal)
            .borderRadius(22)
            .backgroundColor($r('app.color.brand'))
            .fontColor($r('app.color.brand_text'))
            .onClick(() => {
              this.addServer();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 24 })
      }
      .width('90%')
      .padding(24)
      .backgroundColor($r('app.color.dialog_background'))
      .borderRadius(16)
      .border({ width: 1, color: $r('app.color.dialog_border') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.modal_scrim'))
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showDialog = false;
    })
  }
}

@Builder
export function ServerListPageBuilder() {
  ServerListPage()
}
