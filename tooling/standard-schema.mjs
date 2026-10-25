/**
 * JS/TS bridge for hmkit-shaped schemas; deliberately kept outside the ArkTS HAR.
 * Uses parse output, preserving transformations/defaults. Exceptions propagate.
 */
class BridgeToken {
  cancelled = false;
  listeners = new Set();
  isCancelled() {return this.cancelled;}
  onCancel(listener) {
    if (this.cancelled) {try {listener();} catch {} return () => {};}
    this.listeners.add(listener);return () => this.listeners.delete(listener);
  }
  cancel() {
    if (this.cancelled) return;
    this.cancelled=true;
    const listeners=[...this.listeners];this.listeners.clear();
    for(const listener of listeners) try {listener();} catch {}
  }
}
const interrupted = message => ({issues:[{message,path:[]}]});
export function toStandardSchema(schema, {async = false, validationOptions, mapPath} = {}) {
  const finish = (result, input, parsed, options) => {
    if(options?.cancellation?.isCancelled()) return interrupted('Validation cancelled');
    if (parsed ? result.success : result.valid) return {value: parsed ? result.value : input};
    if (!Array.isArray(result.errors) || !result.errors.length) {
      throw new TypeError('A failed hmkit result must contain errors');
    }
    let errors=result.errors;
    if(options?.abortEarly) errors=errors.slice(0,1);
    if(Number.isFinite(options?.maxErrors)) errors=errors.slice(0,Math.max(1,Math.floor(options.maxErrors)));
    return {issues: errors.map(error => ({
      message: error.message,
      path: mapPath ? mapPath(error) : error.path === '' ? [] : error.path.split('.')
    }))};
  };
  const optionsFor = options => {
    const extra = options?.libraryOptions;
    return validationOptions || extra ? {...validationOptions, ...extra} : undefined;
  };
  const validate = async ? async (value, options) => {
    const nativeOptions=optionsFor(options);
    if(nativeOptions?.cancellation?.isCancelled()) return interrupted('Validation cancelled');
    const timeout=nativeOptions?.timeoutMs;
    if(timeout!==undefined && (!Number.isFinite(timeout)||timeout<=0)) throw new RangeError('timeoutMs must be finite and positive');
    const child=new BridgeToken();
    const unlink=nativeOptions?.cancellation?.onCancel(()=>child.cancel());
    let unsubscribe,timer;
    const stop=new Promise(resolve=>{unsubscribe=child.onCancel(()=>resolve(interrupted('Validation cancelled')));});
    const tasks=[stop];
    const parsed = typeof schema.parseAsync === 'function';
    const local={...nativeOptions,cancellation:child};
    tasks.push(Promise.resolve().then(()=>parsed ? schema.parseAsync(value,undefined,local)
      : schema.validateAsync(value,undefined,local)).then(result=>finish(result,value,parsed,local)));
    if(timeout!==undefined) tasks.push(new Promise(resolve=>{timer=setTimeout(()=>{
      resolve(interrupted('Validation timed out'));child.cancel();
    },timeout);}));
    try {return await Promise.race(tasks);} catch(error) {child.cancel();throw error;}
    finally {clearTimeout(timer);unsubscribe?.();unlink?.();}
  } : (value, options) => {
    const nativeOptions=optionsFor(options);
    if(nativeOptions?.timeoutMs!==undefined) throw new TypeError('timeoutMs requires the async bridge');
    if(nativeOptions?.cancellation?.isCancelled()) return interrupted('Validation cancelled');
    const parsed = typeof schema.parse === 'function';
    const result = parsed ? schema.parse(value, undefined, nativeOptions)
      : schema.validate(value, undefined, nativeOptions);
    return finish(result, value, parsed,nativeOptions);
  };
  return {'~standard': {version: 1, vendor: 'hmkit', validate}};
}
