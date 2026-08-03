import { preferences } from '@kit.ArkData';
import { ServerConfig } from '../model/ServerConfig';

const PREFERENCES_NAME = 'orionlink_prefs';
const KEY_SERVER_LIST = 'server_list';
const KEY_GLOBAL_ACCELERATION = 'global_acceleration_factor';
const KEY_GLOBAL_SCROLL_ACCELERATION = 'global_scroll_acceleration_factor';

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
      let factor = item['accelerationFactor'] as number;
      let scrollFactor = item['scrollAccelerationFactor'] as number;
      let config = new ServerConfig(
        item['id'] as string,
        item['name'] as string,
        item['ip'] as string,
        item['port'] as number,
        factor !== undefined ? factor : 1.0,
        scrollFactor !== undefined ? scrollFactor : 1.0
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
        'port': list[i].port,
        'accelerationFactor': list[i].accelerationFactor,
        'scrollAccelerationFactor': list[i].scrollAccelerationFactor
      };
      arr.push(item);
    }
    let json = JSON.stringify(arr);
    prefs.putSync(KEY_SERVER_LIST, json);
    prefs.flush();
  }

  static loadGlobalAccelerationFactor(context: Context): number {
    let prefs = PreferencesUtil.getPreference(context);
    return prefs.getSync(KEY_GLOBAL_ACCELERATION, 1.0) as number;
  }

  static saveGlobalAccelerationFactor(context: Context, factor: number): void {
    let prefs = PreferencesUtil.getPreference(context);
    prefs.putSync(KEY_GLOBAL_ACCELERATION, factor);
    prefs.flush();
  }

  static loadGlobalScrollAccelerationFactor(context: Context): number {
    let prefs = PreferencesUtil.getPreference(context);
    return prefs.getSync(KEY_GLOBAL_SCROLL_ACCELERATION, 0.5) as number;
  }

  static saveGlobalScrollAccelerationFactor(context: Context, factor: number): void {
    let prefs = PreferencesUtil.getPreference(context);
    prefs.putSync(KEY_GLOBAL_SCROLL_ACCELERATION, factor);
    prefs.flush();
  }
}
