(()=>{
  if(window.__hybridCoachSetEditorV2)return;
  window.__hybridCoachSetEditorV2=true;
  window.__hybridCoachSetEditor=true;

  const TRAINING_KEY='hybridCoachData_v1';
  const MAX_SETS=12;
  const expanded=new Set();
  let timer=null;
  let observer=null;

  function readTraining(){try{const raw=localStorage.getItem(TRAINING_KEY);return raw?JSON.parse(raw):null}catch{return null}}
  function readEditorState(){
    const s=readTraining()?.setEditor;
    return s&&s.sessions&&typeof s.sessions==='object'?{version:2,sessions:s.sessions}:{version:2,sessions:{}};
  }
  let state=readEditorState();
  const previousSetItem=Storage.prototype.setItem;

  function refreshState(){
    const incoming=readTraining()?.setEditor;
    if(incoming?.sessions&&typeof incoming.sessions==='object')state={version:2,sessions:incoming.sessions};
  }
  function withState(data){if(data&&typeof data==='object')data.setEditor=state;return data}
  if(!window.__hybridCoachSetStorageBridgeV2){
    window.__hybridCoachSetStorageBridgeV2=true;
    Storage.prototype.setItem=function(key,value){
      if(this===localStorage&&key===TRAINING_KEY){try{value=JSON.stringify(withState(JSON.parse(String(value))))}catch{}}
      return previousSetItem.call(this,key,value);
    };
  }

  function persist(){
    try{
      const data=readTraining();
      if(data)previousSetItem.call(localStorage,TRAINING_KEY,JSON.stringify(withState(data)));
      document.dispatchEvent(new CustomEvent('hc:set-editor-change'));
      document.dispatchEvent(new Event('input',{bubbles:true}));
    }catch(err){console.warn('Could not save set changes',err)}
  }

  function week(){return document.getElementById('week')?.value||'0'}
  function day(){return document.getElementById('day')?.value||'Mon'}
  function sessionKey(){return `${week()}-${day()}`}
  function exerciseId(box){
    if(box.dataset.hcOriginalId)return box.dataset.hcOriginalId;
    if(box.dataset.hcId)return box.dataset.hcId;
    const s=box.querySelector('.choice');
    return (s?.options?.[0]?.value||s?.options?.[0]?.textContent||box.querySelector('.hc-custom-name')?.textContent||'exercise').trim();
  }
  function cardKey(id){return `${sessionKey()}-${id}`}
  function directRows(box){return [...box.children].filter(x=>x.classList?.contains('setrow')&&!x.classList.contains('head'))}
  function nativeRows(box){return directRows(box).filter(x=>!x.classList.contains('hc-extra-set'))}
  function visibleRows(box){return directRows(box).filter(x=>!x.classList.contains('hc-set-hidden')&&x.style.display!=='none')}

  function entry(id,base){
    const sk=sessionKey();
    if(!state.sessions[sk])state.sessions[sk]={};
    if(!state.sessions[sk][id])state.sessions[sk][id]={count:Math.max(1,base),extra:{}};
    const e=state.sessions[sk][id];
    if(!Number.isFinite(Number(e.count)))e.count=Math.max(1,base);
    e.count=Math.max(1,Math.min(MAX_SETS,Number(e.count)));
    if(!e.extra||typeof e.extra!=='object')e.extra={};
    return e;
  }

  function addStyles(){
    if(document.getElementById('hcSetEditorStylesV2'))return;
    const s=document.createElement('style');s.id='hcSetEditorStylesV2';
    s.textContent=`
      .hc-set-hidden{display:none!important}
      .hc-set-controls{display:flex!important;gap:7px;align-items:center;margin-top:9px;flex-wrap:wrap;padding-top:8px;border-top:1px solid var(--border)}
      .hc-set-btn{border:1px solid var(--border);background:var(--panel);color:var(--text);border-radius:9px;min-height:34px;padding:0 10px;font-size:12px}
      .hc-set-btn.delete{color:var(--bad);border-color:#6f3a3a;background:#2b1717}.hc-set-btn:disabled{opacity:.35}
      .hc-set-count-wrap{display:flex;align-items:center;gap:5px;margin-left:auto;font-size:11px;color:var(--muted)}
      .hc-set-count-input{width:56px!important;min-height:34px!important;padding:5px 7px!important;text-align:center}
      .hc-extra-set input{padding:8px;min-height:39px}
      .hc-complete-toggle{display:none!important}
      .hc-set-done{border:1px solid #3b7152;background:#173624;color:var(--ok);border-radius:999px;min-height:32px;padding:0 10px;font-size:12px;font-weight:700;white-space:nowrap}
      .exercise.hc-ex-collapsed>.hc-set-controls{display:flex!important}
      @media(max-width:520px){.hc-set-btn{flex:1}.hc-set-count-wrap{flex-basis:100%;margin-left:0;justify-content:flex-end}}
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
      persist();updateDone(box,id);
    }));
    const anchor=box.querySelector(':scope > .hc-set-controls')||box.querySelector(':scope > .hc-ex-controls');
    anchor?box.insertBefore(row,anchor):box.appendChild(row);
  }

  function updateDone(box,id){
    const rows=visibleRows(box),inputs=rows.flatMap(r=>[...r.querySelectorAll('input')]);
    const done=inputs.length>0&&inputs.every(i=>String(i.value).trim()!=='');
    const key=cardKey(id);
    box.classList.toggle('hc-ex-complete',done);
    if(!done){expanded.delete(key);box.classList.remove('hc-ex-collapsed')}
    else box.classList.toggle('hc-ex-collapsed',!expanded.has(key));

    let b=box.querySelector(':scope > .exhead .hc-set-done');
    if(done&&!b){
      b=document.createElement('button');b.type='button';b.className='hc-set-done';
      box.querySelector(':scope > .exhead')?.appendChild(b);
      b.addEventListener('click',()=>{expanded.has(key)?expanded.delete(key):expanded.add(key);updateDone(box,id)});
    }
    if(b){b.style.display=done?'':'none';b.textContent=expanded.has(key)?'✓ Done · Hide':'✓ Done · Edit'}
  }

  function trimTo(box,e,newCount){
    directRows(box).forEach((row,i)=>{
      const n=i+1;
      if(n<=newCount)return;
      if(row.classList.contains('hc-extra-set'))delete e.extra[Number(row.dataset.hcExtraSet||n)];
      else clearRow(row);
    });
    Object.keys(e.extra||{}).forEach(k=>{if(Number(k)>newCount)delete e.extra[k]});
  }

  function renderCount(box,id,e,base){
    let count=e.count;
    box.querySelectorAll(':scope > .hc-extra-set,:scope > .hc-set-controls').forEach(x=>x.remove());
    const native=nativeRows(box);
    native.forEach((row,i)=>{
      row.classList.toggle('hc-set-hidden',i>=count);
      const label=row.querySelector(':scope > span');if(label)label.textContent=String(i+1);
    });
    for(let n=base+1;n<=count;n++)extraRow(box,id,n,e);

    const controls=document.createElement('div');controls.className='hc-set-controls';controls.dataset.hcFor=id;
    controls.innerHTML=`<button type="button" class="hc-set-btn delete" data-delete>− Set</button><button type="button" class="hc-set-btn" data-add>+ Set</button><label class="hc-set-count-wrap">Sets <input class="hc-set-count-input" type="number" inputmode="numeric" min="1" max="${MAX_SETS}" value="${count}"></label>`;
    const add=controls.querySelector('[data-add]'),del=controls.querySelector('[data-delete]'),countInput=controls.querySelector('.hc-set-count-input');
    add.disabled=count>=MAX_SETS;del.disabled=count<=1;
    add.addEventListener('click',()=>{e.count=Math.min(MAX_SETS,e.count+1);persist();schedule(0)});
    del.addEventListener('click',()=>{
      if(e.count<=1)return;
      trimTo(box,e,e.count-1);e.count=Math.max(1,e.count-1);persist();schedule(0);
    });
    countInput.addEventListener('change',()=>{
      let next=Math.round(Number(countInput.value));if(!Number.isFinite(next))next=e.count;
      next=Math.max(1,Math.min(MAX_SETS,next));
      if(next<e.count)trimTo(box,e,next);
      e.count=next;persist();schedule(0);
    });
    const exerciseControls=box.querySelector(':scope > .hc-ex-controls');
    exerciseControls?box.insertBefore(controls,exerciseControls):box.appendChild(controls);
  }

  function applyBox(box){
    if(!box||box.style.display==='none')return;
    const id=exerciseId(box);if(!id)return;
    const base=nativeRows(box).length;
    const e=entry(id,base);
    renderCount(box,id,e,base);
    updateDone(box,id);

    if(!box.dataset.hcSetWatchV2){
      box.dataset.hcSetWatchV2='1';
      box.addEventListener('input',()=>updateDone(box,id),true);
      box.addEventListener('change',()=>updateDone(box,id),true);
    }
  }

  function apply(){
    addStyles();refreshState();
    document.querySelectorAll('#exercises .exercise').forEach(applyBox);
  }
  function schedule(delay=70){clearTimeout(timer);timer=setTimeout(apply,delay)}

  function meaningfulMutation(mutations){
    for(const m of mutations){
      if(m.type!=='childList')continue;
      const nodes=[...m.addedNodes,...m.removedNodes].filter(n=>n.nodeType===1);
      for(const n of nodes){
        if(n.matches?.('.hc-set-controls,.hc-extra-set,.hc-set-done'))continue;
        if(n.matches?.('.exercise,.setrow,.exhead,.hc-custom-exercise,.hc-ex-controls,.hc-progression-card'))return true;
        if(n.querySelector?.('.exercise,.setrow,.exhead,.hc-custom-exercise'))return true;
      }
    }
    return false;
  }

  function watchHolder(){
    const holder=document.getElementById('exercises');if(!holder)return;
    observer?.disconnect();
    observer=new MutationObserver(m=>{if(meaningfulMutation(m))schedule(45)});
    observer.observe(holder,{childList:true,subtree:true});
  }

  function start(){
    addStyles();watchHolder();schedule(140);
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day'||e.target?.classList?.contains('choice'))setTimeout(()=>{watchHolder();schedule(80)},60)},true);
    document.addEventListener('click',e=>{
      if(e.target?.closest?.('.weekBtn,.tab,#hcEditExercises,.hc-add-btn,.hc-restore,.hc-reset,.hc-ex-control'))setTimeout(()=>{watchHolder();schedule(90)},80);
    },true);
    document.addEventListener('hc:exercises-rendered',()=>schedule(30));
    window.addEventListener('focus',()=>schedule(80));
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
