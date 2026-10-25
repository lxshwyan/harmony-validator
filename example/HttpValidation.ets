import { rcp } from '@kit.RemoteCommunicationKit';
import { liteV, StringSchema } from '@hmkit/validator/lite';
import { ValidationOptions } from '@hmkit/validator/execution';

export class HttpValidationStats {
  started: number = 0;
  active: number = 0;
  cancelled: number = 0;
  destroyed: number = 0;
  destroyFailures: number = 0;
}

interface AvailabilityResponse { available: boolean; }

/** HarmonyOS API12+ reference adapter. Each validation owns one RCP session. */
export function createHttpRule(baseUrl: string, stats: HttpValidationStats): StringSchema {
  return liteV.string().required().customAsync((value: string, options?: ValidationOptions): Promise<boolean> => {
    if (options?.cancellation?.isCancelled() === true) return Promise.resolve(false);
    const request = new rcp.Request(`${baseUrl}/check?value=${encodeURIComponent(value)}`);
    const session = rcp.createSession();
    stats.started++; stats.active++;
    return new Promise<boolean>((resolve): void => {
      let settled = false;
      let unsubscribe: (() => void) | undefined;
      const finish = (valid: boolean): void => {
        if (settled) return;
        settled = true;
        unsubscribe?.();
        try { session.close(); stats.destroyed++; }
        catch (_error) { stats.destroyFailures++; }
        stats.active--;
        resolve(valid);
      };
      unsubscribe = options?.cancellation?.onCancel((): void => {
        stats.cancelled++;
        try { session.cancel(request); } catch (_error) { stats.destroyFailures++; }
        finish(false);
      });
      if (settled) { unsubscribe?.(); return; }
      try {
        session.fetch(request).then((response: rcp.Response): void => {
          if (response.statusCode !== 200) { finish(false); return; }
          try { finish((response.toJSON() as AvailabilityResponse).available === true); }
          catch (_error) { finish(false); }
        }).catch((): void => finish(false));
      } catch (_error) { finish(false); }
    });
  }, '名称不可用或查重请求失败');
}
