import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {generateModel} from './model-codegen.mjs';
import {toStandardSchema} from '../tooling/standard-schema.mjs';
const require = createRequire(import.meta.url);
const {load, ts} = require('./host-runtime.cjs');
const {liteV} = load('validator/lite.ets');
const {ValidationCancellationToken} = load('validator/execution.ets');
const {SchemaFactory} = load('validator/reuse.ets');
let checks = 0;
function check(name, fn) {fn(); checks++; console.log('PASS',name);}
const definition = JSON.parse(fs.readFileSync(new URL('../example/models/order.model.json',import.meta.url),'utf8'));
const source = generateModel(definition);
const sandbox = {exports:{}, require(name) {assert.equal(name,'@hmkit/validator/lite'); return load('validator/lite.ets');}};
vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,sandbox);
const {createOrderSchema,createOrderPatchSchema} = sandbox.exports;
const valid = {customer:' Alice ', note:null, quantity:2, referenceLength:'abc',items:[{sku:'A',price:1}]};
check('model transforms, defaults, nested arrays and unknown field stripping',()=>{
  const result=createOrderSchema().parse({...valid, extra:true}); assert.equal(result.success,true);
  assert.equal(result.value.customer,'Alice'); assert.equal(result.value.referenceLength,3);
  assert.equal(result.value.currency,'CNY'); assert.equal(result.value.note,null); assert.equal('extra' in result.value,false);
});
check('required fields, array presence, integer and nested failures',()=>{
  for(const key of ['customer','note','quantity','referenceLength','items']){
    const input={...valid};delete input[key]; assert.equal(createOrderSchema().parse(input).success,false,key);
  }
  assert.equal(createOrderSchema().parse({...valid,items:[{sku:'A',price:-1}]}).errors[0].path,'items.0.price');
  assert.equal(createOrderSchema().parse({...valid,quantity:1.5}).success,false);
});
check('patch output omits absent fields and defaults, still validates present data',()=>{
  const result=createOrderPatchSchema().parse({quantity:3});assert.equal(result.success,true);
  assert.deepEqual(Object.keys(result.value),['quantity']);
  assert.equal(createOrderPatchSchema().parse({quantity:0}).success,false);
  assert.equal(createOrderPatchSchema().parse({items:[{}]}).success,false);
});
check('definition rejects drift, unsupported constraints and callbacks',()=>{
  for(const bad of [
    {...definition,extra:true},
    {...definition,schema:{kind:'object',required:true,properties:{x:{kind:'map'}}}},
    {...definition,schema:{kind:'object',required:true,properties:{x:{kind:'string',required:true,transform:'custom'}}}},
    {...definition,schema:{kind:'object',required:true,properties:{x:{kind:'string',format:'email'}}}},
    {...definition,schema:{kind:'object',required:true,properties:{x:{kind:'number',default:'bad'}}}}
  ]) assert.throws(()=>generateModel(bad));
  assert.match(source,/referenceLength: number;/); assert.match(source,/referenceLength: string;/);
  assert.match(source,/currency\?: string;/); assert.match(source,/currency: string;/);
});
check('optional non-null fields reject explicit null while accepting omission',()=>{
  const src=generateModel({version:1,name:'Optional',schema:{kind:'object',required:true,properties:{alias:{kind:'string'},count:{kind:'number'}}}});
  const box={exports:{},require:()=>load('validator/lite.ets')};
  vm.runInNewContext(ts.transpileModule(src,{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,box);
  assert.equal(box.exports.createOptionalSchema().parse({}).success,true);
  assert.equal(box.exports.createOptionalSchema().parse({alias:null}).success,false);
  assert.equal(box.exports.createOptionalSchema().parse({count:null}).success,false);
});
check('generated-file check rejects hand edits and definition changes',()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'hmkit-model-'));
  try{
    const input=path.join(dir,'model.json'),output=path.join(dir,'model.ets');
    fs.writeFileSync(input,JSON.stringify(definition));fs.writeFileSync(output,source);
    const args=['scripts/model-codegen.mjs',input,output,'--check'];
    assert.equal(spawnSync(process.execPath,args).status,0);
    fs.appendFileSync(output,'// edited\n');assert.equal(spawnSync(process.execPath,args).status,1);
    fs.writeFileSync(output,source);
    fs.writeFileSync(input,JSON.stringify({...definition,name:'Renamed'}));
    assert.equal(spawnSync(process.execPath,args).status,1);
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
check('factory isolates recursively constructed mutable graphs and plugin rules',()=>{
  const factory=new SchemaFactory(()=>liteV.string().required());
  const short=factory.derive(s=>s.max(2)); const long=factory.derive(s=>s.max(20));
  assert.equal(short.create().validate('abcd').valid,false);assert.equal(long.create().validate('abcd').valid,true);
  assert.equal(factory.create().validate('abcd').valid,true);
});
check('standard sync bridge returns transformed output, not raw input',()=>{
  const standard=toStandardSchema(liteV.string().required().transform(s=>s.length))['~standard'];
  assert.equal(standard.version,1);assert.equal(standard.vendor,'hmkit');
  assert.deepEqual(standard.validate('abcd'),{value:4});
  assert.equal(standard.validate('').issues.length,1);
});
check('standard failure paths, legacy schema fallback and custom path mapping',()=>{
  const schema=liteV.object({rows:liteV.array(liteV.object({name:liteV.string().required()}))});
  assert.deepEqual(toStandardSchema(schema)['~standard'].validate({rows:[{}]}).issues[0].path,['rows','0','name']);
  const legacy={validate:x=>({valid:x===1,errors:x===1?[]:[{path:'a.b',message:'bad'}]})};
  assert.deepEqual(toStandardSchema(legacy)['~standard'].validate(1),{value:1});
  assert.deepEqual(toStandardSchema(legacy,{mapPath:()=>['a.b']})['~standard'].validate(2).issues[0].path,['a.b']);
});
const asyncSchema=liteV.string().required().customAsync(async value=>value!=='taken','taken');
assert.deepEqual(await toStandardSchema(asyncSchema,{async:true})['~standard'].validate('ok'),{value:'ok'});
assert.equal((await toStandardSchema(asyncSchema,{async:true})['~standard'].validate('taken')).issues.length,1);checks++;
const token=new ValidationCancellationToken();token.cancel();
assert.equal(toStandardSchema(liteV.string())['~standard'].validate('x',{libraryOptions:{cancellation:token}}).issues.length,1);checks++;
assert.throws(()=>toStandardSchema({validate(){throw new Error('programmer error');}})['~standard'].validate('x'),/programmer error/);checks++;
await assert.rejects(()=>toStandardSchema({async validateAsync(){throw new Error('async failure');}},{async:true})['~standard'].validate('x'),/async failure/);checks++;
let released=0;
const waiting=liteV.string().customAsync((_value,options)=>new Promise(()=>options.cancellation.onCancel(()=>{released++;})),'pending');
const deadline=toStandardSchema(waiting,{async:true,validationOptions:{timeoutMs:5}});
assert.match((await deadline['~standard'].validate('x')).issues[0].message,/timed out/);assert.equal(released,1);checks++;
const active=new ValidationCancellationToken();
const interrupted=toStandardSchema(waiting,{async:true,validationOptions:{cancellation:active}})['~standard'].validate('x');
await Promise.resolve();active.cancel();
assert.match((await interrupted).issues[0].message,/cancelled/);assert.equal(released,2);checks++;
assert.equal(toStandardSchema(liteV.object({a:liteV.string().required(),b:liteV.string().required()}),{validationOptions:{maxErrors:1}})['~standard'].validate({}).issues.length,1);checks++;
console.log(`PASS ${checks} tooling groups. Host Node only; generated ArkTS is also checked by consumer builds.`);
