(()=>{
  if(window.__hybridCoachExerciseEditor)return;
  window.__hybridCoachExerciseEditor=true;

  const STORAGE_KEY='hybridCoachExerciseLayout_v1';
  const defaults={};
  let editMode=false;
  let applyTimer=null;

  function loadLayout(){
    try{
      const raw=localStorage.getItem(STORAGE_KEY);
      const data=raw?JSON.parse(raw):null;
      if(data&&data.version===1&&data.days)return data;
    }catch{}
    return {version:1,days:{}};
  }

  let layout=loadLayout();

  function saveLayout(){
    try{
      localStorage.setItem(STORAGE_KEY,JSON.stringify(layout));
      window.dispatchEvent(new CustomEvent('hybrid-coach-layout-changed'));
    }catch(err){
      console.warn('Could not save exercise layout',err);
    }
  }

  function dayKey(){return document.getElementById('day')?.value||'Mon'}

  function exerciseId(box){
    const select=box.querySelector('.choice');
    return (select?.options?.[0]?.value||select?.options?.[0]?.textContent||'').trim();
  }

  function ensureDay(day,ids){
    if(!defaults[day]||defaults[day].length!==ids.length||defaults[day].some((x,i)=>x!==ids[i]))defaults[day]=[...ids];
    let cfg=layout.days[day];
    if(!cfg)cfg=layout.days[day]={order:[...ids],removed:[]};
    const known=new Set(ids);
    cfg.order=(Array.isArray(cfg.order)?cfg.order:[]).filter(x=>known.has(x));
    ids.forEach(id=>{if(!cfg.order.includes(id))cfg.order.push(id)});
    cfg.removed=(Array.isArray(cfg.removed)?cfg.removed:[]).filter(x=>known.has(x));
    return cfg;
  }

  function addStyles(){
    if(document.getElementById('hcExerciseEditorStyles'))return;
    const s=document.createElement('style');s.id='hcExerciseEditorStyles';
    s.textContent=`
      .hc-edit-btn{border:1px solid var(--border);background:var(--panel);color:var(--text);border-radius:9px;min-height:34px;padding:0 10px;font-size:12px}
      .hc-edit-btn.active{background:#1d3352;border-color:#4d78b3}
      .hc-ex-controls{display:none;gap:6px;align-items:center;flex-wrap:wrap;margin:8px 0 2px;padding-top:8px;border-top:1px solid var(--border)}
      .hc-ex-editing .hc-ex-controls{display:flex}
      .hc-ex-control{border:1px solid var(--border);background:var(--panel);color:var(--text);border-radius:8px;min-height:34px;padding:0 10px;font-size:12px}
      .hc-ex-control.remove{margin-left:auto;color:var(--bad);border-color:#6f3a3a;background:#2b1717}
      .hc-ex-toolbar{display:none;margin:0 0 10px;padding:10px;border:1px solid var(--border);background:var(--panel);border-radius:11px;font-size:12px}
      .hc-ex-editing .hc-ex-toolbar{display:block}
      .hc-removed-list{display:grid;gap:6px;margin-top:8px}
      .hc-removed-row{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:6px 0;border-top:1px solid var(--border)}
      .hc-restore{border:1px solid var(--border);background:var(--card);color:var(--text);border-radius:8px;min-height:32px;padding:0 9px;font-size:12px}
      .hc-reset{border:0;background:transparent;color:var(--accent);padding:4px 0;font-size:12px}
      @media(max-width:520px){.hc-ex-control{flex:1}.hc-ex-control.remove{margin-left:0;flex-basis:100%}}
    `;
    document.head.appendChild(s);
  }

  function moveExercise(id,dir){
    const day=dayKey(),cfg=layout.days[day];if(!cfg)return;
    const visible=cfg.order.filter(x=>!cfg.removed.includes(x));
    const i=visible.indexOf(id),j=i+dir;if(i<0||j<0||j>=visible.length)return;
    const other=visible[j],a=cfg.order.indexOf(id),b=cfg.order.indexOf(other);
    [cfg.order[a],cfg.order[b]]=[cfg.order[b],cfg.order[a]];
    saveLayout();scheduleApply(0);
  }

  function removeExercise(id){
    const day=dayKey(),cfg=layout.days[day];if(!cfg||cfg.removed.includes(id))return;
    cfg.removed.push(id);saveLayout();scheduleApply(0);
  }

  function restoreExercise(id){
    const day=dayKey(),cfg=layout.days[day];if(!cfg)return;
    cfg.removed=cfg.removed.filter(x=>x!==id);saveLayout();scheduleApply(0);
  }

  function resetDay(){
    const day=dayKey(),base=defaults[day];if(!base)return;
    layout.days[day]={order:[...base],removed:[]};saveLayout();scheduleApply(0);
  }

  function toolbar(section,cfg){
    let t=section.querySelector('.hc-ex-toolbar');
    if(!t){t=document.createElement('div');t.className='hc-ex-toolbar';section.querySelector('.section-title')?.after(t)}
    const removed=cfg.removed||[];
    t.innerHTML=`<div style="display:flex;align-items:center;justify-content:space-between;gap:8px"><strong>Customize this lifting day</strong><button type="button" class="hc-reset">Reset to default</button></div><div class="tiny" style="margin-top:3px">Use ↑ and ↓ to change exercise order. Remove hides an exercise from this day across future weeks.</div>${removed.length?`<div class="hc-removed-list"><div class="tiny">Removed exercises</div>${removed.map(id=>`<div class="hc-removed-row"><span>${escapeHtml(id)}</span><button type="button" class="hc-restore" data-restore="${escapeAttr(id)}">Restore</button></div>`).join('')}</div>`:''}`;
    t.querySelector('.hc-reset')?.addEventListener('click',resetDay);
    t.querySelectorAll('[data-restore]').forEach(b=>b.addEventListener('click',()=>restoreExercise(b.dataset.restore)));
  }

  function escapeHtml(v){return String(v).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]))}
  function escapeAttr(v){return String(v).replace(/&/g,'&amp;').replace(/"/g,'&quot;')}

  function apply(){
    addStyles();
    const holder=document.getElementById('exercises'),liftDone=document.getElementById('liftDone');
    if(!holder||!liftDone)return;
    const section=liftDone.closest('section');if(!section)return;
    section.classList.toggle('hc-ex-editing',editMode);

    const boxes=[...holder.children].filter(x=>x.classList?.contains('exercise'));
    if(!boxes.length)return;
    const ids=boxes.map(exerciseId).filter(Boolean),day=dayKey(),cfg=ensureDay(day,ids);
    const byId=new Map(boxes.map(b=>[exerciseId(b),b]));

    cfg.order.forEach(id=>{const box=byId.get(id);if(box)holder.appendChild(box)});

    const visible=cfg.order.filter(id=>!cfg.removed.includes(id));
    cfg.order.forEach(id=>{
      const box=byId.get(id);if(!box)return;
      box.style.display=cfg.removed.includes(id)?'none':'';
      box.querySelector('.hc-ex-controls')?.remove();
      if(cfg.removed.includes(id))return;
      const controls=document.createElement('div');controls.className='hc-ex-controls';
      const pos=visible.indexOf(id);
      controls.innerHTML=`<button type="button" class="hc-ex-control" data-up ${pos===0?'disabled':''}>↑ Move up</button><button type="button" class="hc-ex-control" data-down ${pos===visible.length-1?'disabled':''}>↓ Move down</button><button type="button" class="hc-ex-control remove" data-remove>Remove exercise</button>`;
      controls.querySelector('[data-up]')?.addEventListener('click',()=>moveExercise(id,-1));
      controls.querySelector('[data-down]')?.addEventListener('click',()=>moveExercise(id,1));
      controls.querySelector('[data-remove]')?.addEventListener('click',()=>removeExercise(id));
      box.appendChild(controls);
    });

    const title=section.querySelector('.section-title');
    let edit=title?.querySelector('#hcEditExercises');
    if(title&&!edit){
      edit=document.createElement('button');edit.type='button';edit.id='hcEditExercises';edit.className='hc-edit-btn';title.appendChild(edit);
      edit.addEventListener('click',()=>{editMode=!editMode;scheduleApply(0)});
    }
    if(edit){edit.textContent=editMode?'Done editing':'Edit exercises';edit.classList.toggle('active',editMode)}
    toolbar(section,cfg);
  }

  function scheduleApply(delay=35){clearTimeout(applyTimer);applyTimer=setTimeout(apply,delay)}

  function start(){
    addStyles();scheduleApply(50);
    const root=document.getElementById('workout');
    if(root)new MutationObserver(()=>scheduleApply(25)).observe(root,{childList:true});
    document.addEventListener('change',e=>{if(e.target?.id==='day'||e.target?.id==='week')scheduleApply(40)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.weekBtn,.tab'))scheduleApply(80)},true);
    window.addEventListener('hybrid-coach-layout-restored',()=>{layout=loadLayout();scheduleApply(0)});
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
  else start();
})();
