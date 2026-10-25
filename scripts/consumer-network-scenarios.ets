import { http } from '@kit.NetworkKit';
import { FormValidator } from '@hmkit/validator/form';
import { ValidationCancellationToken, validateValueAsync } from '@hmkit/validator/execution';
import { createHttpRule, HttpValidationStats } from './HttpValidation';

const BASE_URL: string = 'http://10.0.2.2:18743';
interface FixtureEvent { type: string; value: string; }

async function waitFor(type: string, value: string, token: ValidationCancellationToken): Promise<void> {
  const deadline = Date.now() + 4000;
  while (Date.now() < deadline) {
    if (token.isCancelled()) throw new Error('Page cancelled');
    const request = http.createHttp();
    try {
      const response = await request.request(`${BASE_URL}/events`, {
        expectDataType: http.HttpDataType.STRING, usingCache: false, connectTimeout: 1000, readTimeout: 1000
      });
      const events = JSON.parse(response.result as string) as Array<FixtureEvent>;
      if (events.some((event: FixtureEvent): boolean => event.type === type && event.value === value)) return;
    } finally { request.destroy(); }
    await new Promise<void>((resolve): void => { setTimeout(resolve, 20); });
  }
  throw new Error(`Missing server event ${type}:${value}`);
}

export async function runNetworkScenarios(token: ValidationCancellationToken): Promise<boolean> {
  const stats = new HttpValidationStats();
  const schema = createHttpRule(BASE_URL, stats);
  const forms: FormValidator[] = [];
  const unlink = token.onCancel((): void => { for (const form of forms) form.dispose(); });
  const id = `${Date.now()}`;
  try {
    if (!(await validateValueAsync(schema, 'available', { cancellation: token, timeoutMs: 5000 })).valid) return false;
    for (const value of ['taken', 'error', 'disconnect']) {
      if ((await validateValueAsync(schema, value, { cancellation: token, timeoutMs: 5000 })).valid) return false;
    }
    const latest = new FormValidator({ 'name': schema }, { timeoutMs: 3000 }); forms.push(latest);
    const oldValue = `slow-native-old-${id}`;
    const old = latest.validateFieldAsync('name', oldValue);
    await waitFor('received', oldValue, token);
    if (await latest.validateFieldAsync('name', 'available') !== null) return false;
    await old; await waitFor('aborted', oldValue, token);
    if (latest.getFieldState('name').error !== null) return false;

    const timeoutValue = `slow-native-timeout-${id}`;
    const timeout = validateValueAsync(schema, timeoutValue, { cancellation: token, timeoutMs: 500 });
    await waitFor('received', timeoutValue, token);
    if ((await timeout).errors[0]?.code !== 'timeout') return false;
    await waitFor('aborted', timeoutValue, token);

    for (const action of ['reset', 'dispose']) {
      const form = new FormValidator({ 'name': schema }, { timeoutMs: 3000 }); forms.push(form);
      const value = `slow-native-${action}-${id}`;
      const task = form.validateFieldAsync('name', value);
      await waitFor('received', value, token);
      if (action === 'reset') form.reset(); else form.dispose();
      await task; await waitFor('aborted', value, token);
    }
    const submitting = new FormValidator({ 'name': schema }, { timeoutMs: 3000 }); forms.push(submitting);
    let handlers = 0;
    const submitValue = `slow-native-submit-${id}`;
    const submit = submitting.submit({ 'name': submitValue }, async (): Promise<void> => { handlers++; });
    await waitFor('received', submitValue, token); submitting.dispose(); await submit;
    await waitFor('aborted', submitValue, token);
    if (handlers !== 0 || stats.active !== 0 || stats.destroyFailures !== 0 || stats.started !== stats.destroyed) return false;
    console.info(`[hmkit-http] PASS ${JSON.stringify(stats)}`);
    return true;
  } finally { unlink(); for (const form of forms) form.dispose(); }
}

/** Called by the page; leaving the page cancels an actually received request. */
export async function runExitScenario(token: ValidationCancellationToken, started: () => void): Promise<void> {
  const stats = new HttpValidationStats();
  const value = `slow-native-exit-${Date.now()}`;
  const task = validateValueAsync(createHttpRule(BASE_URL, stats), value, { cancellation: token, timeoutMs: 10000 });
  await waitFor('received', value, token);
  if (!token.isCancelled()) started();
  await task;
  if (stats.active !== 0 || stats.started !== stats.destroyed || stats.destroyFailures !== 0) throw new Error('HTTP resource leak');
  console.info(`[hmkit-http] EXIT CLEAN ${value} ${JSON.stringify(stats)}`);
}
