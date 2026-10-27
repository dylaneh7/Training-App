(()=>{
  if(window.__hybridCoachProgression)return;
  window.__hybridCoachProgression=true;

  const TRAINING_KEY='hybridCoachData_v1';
  const TARGET=0.10;
  const DAY_ORDER={
    Mon:['Flat barbell bench press','Incline dumbbell press','Weighted dip — chest bias','Seated dumbbell shoulder press','Chest-supported lateral raise','Standing lateral raise','Single-arm cable rear-delt fly','Close-grip bench press','Overhead cable triceps extension','Rope pressdown','Push-up plus'],
    Tue:['Weighted pull-up / neutral pulldown','Chest-supported T-bar row','Single-arm cable lat row — elbow to hip','Wide high row','Straight-arm cable pulldown','Dumbbell shrug','Cable Y-raise','Reverse pec deck','Face pull with external rotation','Incline dumbbell curl','Preacher curl','Hammer curl','Reverse EZ-bar curl','Farmer carry'],
    Wed:['Paused bench press','Low-to-high cable fly','Neutral-grip pulldown','Chest-supported machine row','Cable lateral raise','Cable rear-delt fly','Rope pressdown','Cable curl','Cable external rotation'],
    Thu:['Back squat / hack squat','Romanian deadlift','Leg press','Bulgarian split squat','Leg extension','Seated leg curl','Hip thrust','Standing calf raise','Seated soleus raise','Cable crunch / ab wheel']
  };
  let timer=null;

  function state(){try{const raw=localStorage.getItem(TRAINING_KEY);return raw?JSON.parse(raw):null}catch{return null}}
  function week(){return Number(document.getElementById('week')?.value||0)}
  function day(){return document.getElementById('day')?.value||'Mon'}
  function esc(v){return String(v??'').replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]))}
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
    const id=box.dataset.hcId||box.querySelector('.choice')?.options?.[0]?.value||box.querySelector('.hc-custom-name')?.textContent||'';
    const selected=box.querySelector('.choice')?.value||box.querySelector('.hc-custom-name')?.textContent||id;
    const custom=id.startsWith('custom-')||box.classList.contains('hc-custom-exercise');
    const idx=custom?-1:(DAY_ORDER[day()]||[]).indexOf(id);
    return {id,selected,custom,idx};
  }
  function priorSetEditorExtra(s,sk,id,count){
    const e=s?.setEditor?.sessions?.[sk]?.[id];
    if(!e?.extra)return [];
    const out=[];
    for(let n=1;n<=count;n++){
      const v=e.extra[n];
      if(v&&(v.w!==''||v.r!==''||v.rir!==''))out.push({w:Number(v.w)||0,r:Number(v.r)||0,rir:v.rir===''?null:Number(v.rir)});
    }
    return out;
  }
  function builtSets(s,w,d,info){
    if(info.idx<0)return [];
    const sk=`${w}-${d}`,x=s?.days?.[sk];if(!x)return [];
    const canonical=DAY_ORDER[d]?.[info.idx]||info.id;
    const priorSelected=x.choice?.[info.idx]||canonical;
    if(priorSelected!==info.selected)return [];
    const setCfg=s?.setEditor?.sessions?.[sk]?.[info.id];
    const count=Math.max(1,Number(setCfg?.count)||99);
    const vals=[];
    Object.entries(x.sets||{}).forEach(([k,v])=>{
      const m=k.match(/^(\d+)-(\d+)$/);if(!m||Number(m[1])!==info.idx||Number(m[2])>count)return;
      if(v&&(v.w!==''||v.r!==''||v.rir!==''))vals.push({n:Number(m[2]),w:Number(v.w)||0,r:Number(v.r)||0,rir:v.rir===''?null:Number(v.rir)});
    });
    vals.sort((a,b)=>a.n-b.n);
    return vals.map(({w,r,rir})=>({w,r,rir})).concat(priorSetEditorExtra(s,sk,info.id,count));
  }
  function customSets(s,w,d,info){
    const sk=`${w}-${d}`;
    const log=s?.exerciseExtras?.days?.[sk]?.[info.id];
    if(!log?.sets)return [];
    const setCfg=s?.setEditor?.sessions?.[sk]?.[info.id];
    const count=Math.max(1,Number(setCfg?.count)||99);
    const vals=[];
    Object.entries(log.sets).forEach(([n,v])=>{
      if(Number(n)>count)return;
      if(v&&(v.w!==''||v.r!==''||v.rir!==''))vals.push({n:Number(n),w:Number(v.w)||0,r:Number(v.r)||0,rir:v.rir===''?null:Number(v.rir)});
    });
    vals.sort((a,b)=>a.n-b.n);
    return vals.map(({w,r,rir})=>({w,r,rir})).concat(priorSetEditorExtra(s,sk,info.id,count));
  }
  function latestHistory(s,info){
    for(let w=week()-1;w>=0;w--){
      const sets=info.custom?customSets(s,w,day(),info):builtSets(s,w,day(),info);
      const usable=sets.filter(x=>x.w>0&&x.r>0);
      if(usable.length)return {week:w,sets:usable};
    }
    return null;
  }
  function growthFromRir(rir){
    if(rir===null||!Number.isFinite(rir))return TARGET;
    if(rir>=3)return TARGET;
    if(rir>=2)return 0.08;
    if(rir>=1)return 0.05;
    return 0.025;
  }
  function suggestionFor(set,range){
    const {w,r,rir}=set, g=growthFromRir(rir);
    let tw=w,tr=r,mode='reps';
    if(r<range.hi){
      const repGoal=Math.max(r+1,Math.ceil(r*(1+g)));
      tr=Math.min(range.hi,repGoal);
      if(rir!==null&&rir>=3&&tr<=r+1){
        tw=roundLoad(w*(1+Math.min(TARGET,g+.02)));tr=Math.max(range.lo,Math.min(range.hi,r));mode='load';
      }
    }else{
      const loadPct=rir!==null&&rir<1?0.025:rir!==null&&rir<2?0.05:0.075;
      tw=roundLoad(w*(1+loadPct));
      tr=Math.max(range.lo,Math.min(range.hi,range.hi>range.lo?range.hi-1:range.lo));
      mode='load';
    }
    if(tw===w&&tr===r&&r<range.hi)tr=Math.min(range.hi,r+1);
    const loadPct=w?((tw/w)-1)*100:0,repPct=r?((tr/r)-1)*100:0;
    return {w:tw,r:tr,rir,mode,growth:g,loadPct,repPct};
  }
  function fmtSet(x,showRir=true){return `${x.w||'?'}×${x.r||'?'}${showRir&&x.rir!==null&&Number.isFinite(x.rir)?` @${x.rir} RIR`:''}`}
  function reason(history,sugs){
    const rirs=history.sets.map(x=>x.rir).filter(x=>x!==null&&Number.isFinite(x));
    const avg=rirs.length?rirs.reduce((a,b)=>a+b,0)/rirs.length:null;
    const hasLoad=sugs.some(x=>x.mode==='load');
    if(avg!==null&&avg<1)return 'Last exposure was near failure, so aggressive mode caps the jump. Beat it cleanly before forcing a larger increase.';
    if(avg!==null&&avg>=3)return hasLoad?'You had plenty in reserve, so the coach is favoring a load jump.':'You had plenty in reserve, so the coach is pushing the rep target hard.';
    return hasLoad?'You reached the top of the range on at least one set, so load goes up and reps reset slightly.':'You still have room in the rep range, so the fastest progression is more reps at the same load.';
  }
  function currentRows(box){return [...box.querySelectorAll(':scope > .setrow:not(.head):not(.hc-set-hidden)')].filter(r=>r.style.display!=='none')}
  function applyTargets(box,sugs){
    const rows=currentRows(box);
    rows.forEach((row,i)=>{
      const s=sugs[Math.min(i,sugs.length-1)];if(!s)return;
      const inputs=[...row.querySelectorAll('input')];if(inputs.length<2)return;
      if(String(inputs[0].value).trim()===''){inputs[0].value=s.w;inputs[0].dispatchEvent(new Event('input',{bubbles:true}));inputs[0].dispatchEvent(new Event('change',{bubbles:true}))}
      if(String(inputs[1].value).trim()===''){inputs[1].value=s.r;inputs[1].dispatchEvent(new Event('input',{bubbles:true}));inputs[1].dispatchEvent(new Event('change',{bubbles:true}))}
    });
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
      card.innerHTML=`<div class="hc-progression-head"><span class="hc-progression-badge">Aggressive progression · up to +10%</span></div><div class="hc-progression-reason">No earlier logged exposure for ${esc(info.selected)} yet. Log this workout and it becomes the baseline for your next exposure.</div>`;
    }else{
      const range=parseRange(box),sugs=hist.sets.map(x=>suggestionFor(x,range));
      const prior=hist.sets.map(x=>fmtSet(x,true)).join(' · '),target=sugs.map(x=>fmtSet(x,false)).join(' · ');
      card.innerHTML=`<div class="hc-progression-head"><span class="hc-progression-badge">Aggressive target · up to +10%</span><button type="button" class="hc-apply-target">Apply target to empty sets</button></div><div class="hc-progression-last">Last logged: ${esc(prior)}</div><div class="hc-progression-target">Suggested: ${esc(target)}</div><div class="hc-progression-reason">${esc(reason(hist,sugs))} Your actual entries always become the next baseline.</div>`;
      card.querySelector('.hc-apply-target')?.addEventListener('click',()=>applyTargets(box,sugs));
    }
    const head=box.querySelector(':scope > .exhead');head?.after(card);
  }
  function apply(){
    addStyles();const s=state();if(!s)return;
    document.querySelectorAll('#exercises > .exercise').forEach(box=>renderBox(box,s));
  }
  function schedule(delay=100){clearTimeout(timer);timer=setTimeout(apply,delay)}
  function start(){
    addStyles();schedule(350);
    const holder=document.getElementById('exercises');if(holder)new MutationObserver(()=>schedule(140)).observe(holder,{childList:true});
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day'||e.target?.classList?.contains('choice'))schedule(180)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.weekBtn,.tab,#hcEditExercises,.hc-set-btn'))schedule(220)},true);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
