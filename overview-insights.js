(()=>{
  if(window.__hybridCoachOverviewInsights)return;
  window.__hybridCoachOverviewInsights=true;

  const STORAGE_KEY='hybridCoachData_v1';
  const DAY_ORDER=['Mon','Tue','Wed','Thu'];
  const STANDARD_SCHEDULE=[
    {key:'Mon',label:'Monday',title:'Push'},
    {key:'Tue',label:'Tuesday',title:'Pull'},
    {key:'Wed',label:'Wednesday',title:'Upper Support'},
    {key:'Thu',label:'Thursday',title:'Legs'}
  ];
  const WEEK44_SCHEDULE=[
    {key:'Mon',value:'Mon',label:'Monday',title:'Push'},
    {key:'Tue',value:'Tue',label:'Tuesday',title:'Pull'},
    {key:'Wed',value:'UpperThu',label:'Thursday',title:'Upper Support'},
    {key:'Thu',value:'LegsFri',label:'Friday',title:'Legs'}
  ];

  function esc(v){
    return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }

  function readState(){
    try{return JSON.parse(localStorage.getItem(STORAGE_KEY)||'{}')||{}}
    catch{return {}}
  }

  function selectedWeek(){
    const n=Number(document.getElementById('week')?.value||0);
    return Number.isFinite(n)?n:0;
  }

  function weekLabel(i){
    const opt=document.querySelector(`#week option[value="${i}"]`);
    if(!opt)return `Week ${i+1}`;
    const parts=(opt.textContent||'').split('·').map(x=>x.trim());
    return parts.slice(0,2).join(' · ')||`Week ${i+1}`;
  }

  function scheduleFor(wi){return wi===0?WEEK44_SCHEDULE:STANDARD_SCHEDULE}

  function getDay(state,wi,d){return state.days?.[`${wi}-${d}`]||null}

  function loggedSetValues(x){
    if(!x?.sets)return [];
    return Object.values(x.sets).filter(v=>v&&(Number(v.r)>0||Number(v.w)>0));
  }

  function summarizeWeek(state,wi){
    const out={miles:0,runs:0,lifts:0,sets:0,volume:0,rpe:[],days:0};
    DAY_ORDER.forEach(d=>{
      const x=getDay(state,wi,d);if(!x)return;
      out.days++;
      if(x.runDone)out.runs++;
      if(x.liftDone)out.lifts++;
      out.miles+=Number(x.run?.miles)||0;
      if(Number(x.run?.rpe)>0)out.rpe.push(Number(x.run.rpe));
      loggedSetValues(x).forEach(v=>{
        out.sets++;
        out.volume+=(Number(v.w)||0)*(Number(v.r)||0);
      });
    });
    out.avgRpe=out.rpe.length?out.rpe.reduce((a,b)=>a+b,0)/out.rpe.length:null;
    return out;
  }

  function currentStreak(state,type,wi){
    const slots=[];
    for(let w=0;w<=wi;w++){
      DAY_ORDER.forEach(d=>slots.push(getDay(state,w,d)?.[type]===true));
    }
    let last=-1;
    for(let i=slots.length-1;i>=0;i--){if(slots[i]){last=i;break}}
    if(last<0)return 0;
    let streak=0;
    for(let i=last;i>=0;i--){
      if(slots[i])streak++;
      else break;
    }
    return streak;
  }

  function consistencyWeeks(state,wi){
    let count=0;
    for(let w=0;w<=wi;w++){
      const s=summarizeWeek(state,w);
      if(s.lifts>=3)count++;
    }
    return count;
  }

  function nextWorkout(state,wi){
    const schedule=scheduleFor(wi);
    for(const item of schedule){
      if(!getDay(state,wi,item.key)?.liftDone)return item;
    }
    return null;
  }

  function pct(n,max){return max?Math.max(5,Math.round(n/max*100)):0}
  function formatVolume(v){
    if(v>=1000000)return `${(v/1000000).toFixed(2)}M lb`;
    if(v>=1000)return `${(v/1000).toFixed(v>=10000?0:1)}k lb`;
    return `${Math.round(v)} lb`;
  }

  function injectStyles(){
    if(document.getElementById('hcOverviewStyles'))return;
    const s=document.createElement('style');s.id='hcOverviewStyles';
    s.textContent=`
      .hc-overview-hero{display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:12px}
      .hc-overview-hero h2{margin:0 0 4px;font-size:22px}
      .hc-overview-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:10px 0 14px}
      .hc-overview-metric{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:12px}
      .hc-overview-metric .k{font-size:11px;color:var(--muted)}
      .hc-overview-metric .v{font-size:21px;font-weight:800;margin-top:3px}
      .hc-overview-section{background:var(--card);border:1px solid var(--border);border-radius:16px;margin-bottom:10px;overflow:hidden}
      .hc-overview-section>summary{list-style:none;cursor:pointer;padding:14px;font-weight:800;display:flex;justify-content:space-between;gap:12px;align-items:center}
      .hc-overview-section>summary::-webkit-details-marker{display:none}
      .hc-overview-section>summary:after{content:'›';font-size:22px;color:var(--muted);transform:rotate(90deg)}
      .hc-overview-section:not([open])>summary:after{transform:rotate(0)}
      .hc-overview-body{padding:0 14px 14px}
      .hc-overview-next{display:flex;justify-content:space-between;gap:12px;align-items:center;border:1px solid var(--border);background:var(--panel);border-radius:12px;padding:12px}
      .hc-overview-next strong{font-size:17px}
      .hc-overview-bars{display:grid;gap:9px}
      .hc-trend-row{display:grid;grid-template-columns:100px 1fr 92px;gap:8px;align-items:center;font-size:12px}
      .hc-bar{height:9px;border-radius:999px;background:var(--panel);border:1px solid var(--border);overflow:hidden}
      .hc-bar>span{display:block;height:100%;background:var(--accent);border-radius:999px}
      .hc-streak-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
      .hc-mini{border:1px solid var(--border);background:var(--panel);border-radius:12px;padding:11px}
      .hc-mini strong{display:block;font-size:20px;margin-top:3px}
      .hc-overview-note{font-size:11px;color:var(--muted);line-height:1.45;margin-top:8px}
      @media(max-width:720px){
        .hc-overview-grid{grid-template-columns:1fr 1fr}
        .hc-streak-grid{grid-template-columns:1fr}
        .hc-trend-row{grid-template-columns:82px 1fr 76px}
        .hc-overview-next{align-items:flex-start;flex-direction:column}
      }
    `;
    document.head.appendChild(s);
  }

  function ensureUi(){
    injectStyles();
    const tabs=document.querySelector('.tabs');
    if(!tabs)return null;
    let tab=document.querySelector('.tab[data-tab="overview"]');
    if(!tab){
      tab=document.createElement('button');
      tab.className='tab';tab.dataset.tab='overview';tab.textContent='Overview';
      tabs.insertBefore(tab,tabs.firstChild);
      tab.addEventListener('click',()=>{
        document.querySelectorAll('[data-panel]').forEach(p=>p.classList.toggle('hidden',p.dataset.panel!=='overview'));
        document.querySelectorAll('.tab').forEach(b=>b.classList.toggle('active',b===tab));
        render();
      });
    }

    let panel=document.querySelector('[data-panel="overview"]');
    if(!panel){
      panel=document.createElement('section');
      panel.dataset.panel='overview';panel.className='hidden';
      const workout=document.querySelector('[data-panel="workout"]');
      workout?.parentNode?.insertBefore(panel,workout);
    }
    return panel;
  }

  function render(){
    const panel=ensureUi();if(!panel)return;
    const state=readState(),wi=selectedWeek(),summary=summarizeWeek(state,wi),next=nextWorkout(state,wi);
    const liftStreak=currentStreak(state,'liftDone',wi),runStreak=currentStreak(state,'runDone',wi),solidWeeks=consistencyWeeks(state,wi);
    const weeks=[];
    for(let w=Math.max(0,wi-3);w<=wi;w++)weeks.push({i:w,...summarizeWeek(state,w)});
    const maxSets=Math.max(1,...weeks.map(w=>w.sets));
    const maxMiles=Math.max(1,...weeks.map(w=>w.miles));
    const prev=weeks.length>1?weeks[weeks.length-2]:null;
    const setsDelta=prev?summary.sets-prev.sets:null;
    const milesDelta=prev?summary.miles-prev.miles:null;

    panel.innerHTML=`
      <div class="hc-overview-hero">
        <div><h2>Training Overview</h2><div class="tiny">${esc(weekLabel(wi))} · your high-level training hub</div></div>
        <button class="btn" id="hcOverviewRefresh" type="button">Refresh</button>
      </div>

      <div class="hc-overview-grid">
        <div class="hc-overview-metric"><div class="k">Lifts complete</div><div class="v">${summary.lifts}/4</div></div>
        <div class="hc-overview-metric"><div class="k">Runs complete</div><div class="v">${summary.runs}/4</div></div>
        <div class="hc-overview-metric"><div class="k">Logged work sets</div><div class="v">${summary.sets}</div></div>
        <div class="hc-overview-metric"><div class="k">Week miles</div><div class="v">${summary.miles.toFixed(1)}</div></div>
      </div>

      <details class="hc-overview-section" open>
        <summary>This Week <span class="tiny">workload</span></summary>
        <div class="hc-overview-body">
          <div class="hc-streak-grid">
            <div class="hc-mini"><span class="tiny">Strength volume</span><strong>${formatVolume(summary.volume)}</strong><span class="tiny">weight × reps from logged sets</span></div>
            <div class="hc-mini"><span class="tiny">Set change vs prior week</span><strong>${setsDelta===null?'—':`${setsDelta>=0?'+':''}${setsDelta}`}</strong><span class="tiny">logged work sets</span></div>
            <div class="hc-mini"><span class="tiny">Mileage change</span><strong>${milesDelta===null?'—':`${milesDelta>=0?'+':''}${milesDelta.toFixed(1)} mi`}</strong><span class="tiny">vs prior selected week</span></div>
          </div>
          ${summary.avgRpe!==null?`<div class="hc-overview-note">Average logged run RPE this week: <strong>${summary.avgRpe.toFixed(1)}</strong>.</div>`:''}
        </div>
      </details>

      <details class="hc-overview-section" open>
        <summary>Next Workout <span class="tiny">what's next</span></summary>
        <div class="hc-overview-body">
          ${next?`
            <div class="hc-overview-next">
              <div><span class="tiny">${esc(next.label)}</span><strong>${esc(next.title)}</strong><div class="tiny" style="margin-top:4px">First unfinished strength session in this training week.</div></div>
              <button class="btn primary" id="hcOpenNextWorkout" type="button">Open workout</button>
            </div>`:
            `<div class="hc-overview-next"><div><strong>Strength week complete ✓</strong><div class="tiny" style="margin-top:4px">All four strength sessions are checked off.</div></div></div>`}
        </div>
      </details>

      <details class="hc-overview-section" open>
        <summary>Streaks & Consistency <span class="tiny">momentum</span></summary>
        <div class="hc-overview-body">
          <div class="hc-streak-grid">
            <div class="hc-mini"><span class="tiny">Strength streak</span><strong>${liftStreak}</strong><span class="tiny">completed planned lift sessions in a row</span></div>
            <div class="hc-mini"><span class="tiny">Run streak</span><strong>${runStreak}</strong><span class="tiny">completed planned run sessions in a row</span></div>
            <div class="hc-mini"><span class="tiny">Consistent weeks</span><strong>${solidWeeks}</strong><span class="tiny">weeks with at least 3 completed lifts</span></div>
          </div>
        </div>
      </details>

      <details class="hc-overview-section" open>
        <summary>Performance Trend <span class="tiny">last ${weeks.length} weeks</span></summary>
        <div class="hc-overview-body">
          <div class="tiny" style="margin-bottom:8px">Logged work sets</div>
          <div class="hc-overview-bars">
            ${weeks.map(w=>`<div class="hc-trend-row"><span>${esc(weekLabel(w.i).replace('Week ','W'))}</span><div class="hc-bar"><span style="width:${pct(w.sets,maxSets)}%"></span></div><strong>${w.sets} sets</strong></div>`).join('')}
          </div>
          <div class="tiny" style="margin:14px 0 8px">Running mileage</div>
          <div class="hc-overview-bars">
            ${weeks.map(w=>`<div class="hc-trend-row"><span>${esc(weekLabel(w.i).replace('Week ','W'))}</span><div class="hc-bar"><span style="width:${pct(w.miles,maxMiles)}%"></span></div><strong>${w.miles.toFixed(1)} mi</strong></div>`).join('')}
          </div>
          <div class="hc-overview-note">Trends use what you have actually logged in Health Coach; blank sessions are not treated as completed training.</div>
        </div>
      </details>
    `;

    panel.querySelector('#hcOverviewRefresh')?.addEventListener('click',render);
    panel.querySelector('#hcOpenNextWorkout')?.addEventListener('click',()=>{
      const week=document.getElementById('week'),day=document.getElementById('day');
      if(!week||!day||!next)return;
      week.value=String(wi);
      week.dispatchEvent(new Event('change',{bubbles:true}));
      setTimeout(()=>{
        const desired=next.value||next.key;
        if([...day.options].some(o=>o.value===desired))day.value=desired;
        else if([...day.options].some(o=>o.value===next.key))day.value=next.key;
        day.dispatchEvent(new Event('change',{bubbles:true}));
        document.querySelector('.tab[data-tab="workout"]')?.click();
      },40);
    });
  }

  const nativeSetItem=Storage.prototype.setItem;
  if(!window.__hybridCoachOverviewStorageBridge){
    window.__hybridCoachOverviewStorageBridge=true;
    Storage.prototype.setItem=function(k,v){
      const out=nativeSetItem.call(this,k,v);
      if(this===localStorage&&k===STORAGE_KEY)setTimeout(()=>{
        if(!document.querySelector('[data-panel="overview"]')?.classList.contains('hidden'))render();
      },30);
      return out;
    };
  }

  function start(){
    ensureUi();
    const week=document.getElementById('week');
    week?.addEventListener('change',()=>setTimeout(()=>{
      if(!document.querySelector('[data-panel="overview"]')?.classList.contains('hidden'))render();
    },30),true);
    render();
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
  else start();
})();
