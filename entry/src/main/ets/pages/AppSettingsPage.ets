import { PreferencesUtil } from '../utils/PreferencesUtil';
import { window } from '@kit.ArkUI';

@Component
struct AppSettingsPage {
  private pathStack: NavPathStack = new NavPathStack();
  @State accelerationFactor: number = 1.0;
  @State scrollAccelerationFactor: number = 0.5;
  @State topSafeHeight: number = 0;
  @State bottomSafeHeight: number = 0;

  aboutToAppear(): void {
    let context = getContext(this);
    this.accelerationFactor = PreferencesUtil.loadGlobalAccelerationFactor(context);
    this.scrollAccelerationFactor = PreferencesUtil.loadGlobalScrollAccelerationFactor(context);
    window.getLastWindow(context).then((win: window.Window) => {
      let systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeHeight = px2vp(systemArea.topRect.height);
      let indicatorArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomSafeHeight = px2vp(indicatorArea.bottomRect.height);
    });
  }

  private save(): void {
    let context = getContext(this);
    PreferencesUtil.saveGlobalAccelerationFactor(context, this.accelerationFactor);
    PreferencesUtil.saveGlobalScrollAccelerationFactor(context, this.scrollAccelerationFactor);
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('< 返回')
            .fontSize(16)
            .fontColor($r('app.color.brand'))
            .onClick(() => {
              this.pathStack.pop();
            })
          Blank()
          Text('应用设置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Row()
            .width(48)
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        Column() {
          Text('加速度配置')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: 8 })

          Text('低速滑动保持1:1精准定位，高速滑动时系数逐步生效。系数越大，快速滑动时偏移量越大。')
            .fontSize(13)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ bottom: 20 })

          Row() {
            Text('移动加速度')
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text(this.accelerationFactor.toFixed(2))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand'))
          }
          .width('100%')
          .margin({ bottom: 8 })

          Slider({
            value: this.accelerationFactor,
            min: 0.1,
            max: 5.0,
            step: 0.1,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .trackColor($r('app.color.divider'))
            .selectedColor($r('app.color.brand'))
            .onChange((value: number) => {
              this.accelerationFactor = Math.round(value * 100) / 100;
              this.save();
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
            Text(this.scrollAccelerationFactor.toFixed(2))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand'))
          }
          .width('100%')
          .margin({ bottom: 8 })

          Slider({
            value: this.scrollAccelerationFactor,
            min: 0.1,
            max: 5.0,
            step: 0.1,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .trackColor($r('app.color.divider'))
            .selectedColor($r('app.color.brand'))
            .onChange((value: number) => {
              this.scrollAccelerationFactor = Math.round(value * 100) / 100;
              this.save();
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
              .fontSize(14)
              .height(40)
              .type(ButtonType.Normal)
              .borderRadius(20)
              .backgroundColor($r('app.color.cancel_background'))
              .fontColor($r('app.color.text_primary'))
              .onClick(() => {
                this.accelerationFactor = 1.0;
                this.scrollAccelerationFactor = 0.5;
                this.save();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 24 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .margin({ top: 16, left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
      .padding({ top: this.topSafeHeight, bottom: this.bottomSafeHeight })
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Builder
export function AppSettingsPageBuilder() {
  AppSettingsPage()
}
