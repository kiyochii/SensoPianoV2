'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname, '../../web/index.html'), 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(match=>match[1]);
const elements = new Map();
function element() {
  const classes = new Set();
  return {textContent:'', style:{}, value:'',selectedIndex:0,dataset:{},
    classList:{toggle(name,on){if(on)classes.add(name);else classes.delete(name);},remove(name){classes.delete(name);},contains(name){return classes.has(name);}},
    append(){},replaceChildren(){},scrollHeight:0};
}
let now = 2000;
class TestDate extends Date { static now(){return now;} }
const storage = new Map();
const context = vm.createContext({
  document:{getElementById(id){if (!elements.has(id)) elements.set(id, element()); return elements.get(id);},createElement:element,querySelectorAll(){return [];}},
  localStorage:{getItem(key){return storage.get(key)||null;},setItem(key,value){storage.set(key,value);}},Date:TestDate,
  setTimeout(){return 1;}, clearTimeout(){}, AbortController,
  fetch:async()=>{throw new Error('offline');}
});
for(const script of scripts) vm.runInContext(script, context);
const data = {boot:'a',reset:true,next:1,latest:1,dropped:0,note:{pitch:1,octave:6},metrics:{correct:6,wrong:1,attempts:7,done:true},rx:{notes:1,metrics:23,invalidNotes:0,invalidLines:0,uartErrors:0},events:[{id:1,ms:1,source:'notes',type:'note',note:{pitch:1,octave:6},hex:'61'}]};
function render() { context.data = data; vm.runInContext('render(data)',context); }
render();
assert.equal(elements.get('lastNote').textContent, 'C#6');
assert.equal(elements.get('accuracy').textContent, '85.7%');
assert.equal(elements.get('session').textContent, 'Música concluída');
assert.match(elements.get('log').textContent, /HEX 61 · C#6/);
data.reset = false; data.events = []; data.dropped = 4; render();
assert.match(elements.get('warning').textContent, /4 eventos/);
data.reset = true; data.dropped = 0; data.note = null; data.metrics = null; render();
assert.equal(elements.get('lastNote').textContent, '—');
assert.equal(elements.get('accuracy').textContent, '—');
assert.equal(elements.get('warning').textContent, '');
assert.equal(elements.get('log').textContent, '');
data.metrics = {correct:0,wrong:0,attempts:0,done:false}; render();
assert.equal(elements.get('accuracy').textContent, '—');
// Run the complete page, including session capture, not just its first script.
data.reset=false;data.note={pitch:0,octave:3};data.uptimeMs=1000;
data.activity={sequence:1,fpgaMs:1000,epoch:1,session:1,keys:0,pressed:0,released:0,mode:1,state:3,expected:0x30,continuous:true};
data.performance={startedMs:100,presses:0,chords:0,bestStreak:0,elapsedMs:900,activeMs:0,hold:null,interval:null,response:null,solve:null,incomplete:false};
data.events=[];render();
assert.equal(elements.get('physicalState').textContent,'Aprender · Teclas: nenhuma · Guia: C3');
elements.get('record').onclick();
assert.equal(vm.runInContext('records.length',context),1);
// A guide note arriving while recording must not count as a child's touch.
now=2100;data.events=[{id:2,ms:1000,type:'note',source:'notes',note:{pitch:0,octave:3}}];data.next=2;render();
assert.equal(vm.runInContext('records[0].keys.reduce((a,b)=>a+b,0)',context),0);
data.activity={...data.activity,sequence:2,fpgaMs:1100,keys:1,pressed:1};
data.performance={...data.performance,presses:1,hold:{meanMs:125},response:{meanMs:290}};
data.events=[{id:3,ms:1000,type:'activity',source:'metrics',activity:data.activity}];data.next=3;render();
assert.equal(vm.runInContext('records[0].keys[0]',context),1);
assert.equal(vm.runInContext('keys[0].classList.contains("active")',context),true);
assert.equal(elements.get('holdMean').textContent,'125 ms');
assert.equal(elements.get('responseMean').textContent,'290 ms');
assert.match(elements.get('log').textContent,/FPGA 1100 ms/);
render(); // duplicate API event does not double count
assert.equal(vm.runInContext('records[0].keys[0]',context),1);
now=2200;data.activity={...data.activity,sequence:3,fpgaMs:1200,keys:0,pressed:0,released:1};
data.events=[{id:4,ms:1000,type:'activity',source:'metrics',activity:data.activity}];data.next=4;render();
assert.equal(vm.runInContext('keys[0].classList.contains("active")',context),false);
assert.equal(vm.runInContext('records[0].keys[0]',context),1);
assert.equal(vm.runInContext('records[0].fpgaSegments[0].performance.response.meanMs',context),290);
data.dropped=3;data.rx.activityMissing=2;data.performance.incomplete=true;render();
assert.match(elements.get('warning').textContent,/2 observações/);
assert.equal(vm.runInContext('records[0].incomplete',context),true);
// FPGA-only restart closes the browser recording, even when ESP boot is unchanged.
now=2300;data.dropped=0;data.activity={...data.activity,sequence:1,fpgaMs:0,epoch:2,continuous:false};
data.events=[{id:5,ms:1000,type:'activity',source:'metrics',activity:data.activity}];data.next=5;render();
assert.notEqual(vm.runInContext('records[0].end',context),null);
assert(storage.has('senso.sessions'));
// Stale physical data is unknown, and cannot start a new recording.
data.activityAgeMs=4001;data.events=[];render();
assert.match(elements.get('physicalState').textContent,/estado atual das teclas desconhecido/);
elements.get('record').onclick();
assert.equal(vm.runInContext('records.length',context),1);
assert.match(elements.get('notice').textContent,/telemetria das teclas físicas/);
console.log('PASS: pagina completa, tempos, soltura, sessao, notas guia, duplicatas, perdas e reset FPGA');
