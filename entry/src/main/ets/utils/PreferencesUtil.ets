import { preferences } from '@kit.ArkData';
import { ServerConfig } from '../model/ServerConfig';

const PREFERENCES_NAME = 'orionlink_prefs';
const KEY_SERVER_LIST = 'server_list';

export class PreferencesUtil {
  private static getPreference(context: Context): preferences.Preferences {
    let options: preferences.Options = { name: PREFERENCES_NAME };
    return preferences.getPreferencesSync(context, options);
  }

  static loadServerList(context: Context): Array<ServerConfig> {
    let prefs = PreferencesUtil.getPreference(context);
    let json = prefs.getSync(KEY_SERVER_LIST, '[]') as string;
    let arr: Array<Record<string, Object>> = JSON.parse(json) as Array<Record<string, Object>>;
    let result: Array<ServerConfig> = [];
    for (let i = 0; i < arr.length; i++) {
      let item = arr[i];
      let config = new ServerConfig(
        item['id'] as string,
        item['name'] as string,
        item['ip'] as string,
        item['port'] as number
      );
      result.push(config);
    }
    return result;
  }

  static saveServerList(context: Context, list: Array<ServerConfig>): void {
    let prefs = PreferencesUtil.getPreference(context);
    let arr: Array<Record<string, Object>> = [];
    for (let i = 0; i < list.length; i++) {
      let item: Record<string, Object> = {
        'id': list[i].id,
        'name': list[i].name,
        'ip': list[i].ip,
        'port': list[i].port
      };
      arr.push(item);
    }
    let json = JSON.stringify(arr);
    prefs.putSync(KEY_SERVER_LIST, json);
    prefs.flush();
  }
}
