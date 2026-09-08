import { liteV, AnySchema } from '@hmkit/validator/lite';
import { LazySchema, DiscriminatedUnionSchema, WhenSchema } from '@hmkit/validator/composition';
import { FormValidator, FormTrigger } from '@hmkit/validator/form';
import { ValidationOptions, ValidationCancellationToken, validateValueAsync } from '@hmkit/validator/execution';
import { fromJSONSchema, inspectJSONSchema } from '@hmkit/validator/interop';

/** Deterministic remote-request mock. Real adapters should abort their request in onCancel. */
export function remoteCheck(value: string, options?: ValidationOptions): Promise<boolean> {
  return new Promise<boolean>((resolve): void => {
    let unsubscribe: (() => void) | undefined;
    const timer = setTimeout((): void => { unsubscribe?.(); resolve(value !== 'taken'); }, 30);
    unsubscribe = options?.cancellation?.onCancel((): void => { clearTimeout(timer); resolve(false); });
  });
}

/** Compiled against the packaged HAR, not project source files. */
export async function runFeatureScenarios(pageToken: ValidationCancellationToken): Promise<boolean> {
  const tree: LazySchema<Record<string, Object>> = new LazySchema<Record<string, Object>>(
    (): AnySchema<Record<string, Object>> => liteV.object({
      'name': liteV.string().required(), 'children': liteV.array(tree)
    }));
  const leaf: Record<string, Object> = {};
  const update: Record<string, Object> = { 'children': [leaf] };
  if (!tree.deepPartial().validate(update).valid || tree.validate(update).valid) return false;

  const variants = new DiscriminatedUnionSchema<Record<string, Object>>('kind', {
    'person': liteV.object({ 'kind': liteV.literal('person'), 'name': liteV.string().required() })
  }).deepPartial();
  const person: Record<string, Object> = { 'kind': 'person' };
  if (!variants.validate(person).valid || variants.validate(leaf).valid) return false;

  const unsupported = JSON.parse('{"type":"number","multipleOf":2}') as Record<string, Object>;
  if (inspectJSONSchema(unsupported).length !== 1) return false;
  let rejected = false;
  try { fromJSONSchema(unsupported, { strict: true }); } catch (_error) { rejected = true; }
  if (!rejected) return false;

  const remote = liteV.string().customAsync(remoteCheck, 'Already registered');
  if (!(await validateValueAsync(remote, 'available', { cancellation: pageToken, timeoutMs: 1000 })).valid) return false;
  const timeout = await validateValueAsync(remote, 'available', { timeoutMs: 1 });
  if (timeout.errors[0]?.code !== 'timeout') return false;
  const cancelled = new ValidationCancellationToken();
  const task = validateValueAsync(remote, 'available', { cancellation: cancelled });
  cancelled.cancel();
  if ((await task).errors[0]?.code !== 'cancelled') return false;

  const form = new FormValidator({
    'mode': liteV.string(),
    'company': new WhenSchema<string>('mode', (value: Object | null | undefined): boolean => value === 'business',
      liteV.string().required(), liteV.string())
  }, { triggers: [FormTrigger.CHANGE], debounceMs: 2,
    fields: { 'company': { dependencies: ['mode'] } } });
  try {
    const business: Record<string, Object> = { 'mode': 'business', 'company': '' };
    await form.onChange('mode', 'business', business);
    if (form.getState().errors['company'] === undefined) return false;
    const personal: Record<string, Object> = { 'mode': 'personal', 'company': '' };
    await form.onChange('mode', 'personal', personal);
    if (form.getState().errors['company'] !== undefined) return false;
    return Object.keys(await form.submit(personal)).length === 0;
  } finally { form.dispose(); }
}
