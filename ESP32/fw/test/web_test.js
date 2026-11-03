'use strict';
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname, '../../web/index.html'), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const elements = new Map();
function element() {
  return {textContent:'', style:{}, classList:{toggle(){},remove(){}}, append(){}, scrollHeight:0};
}
const context = vm.createContext({
  document:{getElementById(id){if (!elements.has(id)) elements.set(id, element()); return elements.get(id);},createElement:element},
  setTimeout(){return 1;}, clearTimeout(){}, AbortController,
  fetch:async()=>{throw new Error('offline');}
});
vm.runInContext(script, context);
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
console.log('PASS: interface, metricas, historico, perdas e reinicializacao');
