(()=>{
  if(window.__hybridCoachProgressionV3)return;
  window.__hybridCoachProgressionV3=true;

  const TRAINING_KEY='hybridCoachData_v1';
  const TARGET=0.10;
  const DAY_INDEX={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6};
  const DAY_VALUE_MAP={UpperThu:'Wed',LegsFri:'Thu',RestWed:'Wed'};
  const DAY_ORDER={
    Mon:['Flat barbell bench press','Incline dumbbell press','Weighted dip — chest bias','Seated dumbbell shoulder press','Chest-supported lateral raise','Standing lateral raise','Single-arm cable rear-delt fly','Close-grip bench press','Overhead cable triceps extension','Rope pressdown','Push-up plus'],
    Tue:['Weighted pull-up / neutral pulldown','Chest-supported T-bar row','Single-arm cable lat row — elbow to hip','Wide high row','Straight-arm cable pulldown','Dumbbell shrug','Cable Y-raise','Reverse pec deck','Face pull with external rotation','Incline dumbbell curl','Preacher curl','Hammer curl','Reverse EZ-bar curl','Farmer carry'],
    Wed:['Paused bench press','Low-to-high cable fly','Neutral-grip pulldown','Chest-supported machine row','Cable lateral raise','Cable rear-delt fly','Rope pressdown','Cable curl','Cable external rotation'],
    Thu:['Back squat / hack squat','Romanian deadlift','Leg press','Bulgarian split squat','Leg extension','Seated leg curl','Hip thrust','Standing calf raise','Seated soleus raise','Cable crunch / ab wheel']
  };
  const MANUAL_CLEARED=new Set();
  let timer=null;

  function state(){try{const raw=localStorage.getItem(TRAINING_KEY);return raw?JSON.parse(raw):null}catch{return null}}
  function week(){return Number(document.getElementById('week')?.value||0)}
  function rawDay(){return document.getElementById('day')?.value||'Mon'}
  function day(){return DAY_VALUE_MAP[rawDay()]||rawDay()}
  function esc(v){return String(v??'').replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]))}

  function normalizeName(v){
    return String(v||'').toLowerCase()
      .replace(/[–—]/g,'-')
      .replace(/[^a-z0-9]+/g,' ')
      .replace(/\bmachine\b/g,'machine')
      .replace(/\s+/g,' ')
      .trim();
  }

  const ALIAS_GROUPS=[
    ['Flat barbell bench press','Bench Press — Barbell','Barbell Bench Press','Barbell bench press'],
    ['Incline dumbbell press','Bench Press — Incline — Dumbbell','Incline Dumbbell Bench Press','Incline DB Press'],
    ['Overhead Press — Barbell','Barbell Overhead Press','Standing Barbell Overhead Press'],
    ['Machine Chest Fly / Pec Deck','Machine Chest Fly','Pec Deck','Pec Deck Fly'],
    ['Reverse Pec Deck — Rear-Delt Bias','Reverse pec deck','Reverse Pec Deck','Machine Shoulder Fly — Rear-Delt Setup'],
    ['Close-grip bench press','Close-Grip Chest Press — Barbell','Close-Grip Bench Press','Smith Close-Grip Bench Press'],
    ['EZ-Bar Skull Crusher','EZ Bar Skull Crusher','Lying EZ-Bar Triceps Extension'],
    ['Rope pressdown','Triceps Pulldown — Rope','Rope Pressdown','Triceps Pressdown — Rope'],
    ['Push-up plus','Push-Up Plus / Serratus Punch','Push Up Plus'],
    ['Lat Pulldown — Wide-Grip Front Pull','Wide-Grip Lat Pulldown','Wide Grip Lat Pulldown','Wide-Grip Front Pulldown'],
    ['Seated Row','Seated Cable Row','Seated Plate-Loaded Row'],
    ['Smith or Dumbbell Shrug','Dumbbell shrug','Dumbbell Shrug','DB Shrug'],
    ['Cable Face Pull + External Rotation','Face Pull with External Rotation'],
    ['Independent-Arm Plate-Loaded Row — Right / Left','Independent Arm Plate Loaded Row','Iso-Lateral Row Machine'],
    ['Straight-arm cable pulldown','Straight-Arm Cable Pulldown / Pullover','Straight Arm Cable Pulldown','Rope Straight-Arm Pulldown'],
    ['Cable Y-raise','Cable Y-Raise / Trap-3 Raise','Cable Y Raise','Trap-3 Raise'],
    ['Face pull with external rotation','Cable Face Pull + External Rotation','Face Pull + External Rotation'],
    ['Preacher curl','Preacher Curl','Machine Preacher Curl','EZ-Bar Preacher Curl'],
    ['Hammer curl','Hammer Curl — Dumbbell','Dumbbell Hammer Curl'],
    ['Reverse EZ-bar curl','Reverse EZ-Bar Curl','Reverse EZ Bar Curl'],
    ['Paused bench press','Paused Bench Press'],
    ['Low-to-high cable fly','Low-to-High Cable Fly'],
    ['Neutral-grip pulldown','Neutral-Grip Pulldown'],
    ['Chest-supported machine row','Chest-Supported Machine Row'],
    ['Cable lateral raise','Cable Lateral Raise'],
    ['Cable rear-delt fly','Cable Rear-Delt Fly'],
    ['Cable curl','Cable Curl'],
    ['Cable external rotation','Cable External Rotation'],
    ['Back squat / hack squat','Back Squat','Hack Squat'],
    ['Romanian deadlift','Romanian Deadlift','RDL'],
    ['Leg press','Leg Press'],
    ['Bulgarian split squat','Bulgarian Split Squat'],
    ['Leg extension','Leg Extension'],
    ['Seated leg curl','Seated Leg Curl'],
    ['Hip thrust','Hip Thrust'],
    ['Standing calf raise','Standing Calf Raise'],
    ['Seated soleus raise','Seated Calf Raise','Seated Soleus Raise'],
    ['Cable crunch / ab wheel','Cable Crunch','Ab Wheel']
  ];
  // A variation can be related without having comparable loads. Never silently
  // copy dumbbell/cable/machine weights between distinct implements.
  const VARIANTS=[
    {names:['Lat Pulldown — Wide-Grip Front Pull','Neutral-grip lat pulldown','Neutral-Grip Pulldown','Wide Neutral-Grip Pulldown'],transfer:true,factor:.90,label:'pulldown grip variation'},
    {names:['Chest-Supported High Row — Elbows ~45°','Wide high row','Wide-Grip High Row'],transfer:false,label:'high-row variation'},
    {names:['Independent-Arm Plate-Loaded Row — Right / Left','1-arm DB row — lat bias','Single-arm cable lat row — elbow to hip'],transfer:false,label:'different unilateral-row equipment'},
    {names:['Seated Row','Seal row','Chest-supported T-bar row'],transfer:false,label:'different horizontal-row equipment'},
    {names:['Bayesian Cable Curl','Incline dumbbell curl'],transfer:false,label:'different curl equipment'},
  ];
  function variantFor(a,b){
    if(!a||!b||sameMovement(a,b))return null;
    return VARIANTS.find(v=>v.names.some(n=>normalizeName(n)===normalizeName(a))&&v.names.some(n=>normalizeName(n)===normalizeName(b)))||null;
  }
  const ALIAS=new Map();
  ALIAS_GROUPS.forEach((g,i)=>g.forEach(n=>ALIAS.set(normalizeName(n),`g${i}`)));
  function movementKey(v){const n=normalizeName(v);return ALIAS.get(n)||`name:${n}`}
  function sameMovement(a,b){return !!a&&!!b&&movementKey(a)===movementKey(b)}

  function roundLoad(v){
    if(!Number.isFinite(v)||v<=0)return 0;
    if(v<30)return Math.max(1,Math.round(v));
    return Math.max(5,Math.round(v/5)*5);
  }
  function parseRange(box){
    const meta=box.querySelector('.hc-custom-meta')||box.querySelector('.exmain .tiny');
    const t=meta?.textContent||'';
    const m=t.match(/×\s*(\d+)(?:\s*[–-]\s*(\d+))?/);
    if(!m)return {lo:1,hi:99};
    return {lo:Number(m[1]),hi:Number(m[2]||m[1])};
  }
  function exerciseInfo(box){
    const original=(box.dataset.hcOriginalId||box.dataset.hcId||box.querySelector('.choice')?.options?.[0]?.value||box.querySelector('.hc-custom-name')?.textContent||'').trim();
    const selected=(box.querySelector('.choice')?.value||box.querySelector('.hc-custom-name')?.textContent||original).trim();
    const custom=original.startsWith('custom-')||box.classList.contains('hc-custom-exercise');
    const idx=custom?-1:(DAY_ORDER[day()]||[]).indexOf(original);
    return {id:original,selected,custom,idx,key:movementKey(selected)};
  }

  function configuredCount(s,sk,id){
    const e=s?.setEditor?.sessions?.[sk]?.[id];
    return Math.max(1,Number(e?.count)||99);
  }
  function nativeSetsAt(s,w,d,idx,id){
    const sk=`${w}-${d}`,x=s?.days?.[sk];if(!x)return [];
    const count=configuredCount(s,sk,id),vals=[];
    Object.entries(x.sets||{}).forEach(([k,v])=>{
      const m=k.match(/^(\d+)-(\d+)$/);if(!m||Number(m[1])!==idx||Number(m[2])>count)return;
      if(!v||String(v.r??'').trim()==='')return;
      vals.push({n:Number(m[2]),w:Number(v.w)||0,r:Number(v.r)||0,rir:String(v.rir??'').trim()===''?null:Number(v.rir)});
    });
    vals.sort((a,b)=>a.n-b.n);
    const e=s?.setEditor?.sessions?.[sk]?.[id];
    if(e?.extra){
      Object.entries(e.extra).forEach(([n,v])=>{
        if(Number(n)>count||!v||String(v.r??'').trim()==='')return;
        vals.push({n:Number(n),w:Number(v.w)||0,r:Number(v.r)||0,rir:String(v.rir??'').trim()===''?null:Number(v.rir)});
      });
      vals.sort((a,b)=>a.n-b.n);
    }
    return vals.filter(x=>x.r>0);
  }
  function customSetsAt(s,w,d,id){
    const sk=`${w}-${d}`,log=s?.exerciseExtras?.days?.[sk]?.[id];if(!log?.sets)return [];
    const count=configuredCount(s,sk,id),vals=[];
    Object.entries(log.sets).forEach(([n,v])=>{
      if(Number(n)>count||!v||String(v.r??'').trim()==='')return;
      vals.push({n:Number(n),w:Number(v.w)||0,r:Number(v.r)||0,rir:String(v.rir??'').trim()===''?null:Number(v.rir)});
    });
    vals.sort((a,b)=>a.n-b.n);
    return vals.filter(x=>x.r>0);
  }
  function historicalSelection(x,d,idx){return String(x?.choice?.[idx]||DAY_ORDER[d]?.[idx]||'').trim()}
  function currentOrdinal(){return week()*7+(DAY_INDEX[day()]??0)}

  // Search logged built-in AND custom movements across all earlier sessions.
  // The layout may rename a movement or turn it into a custom row; position alone
  // is not evidence that two exercises use comparable weights.
  function latestHistory(s,info){
    const found=[];
    const keys=new Set([...Object.keys(s?.days||{}),...Object.keys(s?.exerciseExtras?.days||{})]);
    function consider(selected,sets,sk,ord,source){
      if(!sets?.length||!selected)return;
      const exact=sameMovement(selected,info.selected),variant=exact?null:variantFor(selected,info.selected);
      if(!exact&&!variant)return;
      found.push({selected,sets,sessionKey:sk,ordinal:ord,source,match:exact?'exact':'variation',variation:variant});
    }
    keys.forEach(sk=>{
      const m=sk.match(/^(\\d+)-(Mon|Tue|Wed|Thu|Fri|Sat|Sun|UpperThu|LegsFri)$/);
      if(!m)return;
      const w=Number(m[1]),d=DAY_VALUE_MAP[m[2]]||m[2],ord=w*7+(DAY_INDEX[m[2]]??DAY_INDEX[d]??0);
      if(ord>=currentOrdinal())return;
      const x=s?.days?.[sk];
      if(x){
        (DAY_ORDER[d]||[]).forEach((id,idx)=>{
          const selected=historicalSelection(x,d,idx);
          if(!sameMovement(selected,info.selected)&&!variantFor(selected,info.selected))return;
          const sets=nativeSetsAt(s,w,m[2],idx,id);
          consider(selected,sets,sk,ord,'Health Coach');
        });
      }
      const extras=s?.exerciseExtras?.days?.[sk]||{};
      const defs=s?.exerciseLayout?.days?.[d]?.custom||[];
      Object.keys(extras).forEach(id=>{
        const def=defs.find(v=>v.id===id);
        // Stable custom IDs are accepted only while the movement name is intact.
        const selected=def?.name||(info.custom&&id===info.id?info.selected:'');
        if(!selected)return;
        if(!sameMovement(selected,info.selected)&&!variantFor(selected,info.selected))return;
        consider(selected,customSetsAt(s,w,m[2],id),sk,ord,'Health Coach custom');
      });
    });
    found.sort((a,b)=>Number(b.match==='exact')-Number(a.match==='exact')||b.ordinal-a.ordinal);
    return found[0]||null;
  }

  function growthFromRir(rir){
    if(rir===null||!Number.isFinite(rir))return TARGET;
    if(rir>=3)return TARGET;
    if(rir>=2)return 0.08;
    if(rir>=1)return 0.05;
    return 0.025;
  }
  function suggestionFor(set,range){
    const {w,r,rir}=set,g=growthFromRir(rir);let tw=w,tr=r,mode='reps';
    if(r<range.hi){
      const repGoal=Math.max(r+1,Math.ceil(r*(1+g)));tr=Math.min(range.hi,repGoal);
      if(w>0&&rir!==null&&rir>=3&&tr<=r+1){tw=roundLoad(w*(1+Math.min(TARGET,g+.02)));tr=Math.max(range.lo,Math.min(range.hi,r));mode='load'}
    }else if(w>0){
      const loadPct=rir!==null&&rir<1?0.025:rir!==null&&rir<2?0.05:0.075;
      tw=roundLoad(w*(1+loadPct));tr=Math.max(range.lo,Math.min(range.hi,range.hi>range.lo?range.hi-1:range.lo));mode='load';
    }
    if(tw===w&&tr===r&&r<range.hi)tr=Math.min(range.hi,r+1);
    return {w:tw,r:tr,rir,mode,growth:g};
  }
  function fmtSet(x,showRir=true){return `${x.w||0}×${x.r||'?'}${showRir&&x.rir!==null&&Number.isFinite(x.rir)?` @${x.rir} RIR`:''}`}
  function reason(history,sugs){
    const rirs=history.sets.map(x=>x.rir).filter(x=>x!==null&&Number.isFinite(x)),avg=rirs.length?rirs.reduce((a,b)=>a+b,0)/rirs.length:null,hasLoad=sugs.some(x=>x.mode==='load');
    if(avg!==null&&avg<1)return 'Last exposure was near failure, so aggressive mode caps the jump. Beat it cleanly before forcing a larger increase.';
    if(avg!==null&&avg>=3)return hasLoad?'You had plenty in reserve, so the coach is favoring a load jump.':'You had plenty in reserve, so the coach is pushing the rep target hard.';
    return hasLoad?'You reached the top of the range on at least one set, so load goes up and reps reset slightly.':'You still have room in the rep range, so the fastest progression is more reps at the same load.';
  }
  function currentRows(box){return [...box.querySelectorAll(':scope > .setrow:not(.head):not(.hc-set-hidden)')].filter(r=>r.style.display!=='none')}
  function manualKey(box,index,field){return `${week()}|${rawDay()}|${exerciseInfo(box).id}|${index}|${field}`}
  function applyTargets(box,sugs){
    let changed=false;const rows=currentRows(box);
    rows.forEach((row,i)=>{
      const s=sugs[Math.min(i,sugs.length-1)];if(!s)return;
      const inputs=[...row.querySelectorAll('input')];if(inputs.length<2)return;
      for(const [field,target,input] of [['w',s.w,inputs[0]],['r',s.r,inputs[1]]]){
        if(target===null||target===undefined||!Number.isFinite(Number(target)))continue;
        if(MANUAL_CLEARED.has(manualKey(box,i,field)))continue;
        if(String(input.value).trim()!=='')continue;
        input.value=target;
        input.dispatchEvent(new Event('input',{bubbles:true}));
        input.dispatchEvent(new Event('change',{bubbles:true}));
        changed=true;
      }
    });
    return changed;
  }
  function variationTargets(hist,range){
    const factor=hist.variation?.factor||1;
    return hist.sets.map(x=>{
      // No "aggressive" increase for a new grip; use a deliberately lighter starting load.
      const weight=x.w>0?Math.max(1,x.w<30?Math.floor(x.w*factor):Math.floor(x.w*factor/5)*5):0;
      return {w:weight,r:Math.max(range.lo,Math.min(range.hi,x.r)),rir:x.rir,mode:'variation'};
    });
  }
  function repOnly(box,range){
    const reps=range.lo>1&&range.hi<99?range.lo:null;
    if(reps===null)return;
    applyTargets(box,[{w:null,r:reps}]);
  }

  function addStyles(){
    if(document.getElementById('hcProgressionStyles'))return;
    const st=document.createElement('style');st.id='hcProgressionStyles';st.textContent=`
      .hc-progression-card{margin:8px 0 4px;padding:9px 10px;border:1px solid #355d86;border-radius:10px;background:#132338}
      .hc-progression-head{display:flex;gap:8px;align-items:center;justify-content:space-between}.hc-progression-badge{font-size:10px;font-weight:800;letter-spacing:.04em;color:#b8d3ff;text-transform:uppercase}
      .hc-progression-last,.hc-progression-target{font-size:12px;line-height:1.45;margin-top:4px}.hc-progression-target{color:var(--accent2);font-weight:700}.hc-progression-reason{font-size:11px;color:var(--muted);line-height:1.4;margin-top:4px}
      .hc-apply-target{border:1px solid #4d78b3;background:#1d3352;color:var(--text);border-radius:8px;min-height:32px;padding:0 9px;font-size:11px;white-space:nowrap}
      .exercise.hc-ex-collapsed>.hc-progression-card{display:none!important}
    `;document.head.appendChild(st);
  }

  function renderBox(box,s){
    if(box.style.display==='none')return;
    box.querySelector(':scope > .hc-progression-card')?.remove();
    const info=exerciseInfo(box);if(!info.id)return;
    const hist=latestHistory(s,info),card=document.createElement('div');card.className='hc-progression-card';
    const range=parseRange(box);
    if(!hist){
      card.innerHTML=`<div class="hc-progression-head"><span class="hc-progression-badge">Progression · baseline needed</span></div><div class="hc-progression-reason">No earlier comparable weight-and-rep sets for ${esc(info.selected)} are saved in Health Coach. Prior exercises with different equipment will not be assigned an invented weight. Rep targets can be prefilled, but set your first working weight to establish a baseline.</div>`;
      setTimeout(()=>repOnly(box,range),70);
    }else if(hist.match==='variation'&&!hist.variation?.transfer){
      const prior=hist.sets.map(x=>fmtSet(x,true)).join(' · ');
      card.innerHTML=`<div class="hc-progression-head"><span class="hc-progression-badge">Related history · equipment changed</span></div><div class="hc-progression-last">Previously logged ${esc(hist.selected)} (${esc(hist.sessionKey)}): ${esc(prior)}</div><div class="hc-progression-reason">This is a ${esc(hist.variation.label)}. The previous exercise counts as experience, but the weight is not directly transferable; choose a comfortable first working load. Rep targets are suggested.</div>`;
      setTimeout(()=>repOnly(box,range),70);
    }else{
      const changedGrip=hist.match==='variation';
      const sugs=changedGrip?variationTargets(hist,range):hist.sets.map(x=>suggestionFor(x,range));
      const prior=hist.sets.map(x=>fmtSet(x,true)).join(' · '),target=sugs.map(x=>fmtSet(x,false)).join(' · ');
      card.innerHTML=`<div class="hc-progression-head"><span class="hc-progression-badge">${changedGrip?'Grip variation · starter estimate':'Aggressive target · auto-filled'}</span><button type="button" class="hc-apply-target">Reapply to empty sets</button></div><div class="hc-progression-last">Last logged ${esc(hist.selected)} (${esc(hist.sessionKey)}): ${esc(prior)}</div><div class="hc-progression-target">Suggested: ${esc(target)}</div><div class="hc-progression-reason">${changedGrip?'Grip changed. A conservative starting weight is suggested; check the load before lifting.':esc(reason(hist,sugs))} Blank weight/reps will be filled automatically; previously entered sets will not be overwritten.</div>`;
      card.querySelector('.hc-apply-target')?.addEventListener('click',()=>applyTargets(box,sugs));
      setTimeout(()=>applyTargets(box,sugs),70);
    }
    box.querySelector(':scope > .exhead')?.after(card);
  }

  function apply(){addStyles();const s=state();if(!s)return;document.querySelectorAll('#exercises > .exercise').forEach(box=>renderBox(box,s))}
  function schedule(delay=100){clearTimeout(timer);timer=setTimeout(apply,delay)}
  function start(){
    addStyles();schedule(350);
    const holder=document.getElementById('exercises');if(holder)new MutationObserver(()=>schedule(140)).observe(holder,{childList:true});
    document.addEventListener('input',e=>{
      if(!e.isTrusted||!e.target?.matches?.('#exercises .setrow:not(.head) input'))return;
      const row=e.target.closest('.setrow'),box=e.target.closest('.exercise');if(!row||!box)return;
      const rows=currentRows(box),i=rows.indexOf(row),inputs=[...row.querySelectorAll('input')],field=inputs[0]===e.target?'w':inputs[1]===e.target?'r':null;
      if(i<0||!field)return;
      const key=manualKey(box,i,field);
      if(String(e.target.value).trim()==='')MANUAL_CLEARED.add(key);else MANUAL_CLEARED.delete(key);
    },true);
    document.addEventListener('hc:set-editor-change',()=>schedule(130));
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day'||e.target?.classList?.contains('choice'))schedule(180)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.weekBtn,.tab,#hcEditExercises,.hc-set-btn'))schedule(220)},true);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
