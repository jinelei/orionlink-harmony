import { ServerListPageBuilder } from './ServerListPage';
import { MainContentPageBuilder } from './MainContentPage';
import { AppSettingsPageBuilder } from './AppSettingsPage';

@Entry
@Component
struct Index {
  private pageStack: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.pageStack) {
    }
    .hideNavBar(true)
    .navDestination(this.buildNavDestination)
    .onAppear(() => {
      this.pageStack.pushPathByName('ServerList', null, false);
    })
  }

  @Builder
  buildNavDestination(name: string, param: Object) {
    if (name === 'ServerList') {
      ServerListPageBuilder();
    } else if (name === 'MainContent') {
      MainContentPageBuilder();
    } else if (name === 'AppSettings') {
      AppSettingsPageBuilder();
    }
  }
}
