import assert from 'node:assert/strict';
import http from 'node:http';
import {createRequire} from 'node:module';
import {startNetworkFixture} from './network-fixture.mjs';
const require=createRequire(import.meta.url);
const {load}=require('./host-runtime.cjs');
const {liteV}=load('validator/lite.ets');
const {FormValidator}=load('validator/form.ets');
const {ValidationCancellationToken,validateValueAsync}=load('validator/execution.ets');
const fixture=await startNetworkFixture();
const stats={started:0,active:0,destroyed:0,cancelled:0};
function check(value,options){
  if(options?.cancellation?.isCancelled())return Promise.resolve(false);
  return new Promise(resolve=>{
    let settled=false,unsubscribe;
    const request=http.get(`${fixture.url}/check?value=${encodeURIComponent(value)}`,response=>{
      let data='';response.setEncoding('utf8');response.on('data',chunk=>{data+=chunk;});
      response.once('error',()=>finish(false));
      response.once('end',()=>{try{finish(response.statusCode===200&&JSON.parse(data).available===true);}catch{finish(false);}});
    });
    stats.started++;stats.active++;
    function finish(valid){if(settled)return;settled=true;unsubscribe?.();request.destroy();stats.destroyed++;stats.active--;resolve(valid);}
    request.once('error',()=>finish(false));
    unsubscribe=options?.cancellation?.onCancel(()=>{stats.cancelled++;finish(false);});
    if(settled)unsubscribe?.();
  });
}
const schema=liteV.string().required().customAsync(check,'unavailable');
const forms=[];
const makeForm=options=>{const form=new FormValidator({name:schema},options);forms.push(form);return form;};
let groups=0;
try{
  for(const [value,valid] of [['available',true],['taken',false],['error',false],['disconnect',false]]){
    assert.equal((await validateValueAsync(schema,value,{timeoutMs:2000})).valid,valid,value);
    assert.equal(stats.active,0);
  }groups++;console.log('PASS success, business failure, HTTP failure and disconnected transport cleanup');
  const before=stats.started,pre=new ValidationCancellationToken();pre.cancel();
  assert.equal((await validateValueAsync(schema,'unused',{cancellation:pre})).errors[0].code,'cancelled');
  assert.equal(stats.started,before);groups++;
  const form=makeForm();
  const old=form.validateFieldAsync('name','slow-old');await fixture.waitFor('received','slow-old');
  assert.equal(await form.validateFieldAsync('name','available'),null);await old;
  await fixture.waitFor('aborted','slow-old');
  assert.equal(form.getFieldState('name').error,null);assert.equal(form.getFieldState('name').validating,false);groups++;
  const task=validateValueAsync(schema,'slow-timeout',{timeoutMs:150});
  await fixture.waitFor('received','slow-timeout');assert.equal((await task).errors[0].code,'timeout');
  await fixture.waitFor('aborted','slow-timeout');groups++;
  for(const action of ['reset','dispose']){
    const subject=makeForm(),value='slow-'+action;
    const task=subject.validateFieldAsync('name',value);await fixture.waitFor('received',value);
    subject[action]();await task;await fixture.waitFor('aborted',value);assert.equal(stats.active,0);groups++;
  }
  const submitting=makeForm();let handlers=0;
  const submit=submitting.submit({name:'slow-submit'},async()=>{handlers++;});
  await fixture.waitFor('received','slow-submit');submitting.dispose();await submit;
  await fixture.waitFor('aborted','slow-submit');assert.equal(handlers,0);assert.equal(submitting.getState().submitting,false);groups++;
  const token=new ValidationCancellationToken();const recovered=makeForm();
  const pending=validateValueAsync(schema,'slow-token',{cancellation:token});await fixture.waitFor('received','slow-token');
  token.cancel();token.cancel();await pending;await fixture.waitFor('aborted','slow-token');
  assert.equal(await recovered.validateFieldAsync('name','available'),null);assert.equal(stats.active,0);groups++;
  const cancelledBefore=stats.cancelled;token.cancel();
  assert.equal(stats.cancelled,cancelledBefore);assert.equal(stats.started,stats.destroyed);
  assert.equal(fixture.events.some(e=>e.type==='completed'&&e.value.startsWith('slow')),false);
  console.log(JSON.stringify({result:'PASS',groups,transport:'Node HTTP loopback',stats,serverAborted:fixture.events.filter(e=>e.type==='aborted').map(e=>e.value)},null,2));
}finally{for(const form of forms)form.dispose();await fixture.close();}
