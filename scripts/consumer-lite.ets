import { liteV } from '@hmkit/validator/lite';
import { validateValueAsync, validateBatchAsync, deepPartialSchema } from '@hmkit/validator/execution';
import { fromJSONSchema } from '@hmkit/validator/interop';
import { uuidRule } from '@hmkit/validator/rules/uuid';
import { ValidationCancellationToken } from '@hmkit/validator/execution';
import { runFeatureScenarios } from './ConsumerScenarios';

@Entry
@Component
struct Index {
  @State status: string = 'running';
  @State busy: boolean = false;
  private pageToken: ValidationCancellationToken = new ValidationCancellationToken();
  aboutToAppear(): void { this.check(); }
  aboutToDisappear(): void { this.pageToken.cancel(); }
  async check(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.pageToken = new ValidationCancellationToken();
    const runToken = this.pageToken;
    try {
    const schema = liteV.string().required().use(uuidRule);
    const good = '550e8400-e29b-41d4-a716-446655440000';
    const result = await validateValueAsync(schema, good, { timeoutMs: 1000 });
    const batch = await validateBatchAsync(schema, [good, 'bad'], { concurrency: 2 });
    const json = fromJSONSchema(JSON.parse('{"oneOf":[{"type":"number"},{"type":"integer"}]}') as Record<string, Object>);
    const partial = deepPartialSchema(liteV.object({ 'name': liteV.string().required() }));
    const passed = result.valid && batch.length === 2 && !batch[1].valid && !json.validate(1).valid &&
      partial.validate({} as Record<string, Object>).valid && await runFeatureScenarios(runToken);
    if (!runToken.isCancelled()) this.status = passed ? 'PASS 1.3 consumer' : 'FAIL 1.3 consumer';
    } catch (_error) { if (!runToken.isCancelled()) this.status = 'FAIL 1.3 consumer: exception'; }
    finally { this.busy = false; }
  }
  build() {
    Column() {
      Text(this.status).id('validator_consumer_status')
      Button('Run acceptance').enabled(!this.busy).onClick(() => { this.check(); })
      Button('Cancel pending request').onClick(() => { this.pageToken.cancel(); this.status = 'Cancelled'; })
    }
  }
}
