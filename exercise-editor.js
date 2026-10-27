(()=>{
  if(window.__hybridCoachExerciseEditor)return;
  window.__hybridCoachExerciseEditor=true;

  const STORAGE_KEY='hybridCoachExerciseLayout_v1';
  const TRAINING_KEY='hybridCoachData_v1';
  const defaults={};
  const expandedCompleted=new Set();
  const completionState=new Map();
  let editMode=false;
  let applyTimer=null;

  function validLayout(data){return !!(data&&(data.version===1||data.version===2)&&data.days&&typeof data.days==='object')}
  function blankLayout(){return {version:2,days:{}}}
  function blankExtras(){return {version:1,days:{}}}

  function readTraining(){
    try{const raw=localStorage.getItem(TRAINING_KEY);return raw?JSON.parse(raw):null}catch{return null}
  }

  function loadLayout(){
    try{
      const raw=localStorage.getItem(STORAGE_KEY),data=raw?JSON.parse(raw):null;
      if(validLayout(data)){data.version=2;return data}
    }catch{}
    const training=readTraining();
    if(validLayout(training?.exerciseLayout)){
      const data=training.exerciseLayout;data.version=2;
      try{localStorage.setItem(STORAGE_KEY,JSON.stringify(data))}catch{}
      return data;
    }
    return blankLayout();
  }

  let layout=loadLayout();
  let extras=(()=>{const d=readTraining()?.exerciseExtras;return d&&d.version===1&&d.days?d:blankExtras()})();
  const nativeSetItem=Storage.prototype.setItem;

  function mergeAddons(data){
    if(!data||typeof data!=='object')return data;
    data.exerciseLayout=layout;
    data.exerciseExtras=extras;
    return data;
  }

  function embedAddons(){
    try{
      const raw=localStorage.getItem(TRAINING_KEY);if(!raw)return;
      const data=mergeAddons(JSON.parse(raw));
      nativeSetItem.call(localStorage,TRAINING_KEY,JSON.stringify(data));
    }catch(err){console.warn('Could not embed exercise customization in training backup',err)}
  }

  if(!window.__hybridCoachLayoutStorageBridge){
    window.__hybridCoachLayoutStorageBridge=true;
    Storage.prototype.setItem=function(key,value){
      if(this===localStorage&&key===TRAINING_KEY){
        try{value=JSON.stringify(mergeAddons(JSON.parse(String(value))))}catch{}
      }
      return nativeSetItem.call(this,key,value);
    };
  }

  function notifySave(){
    embedAddons();
    document.dispatchEvent(new Event('input',{bubbles:true}));
  }

  function saveLayout(){
    try{nativeSetItem.call(localStorage,STORAGE_KEY,JSON.stringify(layout));notifySave()}
    catch(err){console.warn('Could not save exercise layout',err)}
  }

  function saveExtras(){
    try{notifySave()}catch(err){console.warn('Could not save custom exercise log',err)}
  }

  function dayKey(){return document.getElementById('day')?.value||'Mon'}
  function weekKey(){return document.getElementById('week')?.value||'0'}
  function sessionKey(){return `${weekKey()}-${dayKey()}`}
  function cardKey(id){return `${sessionKey()}-${id}`}

  function builtInId(box){
    const select=box.querySelector('.choice');
    return (select?.options?.[0]?.value||select?.options?.[0]?.textContent||'').trim();
  }
  function exerciseId(box){return box.dataset.hcId||builtInId(box)}

  function customList(cfg){return Array.isArray(cfg.custom)?cfg.custom:[]}
  function ensureDay(day,builtInIds){
    if(!defaults[day])defaults[day]=[...builtInIds];
    let cfg=layout.days[day];
    if(!cfg)cfg=layout.days[day]={order:[...builtInIds],removed:[],custom:[]};
    if(!Array.isArray(cfg.custom))cfg.custom=[];
    const allIds=[...builtInIds,...cfg.custom.map(x=>x.id).filter(Boolean)];
    const known=new Set(allIds);
    cfg.order=(Array.isArray(cfg.order)?cfg.order:[]).filter(x=>known.has(x));
    allIds.forEach(id=>{if(!cfg.order.includes(id))cfg.order.push(id)});
    cfg.removed=(Array.isArray(cfg.removed)?cfg.removed:[]).filter(x=>known.has(x));
    return cfg;
  }

  function addStyles(){
    if(document.getElementById('hcExerciseEditorStyles'))return;
    const s=document.createElement('style');s.id='hcExerciseEditorStyles';
    s.textContent=`
      .hc-edit-btn,.hc-add-btn{border:1px solid var(--border);background:var(--panel);color:var(--text);border-radius:9px;min-height:34px;padding:0 10px;font-size:12px}
      .hc-edit-btn.active{background:#1d3352;border-color:#4d78b3}
      .hc-ex-controls{display:none;gap:6px;align-items:center;flex-wrap:wrap;margin:8px 0 2px;padding-top:8px;border-top:1px solid var(--border)}
      .hc-ex-editing .hc-ex-controls{display:flex}
      .hc-ex-control{border:1px solid var(--border);background:var(--panel);color:var(--text);border-radius:8px;min-height:34px;padding:0 10px;font-size:12px}
      .hc-ex-control:disabled{opacity:.35}.hc-ex-control.remove{margin-left:auto;color:var(--bad);border-color:#6f3a3a;background:#2b1717}
      .hc-ex-toolbar{display:none;margin:0 0 10px;padding:10px;border:1px solid var(--border);background:var(--panel);border-radius:11px;font-size:12px}
      .hc-ex-editing .hc-ex-toolbar{display:block}.hc-toolbar-actions{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
      .hc-removed-list{display:grid;gap:6px;margin-top:8px}.hc-removed-row{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:6px 0;border-top:1px solid var(--border)}
      .hc-restore{border:1px solid var(--border);background:var(--card);color:var(--text);border-radius:8px;min-height:32px;padding:0 9px;font-size:12px}
      .hc-reset{border:0;background:transparent;color:var(--accent);padding:4px 0;font-size:12px}
      .hc-complete-toggle{border:1px solid #3b7152;background:#173624;color:var(--ok);border-radius:999px;min-height:32px;padding:0 10px;font-size:12px;font-weight:700;white-space:nowrap}
      .exercise.hc-ex-complete{border-color:#3b7152}.exercise.hc-ex-complete .exmain:before{content:'✓ ';color:var(--ok);font-weight:800}
      .exercise.hc-ex-collapsed>.setrow,.exercise.hc-ex-collapsed>.how,.exercise.hc-ex-collapsed>.hc-custom-help{display:none!important}
      .hc-custom-exercise .hc-custom-name{display:block;font-size:16px}.hc-custom-exercise .hc-custom-meta{margin-top:4px}
      .hc-custom-dialog{border:1px solid var(--border);border-radius:18px;background:var(--card);color:var(--text);width:min(430px,calc(100% - 24px));padding:0;box-shadow:0 30px 90px rgba(0,0,0,.45)}
      .hc-custom-dialog::backdrop{background:rgba(0,0,0,.68);backdrop-filter:blur(4px)}.hc-custom-dialog form{padding:18px}.hc-custom-dialog h2{margin:0 0 6px}.hc-custom-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:10px}.hc-custom-actions{display:flex;justify-content:flex-end;gap:8px;margin-top:14px}
      @media(max-width:520px){.hc-ex-control{flex:1}.hc-ex-control.remove{margin-left:0;flex-basis:100%}.hc-custom-grid{grid-template-columns:1fr}}
    `;
    document.head.appendChild(s);
  }

  function escapeHtml(v){return String(v).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]))}
  function escapeAttr(v){return String(v).replace(/&/g,'&amp;').replace(/"/g,'&quot;')}
  function safeInt(v,min,max,fallback){const n=Math.round(Number(v));return Number.isFinite(n)?Math.max(min,Math.min(max,n)):fallback}

  function moveExercise(id,dir){
    const cfg=layout.days[dayKey()];if(!cfg)return;
    const visible=cfg.order.filter(x=>!cfg.removed.includes(x));
    const i=visible.indexOf(id),j=i+dir;if(i<0||j<0||j>=visible.length)return;
    const other=visible[j],a=cfg.order.indexOf(id),b=cfg.order.indexOf(other);
    [cfg.order[a],cfg.order[b]]=[cfg.order[b],cfg.order[a]];saveLayout();scheduleApply(0);
  }
  function removeExercise(id){const cfg=layout.days[dayKey()];if(!cfg||cfg.removed.includes(id))return;cfg.removed.push(id);saveLayout();scheduleApply(0)}
  function restoreExercise(id){const cfg=layout.days[dayKey()];if(!cfg)return;cfg.removed=cfg.removed.filter(x=>x!==id);saveLayout();scheduleApply(0)}
  function resetDay(){
    const day=dayKey(),base=defaults[day],cfg=layout.days[day];if(!base||!cfg)return;
    const customs=customList(cfg).map(x=>x.id);cfg.order=[...base,...customs];cfg.removed=[];saveLayout();scheduleApply(0);
  }

  function addDialog(){
    if(document.getElementById('hcCustomDialog'))return;
    const d=document.createElement('dialog');d.id='hcCustomDialog';d.className='hc-custom-dialog';
    d.innerHTML=`<form method="dialog" id="hcCustomForm"><h2>Add custom exercise</h2><div class="tiny">This exercise will be available on this lifting day across future weeks.</div><label style="display:block;margin-top:10px">Exercise name<input id="hcCustomName" required placeholder="e.g. Incline Smith press"></label><div class="hc-custom-grid"><label>Sets<input id="hcCustomSets" type="number" min="1" max="12" value="3" required></label><label>Rep target<input id="hcCustomReps" placeholder="8–12" value="8–12" required></label></div><div class="hc-custom-actions"><button type="button" class="btn" id="hcCustomCancel">Cancel</button><button type="submit" class="btn primary">Add exercise</button></div></form>`;
    document.body.appendChild(d);
    d.querySelector('#hcCustomCancel').onclick=()=>d.close();
    d.querySelector('#hcCustomForm').addEventListener('submit',e=>{
      e.preventDefault();
      const name=d.querySelector('#hcCustomName').value.trim();if(!name)return;
      const sets=safeInt(d.querySelector('#hcCustomSets').value,1,12,3),reps=d.querySelector('#hcCustomReps').value.trim()||'8–12';
      const cfg=layout.days[dayKey()];if(!cfg)return;
      const id=`custom-${Date.now().toString(36)}-${Math.random().toString(36).slice(2,7)}`;
      cfg.custom=customList(cfg);cfg.custom.push({id,name,sets,reps});cfg.order.push(id);cfg.removed=cfg.removed.filter(x=>x!==id);
      saveLayout();d.close();d.querySelector('#hcCustomName').value='';scheduleApply(0);
    });
  }
  function openAdd(){addDialog();document.getElementById('hcCustomDialog')?.showModal()}

  function toolbar(section,cfg){
    let t=section.querySelector('.hc-ex-toolbar');if(!t){t=document.createElement('div');t.className='hc-ex-toolbar';section.querySelector('.section-title')?.after(t)}
    const removed=cfg.removed||[],nameFor=id=>customList(cfg).find(x=>x.id===id)?.name||id;
    t.innerHTML=`<div class="hc-toolbar-actions"><strong style="margin-right:auto">Customize this lifting day</strong><button type="button" class="hc-add-btn">+ Add custom exercise</button><button type="button" class="hc-reset">Reset order</button></div><div class="tiny" style="margin-top:5px">Use ↑ and ↓ to reorder. Remove hides an exercise; you can restore it here later.</div>${removed.length?`<div class="hc-removed-list"><div class="tiny">Removed exercises</div>${removed.map(id=>`<div class="hc-removed-row"><span>${escapeHtml(nameFor(id))}</span><button type="button" class="hc-restore" data-restore="${escapeAttr(id)}">Restore</button></div>`).join('')}</div>`:''}`;
    t.querySelector('.hc-add-btn')?.addEventListener('click',openAdd);t.querySelector('.hc-reset')?.addEventListener('click',resetDay);
    t.querySelectorAll('[data-restore]').forEach(b=>b.addEventListener('click',()=>restoreExercise(b.dataset.restore)));
  }

  function customSession(){
    const sk=sessionKey();if(!extras.days[sk])extras.days[sk]={};return extras.days[sk];
  }
  function customLog(id,sets){
    const s=customSession();if(!s[id])s[id]={sets:{}};if(!s[id].sets)s[id].sets={};
    for(let i=1;i<=sets;i++)if(!s[id].sets[i])s[id].sets[i]={w:'',r:'',rir:''};
    return s[id];
  }

  function renderCustom(holder,def){
    let box=holder.querySelector(`.hc-custom-exercise[data-hc-id="${CSS.escape(def.id)}"]`);
    const log=customLog(def.id,def.sets);
    if(!box){
      box=document.createElement('div');box.className='exercise hc-custom-exercise';box.dataset.hcId=def.id;
      holder.appendChild(box);
    }
    const currentFocused=document.activeElement?.closest?.('.hc-custom-exercise')===box;
    if(!currentFocused){
      box.innerHTML=`<div class="exhead"><div class="exmain"><strong class="hc-custom-name">${escapeHtml(def.name)}</strong><div class="tiny hc-custom-meta">Custom exercise · ${def.sets}×${escapeHtml(def.reps)}</div></div></div><div class="setrow head"><span>Set</span><span>Weight</span><span>Reps</span><span>RIR</span></div>${Array.from({length:def.sets},(_,i)=>{const n=i+1,v=log.sets[n]||{};return `<div class="setrow" data-custom-set="${n}"><span>${n}</span><input type="number" inputmode="decimal" placeholder="lb" data-field="w" value="${escapeAttr(v.w||'')}"><input type="number" inputmode="numeric" placeholder="reps" data-field="r" value="${escapeAttr(v.r||'')}"><input type="number" inputmode="numeric" placeholder="RIR" data-field="rir" value="${escapeAttr(v.rir??'')}"></div>`}).join('')}`;
      box.querySelectorAll('[data-custom-set] input').forEach(input=>input.addEventListener('input',()=>{
        const row=input.closest('[data-custom-set]'),n=row.dataset.customSet,field=input.dataset.field;customLog(def.id,def.sets).sets[n][field]=input.value;saveExtras();evaluateCompletion(box,def.id,true);
      }));
    }
    return box;
  }

  function setInputs(box){return [...box.querySelectorAll('.setrow:not(.head) input')]}
  function isComplete(box){const inputs=setInputs(box);return inputs.length>0&&inputs.every(i=>String(i.value).trim()!=='')}
  function evaluateCompletion(box,id,fromInput=false){
    const key=cardKey(id),complete=isComplete(box),was=completionState.get(key);completionState.set(key,complete);
    box.classList.toggle('hc-ex-complete',complete);
    if(!complete){expandedCompleted.delete(key);box.classList.remove('hc-ex-collapsed')}
    else{
      if(was===undefined||(!was&&fromInput))expandedCompleted.delete(key);
      box.classList.toggle('hc-ex-collapsed',!expandedCompleted.has(key));
    }
    let toggle=box.querySelector('.hc-complete-toggle');
    if(complete&&!toggle){toggle=document.createElement('button');toggle.type='button';toggle.className='hc-complete-toggle';box.querySelector('.exhead')?.appendChild(toggle);toggle.addEventListener('click',()=>{expandedCompleted.has(key)?expandedCompleted.delete(key):expandedCompleted.add(key);scheduleApply(0)})}
    if(toggle){toggle.style.display=complete?'':'none';toggle.textContent=expandedCompleted.has(key)?'✓ Done · Hide':'✓ Done · Edit'}
  }

  function controlsFor(box,id,pos,last){
    box.querySelector('.hc-ex-controls')?.remove();
    const controls=document.createElement('div');controls.className='hc-ex-controls';
    controls.innerHTML=`<button type="button" class="hc-ex-control" data-up ${pos===0?'disabled':''}>↑ Move up</button><button type="button" class="hc-ex-control" data-down ${pos===last?'disabled':''}>↓ Move down</button><button type="button" class="hc-ex-control remove" data-remove>Remove exercise</button>`;
    controls.querySelector('[data-up]')?.addEventListener('click',()=>moveExercise(id,-1));controls.querySelector('[data-down]')?.addEventListener('click',()=>moveExercise(id,1));controls.querySelector('[data-remove]')?.addEventListener('click',()=>removeExercise(id));box.appendChild(controls);
  }

  function apply(){
    addStyles();addDialog();
    const holder=document.getElementById('exercises'),liftDone=document.getElementById('liftDone');if(!holder||!liftDone)return;
    const section=liftDone.closest('section');if(!section)return;section.classList.toggle('hc-ex-editing',editMode);

    const builtBoxes=[...holder.children].filter(x=>x.classList?.contains('exercise')&&!x.classList.contains('hc-custom-exercise'));
    if(!builtBoxes.length)return;
    builtBoxes.forEach(b=>{if(!b.dataset.hcId)b.dataset.hcId=builtInId(b)});
    const builtIds=builtBoxes.map(exerciseId).filter(Boolean),cfg=ensureDay(dayKey(),builtIds);
    const customBoxes=customList(cfg).map(def=>renderCustom(holder,def));
    const allBoxes=[...builtBoxes,...customBoxes],byId=new Map(allBoxes.map(b=>[exerciseId(b),b]));
    cfg.order.forEach(id=>{const box=byId.get(id);if(box)holder.appendChild(box)});

    const visible=cfg.order.filter(id=>!cfg.removed.includes(id));
    cfg.order.forEach(id=>{
      const box=byId.get(id);if(!box)return;box.style.display=cfg.removed.includes(id)?'none':'';if(cfg.removed.includes(id))return;
      controlsFor(box,id,visible.indexOf(id),visible.length-1);evaluateCompletion(box,id,false);
      if(!box.dataset.hcCompletionWatch){box.dataset.hcCompletionWatch='1';box.addEventListener('input',()=>evaluateCompletion(box,id,true),true)}
    });

    const title=section.querySelector('.section-title');let edit=title?.querySelector('#hcEditExercises');
    if(title&&!edit){edit=document.createElement('button');edit.type='button';edit.id='hcEditExercises';edit.className='hc-edit-btn';title.appendChild(edit);edit.addEventListener('click',()=>{editMode=!editMode;scheduleApply(0)})}
    if(edit){edit.textContent=editMode?'Done editing':'Edit exercises';edit.classList.toggle('active',editMode)}
    toolbar(section,cfg);embedAddons();
  }

  function scheduleApply(delay=35){clearTimeout(applyTimer);applyTimer=setTimeout(apply,delay)}
  function start(){
    addStyles();addDialog();embedAddons();scheduleApply(50);
    const root=document.getElementById('workout');if(root)new MutationObserver(()=>scheduleApply(30)).observe(root,{childList:true});
    document.addEventListener('change',e=>{if(e.target?.id==='day'||e.target?.id==='week')scheduleApply(50)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.weekBtn,.tab'))scheduleApply(80)},true);
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
