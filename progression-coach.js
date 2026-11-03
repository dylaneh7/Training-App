(()=>{
  if(window.__hybridCoachProgressionV2)return;
  window.__hybridCoachProgressionV2=true;

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
  const AUTO_APPLIED=new Set();
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
    ['Seated Row','Seated Cable Row'],
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

  function latestBuiltHistory(s,info){
    const candidates=[];
    Object.keys(s?.days||{}).forEach(sk=>{
      const m=sk.match(/^(\d+)-(Mon|Tue|Wed|Thu)$/);if(!m)return;
      const w=Number(m[1]),d=m[2],ord=w*7+(DAY_INDEX[d]??0);if(ord>=currentOrdinal())return;
      const x=s.days[sk],order=DAY_ORDER[d]||[];
      order.forEach((id,idx)=>{
        const selected=historicalSelection(x,d,idx);if(!sameMovement(selected,info.selected))return;
        const sets=nativeSetsAt(s,w,d,idx,id);if(sets.length)candidates.push({week:w,day:d,ordinal:ord,sets,selected,sessionKey:sk});
      });
    });
    candidates.sort((a,b)=>b.ordinal-a.ordinal);
    return candidates[0]||null;
  }
  function latestCustomHistory(s,info){
    const candidates=[];
    Object.keys(s?.exerciseExtras?.days||{}).forEach(sk=>{
      const m=sk.match(/^(\d+)-(Mon|Tue|Wed|Thu)$/);if(!m)return;
      const w=Number(m[1]),d=m[2],ord=w*7+(DAY_INDEX[d]??0);if(ord>=currentOrdinal())return;
      const log=s.exerciseExtras.days[sk]?.[info.id];if(!log)return;
      const sets=customSetsAt(s,w,d,info.id);if(sets.length)candidates.push({week:w,day:d,ordinal:ord,sets,selected:info.selected,sessionKey:sk});
    });
    candidates.sort((a,b)=>b.ordinal-a.ordinal);
    return candidates[0]||null;
  }
  function latestHistory(s,info){return info.custom?latestCustomHistory(s,info):latestBuiltHistory(s,info)}

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
  function applyTargets(box,sugs){
    let changed=false;const rows=currentRows(box);
    rows.forEach((row,i)=>{
      const s=sugs[Math.min(i,sugs.length-1)];if(!s)return;
      const inputs=[...row.querySelectorAll('input')];if(inputs.length<2)return;
      if(String(inputs[0].value).trim()===''){inputs[0].value=s.w;inputs[0].dispatchEvent(new Event('input',{bubbles:true}));inputs[0].dispatchEvent(new Event('change',{bubbles:true}));changed=true}
      if(String(inputs[1].value).trim()===''){inputs[1].value=s.r;inputs[1].dispatchEvent(new Event('input',{bubbles:true}));inputs[1].dispatchEvent(new Event('change',{bubbles:true}));changed=true}
    });
    return changed;
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
    if(!hist){
      card.innerHTML=`<div class="hc-progression-head"><span class="hc-progression-badge">Aggressive progression · up to +10%</span></div><div class="hc-progression-reason">No earlier matching logged exposure for ${esc(info.selected)} yet. The coach now searches movement aliases and prior training days, so unrelated exercises are not used as a weight baseline.</div>`;
    }else{
      const range=parseRange(box),sugs=hist.sets.map(x=>suggestionFor(x,range));
      const prior=hist.sets.map(x=>fmtSet(x,true)).join(' · '),target=sugs.map(x=>fmtSet(x,false)).join(' · ');
      card.innerHTML=`<div class="hc-progression-head"><span class="hc-progression-badge">Aggressive target · auto-filled</span><button type="button" class="hc-apply-target">Reapply to empty sets</button></div><div class="hc-progression-last">Last logged (${esc(hist.sessionKey)}): ${esc(prior)}</div><div class="hc-progression-target">Suggested: ${esc(target)}</div><div class="hc-progression-reason">${esc(reason(hist,sugs))} Blank weight/reps are filled automatically; anything you already entered is left alone.</div>`;
      card.querySelector('.hc-apply-target')?.addEventListener('click',()=>applyTargets(box,sugs));
      const autoKey=`${week()}-${rawDay()}|${info.key}|${hist.sessionKey}|${target}`;
      if(!AUTO_APPLIED.has(autoKey)){
        AUTO_APPLIED.add(autoKey);
        setTimeout(()=>applyTargets(box,sugs),20);
      }
    }
    box.querySelector(':scope > .exhead')?.after(card);
  }

  function apply(){addStyles();const s=state();if(!s)return;document.querySelectorAll('#exercises > .exercise').forEach(box=>renderBox(box,s))}
  function schedule(delay=100){clearTimeout(timer);timer=setTimeout(apply,delay)}
  function start(){
    addStyles();schedule(350);
    const holder=document.getElementById('exercises');if(holder)new MutationObserver(()=>schedule(140)).observe(holder,{childList:true});
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day'||e.target?.classList?.contains('choice'))schedule(180)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.weekBtn,.tab,#hcEditExercises,.hc-set-btn'))schedule(220)},true);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
