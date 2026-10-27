(()=>{
  if(window.__hybridCoachSetEditor)return;
  window.__hybridCoachSetEditor=true;

  const TRAINING_KEY='hybridCoachData_v1';
  const MAX_SETS=12;
  const expanded=new Set();
  let timer=null;

  function readTraining(){try{const raw=localStorage.getItem(TRAINING_KEY);return raw?JSON.parse(raw):null}catch{return null}}
  let state=(()=>{const s=readTraining()?.setEditor;return s&&s.version===1&&s.sessions?s:{version:1,sessions:{}}})();
  const previousSetItem=Storage.prototype.setItem;

  function withState(data){if(data&&typeof data==='object')data.setEditor=state;return data}
  if(!window.__hybridCoachSetStorageBridge){
    window.__hybridCoachSetStorageBridge=true;
    Storage.prototype.setItem=function(key,value){
      if(this===localStorage&&key===TRAINING_KEY){try{value=JSON.stringify(withState(JSON.parse(String(value))))}catch{}}
      return previousSetItem.call(this,key,value);
    };
  }

  function persist(){
    try{
      const data=readTraining();
      if(data)previousSetItem.call(localStorage,TRAINING_KEY,JSON.stringify(withState(data)));
      document.dispatchEvent(new Event('input',{bubbles:true}));
    }catch(err){console.warn('Could not save set changes',err)}
  }

  function week(){return document.getElementById('week')?.value||'0'}
  function day(){return document.getElementById('day')?.value||'Mon'}
  function sessionKey(){return `${week()}-${day()}`}
  function exerciseId(box){
    if(box.dataset.hcId)return box.dataset.hcId;
    const s=box.querySelector('.choice');
    return (s?.options?.[0]?.value||s?.options?.[0]?.textContent||'exercise').trim();
  }
  function cardKey(id){return `${sessionKey()}-${id}`}
  function nativeRows(box){return [...box.querySelectorAll(':scope > .setrow:not(.head):not(.hc-extra-set)')]}
  function visibleRows(box){return [...box.querySelectorAll(':scope > .setrow:not(.head):not(.hc-set-hidden)')]}

  function entry(id,base){
    const sk=sessionKey();
    if(!state.sessions[sk])state.sessions[sk]={};
    if(!state.sessions[sk][id])state.sessions[sk][id]={count:base,extra:{}};
    const e=state.sessions[sk][id];
    if(!Number.isFinite(Number(e.count)))e.count=base;
    e.count=Math.max(1,Math.min(MAX_SETS,Number(e.count)));
    if(!e.extra||typeof e.extra!=='object')e.extra={};
    return e;
  }

  function addStyles(){
    if(document.getElementById('hcSetEditorStyles'))return;
    const s=document.createElement('style');s.id='hcSetEditorStyles';
    s.textContent=`
      .hc-set-hidden{display:none!important}
      .hc-set-controls{display:flex;gap:7px;align-items:center;margin-top:9px;flex-wrap:wrap}
      .hc-set-btn{border:1px solid var(--border);background:var(--panel);color:var(--text);border-radius:9px;min-height:34px;padding:0 10px;font-size:12px}
      .hc-set-btn.delete{color:var(--bad);border-color:#6f3a3a;background:#2b1717}.hc-set-btn:disabled{opacity:.35}
      .hc-set-count{font-size:11px;color:var(--muted);margin-left:auto}
      .hc-extra-set input{padding:8px;min-height:39px}
      .hc-complete-toggle{display:none!important}
      .hc-set-done{border:1px solid #3b7152;background:#173624;color:var(--ok);border-radius:999px;min-height:32px;padding:0 10px;font-size:12px;font-weight:700;white-space:nowrap}
      .exercise.hc-ex-collapsed>.hc-set-controls{display:none!important}
      @media(max-width:520px){.hc-set-btn{flex:1}.hc-set-count{flex-basis:100%;margin-left:0}}
    `;
    document.head.appendChild(s);
  }

  function setValue(input,value){
    if(!input)return;
    input.value=value??'';
    input.dispatchEvent(new Event('input',{bubbles:true}));
    input.dispatchEvent(new Event('change',{bubbles:true}));
  }

  function clearRow(row){row?.querySelectorAll('input').forEach(i=>setValue(i,''))}

  function extraRow(box,id,n,e){
    const v=e.extra[n]||{w:'',r:'',rir:''};
    const row=document.createElement('div');row.className='setrow hc-extra-set';row.dataset.hcExtraSet=String(n);
    row.innerHTML=`<span>${n}</span><input type="number" inputmode="decimal" placeholder="lb" data-field="w"><input type="number" inputmode="numeric" placeholder="reps" data-field="r"><input type="number" inputmode="numeric" placeholder="RIR" data-field="rir">`;
    const inputs=[...row.querySelectorAll('input')];
    inputs[0].value=v.w??'';inputs[1].value=v.r??'';inputs[2].value=v.rir??'';
    inputs.forEach(input=>input.addEventListener('input',()=>{
      if(!e.extra[n])e.extra[n]={w:'',r:'',rir:''};
      e.extra[n][input.dataset.field]=input.value;
      persist();schedule(35);
    }));
    const anchor=box.querySelector('.hc-ex-controls');
    anchor?box.insertBefore(row,anchor):box.appendChild(row);
  }

  function updateDone(box,id){
    const rows=visibleRows(box),inputs=rows.flatMap(r=>[...r.querySelectorAll('input')]);
    const done=inputs.length>0&&inputs.every(i=>String(i.value).trim()!=='');
    const key=cardKey(id);
    box.classList.toggle('hc-ex-complete',done);
    if(!done){expanded.delete(key);box.classList.remove('hc-ex-collapsed')}
    else box.classList.toggle('hc-ex-collapsed',!expanded.has(key));

    let b=box.querySelector('.hc-set-done');
    if(done&&!b){
      b=document.createElement('button');b.type='button';b.className='hc-set-done';
      box.querySelector('.exhead')?.appendChild(b);
      b.addEventListener('click',()=>{expanded.has(key)?expanded.delete(key):expanded.add(key);updateDone(box,id)});
    }
    if(b){b.style.display=done?'':'none';b.textContent=expanded.has(key)?'✓ Done · Hide':'✓ Done · Edit'}
  }

  function applyBox(box){
    if(box.style.display==='none')return;
    const id=exerciseId(box),native=nativeRows(box),base=Math.max(1,native.length),e=entry(id,base),count=e.count;
    box.querySelectorAll(':scope > .hc-extra-set,:scope > .hc-set-controls').forEach(x=>x.remove());

    native.forEach((row,i)=>{
      row.classList.toggle('hc-set-hidden',i>=count);
      const label=row.querySelector(':scope > span');if(label)label.textContent=String(i+1);
    });
    for(let n=base+1;n<=count;n++)extraRow(box,id,n,e);

    const controls=document.createElement('div');controls.className='hc-set-controls';
    controls.innerHTML=`<button type="button" class="hc-set-btn" data-add>+ Add set</button><button type="button" class="hc-set-btn delete" data-delete>− Delete last set</button><span class="hc-set-count">${count} set${count===1?'':'s'}</span>`;
    controls.querySelector('[data-add]').disabled=count>=MAX_SETS;
    controls.querySelector('[data-delete]').disabled=count<=1;
    controls.querySelector('[data-add]').addEventListener('click',()=>{e.count=Math.min(MAX_SETS,e.count+1);persist();schedule(0)});
    controls.querySelector('[data-delete]').addEventListener('click',()=>{
      if(e.count<=1)return;
      const rows=visibleRows(box),last=rows[rows.length-1];
      if(last?.classList.contains('hc-extra-set'))delete e.extra[e.count];
      else clearRow(last);
      e.count=Math.max(1,e.count-1);persist();schedule(0);
    });
    const exerciseControls=box.querySelector('.hc-ex-controls');
    exerciseControls?box.insertBefore(controls,exerciseControls):box.appendChild(controls);
    updateDone(box,id);

    if(!box.dataset.hcSetWatch){
      box.dataset.hcSetWatch='1';
      box.addEventListener('input',()=>schedule(45),true);
      box.addEventListener('change',()=>schedule(45),true);
    }
  }

  function apply(){
    addStyles();
    document.querySelectorAll('#exercises > .exercise').forEach(applyBox);
    persist();
  }
  function schedule(delay=70){clearTimeout(timer);timer=setTimeout(apply,delay)}

  function start(){
    addStyles();schedule(120);
    const holder=document.getElementById('exercises');
    if(holder)new MutationObserver(()=>schedule(90)).observe(holder,{childList:true,subtree:true});
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day')schedule(140)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.weekBtn,.tab,#hcEditExercises'))schedule(150)},true);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
