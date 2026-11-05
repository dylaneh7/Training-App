(()=>{
  if(window.__hybridCoachTodayMode)return;
  window.__hybridCoachTodayMode=true;

  const BASE_DATE='2026-10-26';
  const STORAGE_KEY='hybridCoachData_v1';
  const AUTH_STORAGE_KEY='hybrid-coach-command-center-auth';
  const SUPABASE_URL='https://ecmosmmqloyahsdcxvpz.supabase.co';
  const SUPABASE_KEY='sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ';
  const DAY_OFFSETS={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6,RestWed:2,UpperThu:3,LegsFri:4};
  const WEEKDAY_KEYS=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
  const WORKOUT_DAYS=['Mon','Tue','Wed','Thu'];
  let autoClient=null;
  let coreDayChange=null;
  let lastCalendarDate='';
  let runSyncTimer=null;
  let sdkRetries=0;

  const localNoon=iso=>new Date(`${iso}T12:00:00`);
  const addDays=(date,n)=>{const d=new Date(date);d.setDate(d.getDate()+n);return d};
  const isoDate=date=>`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
  const formatDate=date=>date.toLocaleDateString(undefined,{weekday:'long',month:'short',day:'numeric'});
  const weekStart=i=>addDays(localNoon(BASE_DATE),Number(i)*7);
  const dateFor=(wi,d)=>addDays(weekStart(wi),DAY_OFFSETS[d]??0);

  function today(){const d=new Date();return new Date(d.getFullYear(),d.getMonth(),d.getDate(),12)}
  function currentWeekIndex(){return Math.floor((today()-localNoon(BASE_DATE))/604800000)}
  function currentDayKey(){return WEEKDAY_KEYS[today().getDay()]}
  function selectedDate(){
    const week=document.getElementById('week'),day=document.getElementById('day');
    if(!week||!day)return today();
    return dateFor(Number(week.value||0),day.value);
  }
  function isTodaySelected(){return isoDate(selectedDate())===isoDate(today())}

  function readState(){try{return JSON.parse(localStorage.getItem(STORAGE_KEY)||'{}')||{}}catch{return {}}}
  function writeState(state){try{localStorage.setItem(STORAGE_KEY,JSON.stringify(state))}catch{}}
  function ensureDayState(wi,d){
    const state=readState();if(!state.days)state.days={};const k=`${wi}-${d}`;
    if(!state.days[k])state.days[k]={runDone:false,liftDone:false,run:{miles:'',time:'',hr:'',rpe:'',shoe:state.shoes?.[0]||'',notes:'',carbs:'',fluid:'',sodium:'',gi:''},rec:{},sets:{},choice:{},openHow:null};
    return {state,key:k,day:state.days[k]};
  }

  function injectStyles(){
    if(document.getElementById('hcTodayModeStyles'))return;
    const s=document.createElement('style');s.id='hcTodayModeStyles';
    s.textContent=`
      .hc-today-bar{display:flex;justify-content:space-between;gap:10px;align-items:center;background:var(--panel);border:1px solid var(--border);border-radius:14px;padding:10px 12px;margin:0 0 12px}
      .hc-today-bar strong{font-size:14px}.hc-today-bar .tiny{margin-top:2px}
      .hc-today-badge{display:inline-block;border:1px solid #3b7152;background:#173624;color:var(--ok);border-radius:999px;padding:3px 7px;font-size:10px;font-weight:800;margin-right:6px}
      .hc-overview-date-nav{display:grid;grid-template-columns:1fr auto 1fr;gap:8px;align-items:center;margin:0 0 12px}
      .hc-nav-center{text-align:center;min-width:115px}
      .hc-run-auto{border:1px solid var(--border);background:var(--panel);border-radius:12px;padding:11px;margin:9px 0}
      .hc-run-auto-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin-top:8px}
      .hc-run-auto-metric{border:1px solid var(--border);background:var(--card);border-radius:10px;padding:8px}
      .hc-run-auto-metric span{display:block;color:var(--muted);font-size:10px}.hc-run-auto-metric strong{display:block;font-size:15px;margin-top:2px}
      .hc-run-manual.hc-run-collapsed{display:none!important}.hc-run-auto-actions{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-top:8px}.hc-auto-source{font-size:10px;color:var(--muted)}
      @media(max-width:720px){.hc-overview-date-nav{grid-template-columns:1fr 1fr}.hc-nav-center{grid-column:1/-1;grid-row:1}.hc-run-auto-grid{grid-template-columns:1fr 1fr}.hc-today-bar{align-items:flex-start}}
    `;
    document.head.appendChild(s);
  }

  function ensureTodayBar(){
    const root=document.getElementById('workout');if(!root)return;
    let bar=document.getElementById('hcTodayBar');
    if(!bar){bar=document.createElement('div');bar.id='hcTodayBar';bar.className='hc-today-bar';root.parentNode.insertBefore(bar,root)}
    const d=selectedDate(),onToday=isTodaySelected(),sig=`${isoDate(d)}|${onToday}`;
    if(bar.dataset.sig===sig)return;bar.dataset.sig=sig;
    bar.innerHTML=`<div><div><span class="${onToday?'hc-today-badge':'tiny'}">${onToday?'TODAY':'VIEWING'}</span><strong>${formatDate(d)}</strong></div><div class="tiny">${onToday?'Your run and lift for today are shown below.':'You are browsing another workout date.'}</div></div><button class="btn" id="hcBackToday" type="button">${onToday?'Refresh Today':'Back to Today'}</button>`;
    bar.querySelector('#hcBackToday')?.addEventListener('click',goToday);
  }

  function genericShoeOptions(selected){
    const state=readState(),shoes=Array.isArray(state.shoes)?state.shoes:[];
    return shoes.map(s=>`<option ${s===selected?'selected':''}>${String(s).replace(/</g,'&lt;')}</option>`).join('');
  }

  function renderGenericDay(dayKey){
    const root=document.getElementById('workout'),week=document.getElementById('week');if(!root||!week)return;
    const {day:x}=ensureDayState(week.value,dayKey);
    root.innerHTML=`<article class="card"><div class="dayhead"><div><div class="tiny">${dayKey.toUpperCase()} · TODAY</div><h2>Today's Training</h2><div class="coverage">Run and strength schedule are pulled from Command Center when available.</div></div></div><div class="split2"><section><div class="section-title"><label class="checkline"><input id="runDone" type="checkbox" ${x.runDone?'checked':''}> Running</label></div><strong>No run planned</strong><p class="tiny" style="font-size:12px;line-height:1.5">No run is scheduled yet.</p><div class="fields2"><label>Actual miles<input data-run="miles" type="number" value="${x.run?.miles||''}"></label><label>Time<input data-run="time" value="${x.run?.time||''}"></label><label>Avg HR<input data-run="hr" type="number" value="${x.run?.hr||''}"></label><label>RPE 1–10<input data-run="rpe" type="number" value="${x.run?.rpe||''}"></label></div><label style="display:block;margin-top:8px">Shoe<select data-run="shoe">${genericShoeOptions(x.run?.shoe)}</select></label><label style="display:block;margin-top:8px">Run notes<input data-run="notes" value="${x.run?.notes||''}"></label></section><section><div class="section-title"><label class="checkline"><input id="liftDone" type="checkbox" ${x.liftDone?'checked':''}> Lifting</label></div><div class="guidebox"><strong>No built-in lift template for this day</strong><p class="tiny" style="margin-bottom:0">If a shifted strength session is scheduled in Command Center, its completion status will still sync here.</p></div><div id="exercises"></div></section></div></article>`;
    const persist=()=>{const z=ensureDayState(week.value,dayKey);z.day.runDone=!!root.querySelector('#runDone')?.checked;z.day.liftDone=!!root.querySelector('#liftDone')?.checked;root.querySelectorAll('[data-run]').forEach(i=>z.day.run[i.dataset.run]=i.value);writeState(z.state)};
    root.querySelectorAll('[data-run]').forEach(i=>i.addEventListener('input',persist));
    root.querySelector('#runDone')?.addEventListener('change',persist);root.querySelector('#liftDone')?.addEventListener('change',persist);
    ensureTodayBar();scheduleRunSync(250);
  }

  function wrapDayHandler(){
    const day=document.getElementById('day');if(!day||day.dataset.hcTodayWrapped==='1')return;
    coreDayChange=day.onchange;
    day.onchange=function(e){
      if(['Fri','Sat','Sun'].includes(day.value))renderGenericDay(day.value);
      else if(typeof coreDayChange==='function')coreDayChange.call(day,e);
      setTimeout(()=>{ensureTodayBar();scheduleRunSync(160)},100);
    };
    day.dataset.hcTodayWrapped='1';
  }

  function ensureWeekendOption(key){
    const day=document.getElementById('day');if(!day)return;
    if(![...day.options].some(o=>o.value===key)){const o=document.createElement('option');o.value=key;o.textContent=`${{Fri:'Friday',Sat:'Saturday',Sun:'Sunday'}[key]} — Today`;day.appendChild(o)}
  }

  function desiredValueForToday(wi,key){
    if(wi===0){const iso=isoDate(today());if(iso==='2026-10-28')return'RestWed';if(iso==='2026-10-29')return'UpperThu';if(iso==='2026-10-30')return'LegsFri'}
    if(wi===1){return {Wed:'RestWed',Thu:'UpperThu',Fri:'LegsFri'}[key]||key}
    return key;
  }

  function goToday(){
    const week=document.getElementById('week'),day=document.getElementById('day');
    if(!week||!day)return;
    const wi=Math.max(0,Math.min(week.options.length-1,currentWeekIndex()));
    const key=currentDayKey(),wanted=desiredValueForToday(wi,key);

    // Refresh the week options first (the schedule module owns shifted dates).
    week.value=String(wi);
    week.dispatchEvent(new Event('change',{bubbles:true}));

    function selectActualToday(){
      wrapDayHandler();
      if(![...day.options].some(o=>o.value===wanted)){
        // Older installed bundles may not yet include the shifted option.
        // Keeping this option available also makes the Today action recoverable.
        const option=document.createElement('option');
        option.value=wanted;
        option.textContent={
          RestWed:'Wednesday — Strength Rest',
          UpperThu:'Thursday — Upper Support',
          LegsFri:'Friday — Legs'
        }[wanted]||`${key} — Today`;
        day.appendChild(option);
      }
      day.value=wanted;
      day.dispatchEvent(new Event('change',{bubbles:true}));
      lastCalendarDate=isoDate(today());
      ensureTodayBar();
      ensureOverviewNav();
      scheduleRunSync(550);
    }

    setTimeout(()=>{
      selectActualToday();
      const workoutTab=document.querySelector('.tab[data-tab="workout"]');
      if(workoutTab)workoutTab.click();
      // Some older tab handlers briefly swap the day selector. Run one
      // idempotent correction after they finish, rather than trusting a race.
      setTimeout(()=>{
        if(week.value!==String(wi)||day.value!==wanted){
          week.value=String(wi);
          week.dispatchEvent(new Event('change',{bubbles:true}));
          selectActualToday();
        }
        ensureTodayBar();
        ensureOverviewNav();
      },260);
    },100);
  }

  function workoutSlots(){
    const week=document.getElementById('week');if(!week)return[];const slots=[];
    for(let wi=0;wi<week.options.length;wi++){
      const shifted=[{d:'Mon',v:'Mon'},{d:'Tue',v:'Tue'},{d:'Thu',v:'UpperThu'},{d:'Fri',v:'LegsFri'}];
      const days=(wi===0||wi===1)?shifted:WORKOUT_DAYS.map(d=>({d,v:d}));
      days.forEach(x=>slots.push({wi,key:x.d,value:x.v,date:dateFor(wi,x.d)}));
    }
    return slots;
  }

  function openSlot(slot){
    const week=document.getElementById('week'),day=document.getElementById('day');if(!week||!day||!slot)return;
    week.value=String(slot.wi);week.dispatchEvent(new Event('change',{bubbles:true}));
    setTimeout(()=>{
      wrapDayHandler();if(['Fri','Sat','Sun'].includes(slot.value))ensureWeekendOption(slot.value);
      const wanted=[...day.options].some(o=>o.value===slot.value)?slot.value:slot.key;
      if([...day.options].some(o=>o.value===wanted))day.value=wanted;
      day.dispatchEvent(new Event('change',{bubbles:true}));
      document.querySelector('.tab[data-tab="workout"]')?.click();ensureTodayBar();
    },120);
  }

  function ensureOverviewNav(){
    const panel=document.querySelector('[data-panel="overview"]'),hero=panel?.querySelector('.hc-overview-hero');if(!panel||!hero)return;
    let nav=panel.querySelector('.hc-overview-date-nav');if(!nav){nav=document.createElement('div');nav.className='hc-overview-date-nav';hero.insertAdjacentElement('afterend',nav)}
    const slots=workoutSlots(),current=selectedDate().getTime();let prev=null,next=null;
    slots.forEach(s=>{const t=s.date.getTime();if(t<current&&(!prev||t>prev.date.getTime()))prev=s;if(t>current&&(!next||t<next.date.getTime()))next=s});
    const sig=`${isoDate(selectedDate())}|${prev?isoDate(prev.date):''}|${next?isoDate(next.date):''}`;
    if(nav.dataset.sig===sig)return;nav.dataset.sig=sig;
    nav.innerHTML=`<button class="btn" id="hcPrevWorkout" type="button" ${prev?'':'disabled'}>‹ Previous workout</button><div class="hc-nav-center"><strong>${isTodaySelected()?'Today':'Browse'}</strong><div class="tiny">${formatDate(selectedDate())}</div><button class="hc-reset" id="hcOverviewToday" type="button">Go to today</button></div><button class="btn" id="hcNextWorkout" type="button" ${next?'':'disabled'}>Next workout ›</button>`;
    nav.querySelector('#hcPrevWorkout')?.addEventListener('click',()=>openSlot(prev));
    nav.querySelector('#hcNextWorkout')?.addEventListener('click',()=>openSlot(next));
    nav.querySelector('#hcOverviewToday')?.addEventListener('click',goToday);
  }

  function secondsToClock(sec){sec=Math.max(0,Math.round(Number(sec)||0));const h=Math.floor(sec/3600),m=Math.floor((sec%3600)/60),s=sec%60;return h?`${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`:`${m}:${String(s).padStart(2,'0')}`}
  function paceToMi(secKm){const sec=Math.round((Number(secKm)||0)*1.609344);return sec?`${Math.floor(sec/60)}:${String(sec%60).padStart(2,'0')}/mi`:'—'}
  function setField(name,value){const el=document.querySelector(`#workout [data-run="${name}"]`);if(!el||value===null||value===undefined||value==='')return;if(String(el.value)===String(value))return;el.value=value;el.dispatchEvent(new Event('input',{bubbles:true}))}
  function lastShoe(){
    const state=readState(),entries=Object.entries(state.days||{}).sort((a,b)=>b[0].localeCompare(a[0]));
    for(const [,x] of entries){if(x?.runDone&&x?.run?.shoe)return x.run.shoe}
    return state.shoes?.[0]||'';
  }

  function markManualFields(section){
    if(!section)return[];const nodes=[];
    const fields=[...section.querySelectorAll('.fields2')].find(x=>x.querySelector('[data-run="miles"]'));if(fields)nodes.push(fields);
    section.querySelectorAll('label').forEach(l=>{if(l.querySelector('[data-run="shoe"]')||l.querySelector('[data-run="notes"]'))nodes.push(l)});
    section.querySelectorAll('.guidebox').forEach(g=>{if(/Long-run fueling/i.test(g.textContent||''))nodes.push(g)});
    nodes.forEach(n=>n.classList.add('hc-run-manual','hc-run-collapsed'));return nodes;
  }

  function readRunValues(){const get=n=>document.querySelector(`#workout [data-run="${n}"]`)?.value||'';return {miles:get('miles'),time:get('time'),hr:get('hr'),rpe:get('rpe'),shoe:get('shoe')}}

  function decorateRun(eventData,status='waiting'){
    const runDone=document.querySelector('#workout #runDone'),section=runDone?.closest('section');if(!section)return;
    const manual=markManualFields(section);let box=section.querySelector('.hc-run-auto');
    if(!box){box=document.createElement('div');box.className='hc-run-auto';const guide=section.querySelector('p.tiny');(guide||section.querySelector('.section-title'))?.insertAdjacentElement('afterend',box)}
    const v=readRunValues(),has=!!eventData,sig=`${has}|${status}|${v.miles}|${v.time}|${v.hr}|${v.rpe}|${v.shoe}|${eventData?.activity_synced_at||''}`;
    if(box.dataset.sig===sig)return;box.dataset.sig=sig;
    box.innerHTML=has?`<div><strong>Run auto-logged</strong><div class="hc-auto-source">${eventData.activity_attribution==='Garmin'?'Garmin · ':''}synced through Tredict</div></div><div class="hc-run-auto-grid"><div class="hc-run-auto-metric"><span>Distance</span><strong>${v.miles||'—'} mi</strong></div><div class="hc-run-auto-metric"><span>Time</span><strong>${v.time||'—'}</strong></div><div class="hc-run-auto-metric"><span>Avg HR</span><strong>${v.hr||'—'}${v.hr?' bpm':''}</strong></div><div class="hc-run-auto-metric"><span>RPE</span><strong>${v.rpe||'—'}</strong></div><div class="hc-run-auto-metric"><span>Avg pace</span><strong>${paceToMi(eventData.activity_pace_sec_km)}</strong></div><div class="hc-run-auto-metric"><span>Calories</span><strong>${eventData.activity_calories?Math.round(eventData.activity_calories)+' kcal':'—'}</strong></div></div><div class="hc-run-auto-actions"><span class="tiny">Shoe: <strong>${v.shoe||'Not set'}</strong></span><button class="btn" type="button" data-hc-edit-run>Edit details</button></div>`:`<div><strong>${status==='connect'?'Connect Command Center for automatic run logging':'Automatic run logging'}</strong><div class="tiny" style="margin-top:4px">${status==='connect'?'Once connected, completed Garmin/Tredict runs can fill this card automatically.':'No manual entry needed. After your completed run reaches Tredict, distance, time, average HR and RPE will fill in here automatically.'}</div></div><div class="hc-run-auto-actions"><span class="tiny">Remembered shoe: <strong>${v.shoe||lastShoe()||'—'}</strong></span><button class="btn" type="button" data-hc-edit-run>Edit details</button></div>`;
    box.querySelector('[data-hc-edit-run]')?.addEventListener('click',()=>{manual.forEach(n=>n.classList.toggle('hc-run-collapsed'));const b=box.querySelector('[data-hc-edit-run]');if(b)b.textContent=manual.some(n=>n.classList.contains('hc-run-collapsed'))?'Edit details':'Hide details'});
  }

  async function getAutoClient(){
    if(autoClient)return autoClient;
    if(!window.supabase?.createClient)return null;
    autoClient=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,storageKey:AUTH_STORAGE_KEY,autoRefreshToken:true,detectSessionInUrl:false}});
    return autoClient;
  }

  async function syncRunMetrics(){
    clearTimeout(runSyncTimer);const runDone=document.querySelector('#workout #runDone');if(!runDone){ensureTodayBar();return}
    const shoe=document.querySelector('#workout [data-run="shoe"]');
    if(shoe&&!shoe.value){const s=lastShoe();if(s&&[...shoe.options].some(o=>o.value===s)){shoe.value=s;shoe.dispatchEvent(new Event('input',{bubbles:true}))}}
    const client=await getAutoClient();
    if(!client){decorateRun(null,'waiting');if(sdkRetries<6){sdkRetries++;scheduleRunSync(1200)}return}
    sdkRetries=0;
    try{
      const {data:{session}}=await client.auth.getSession();if(!session){decorateRun(null,'connect');return}
      const date=isoDate(selectedDate());
      const {data,error}=await client.from('workout_completion_events').select('activity_started_at,activity_duration_sec,activity_duration_total_sec,activity_distance_m,activity_avg_hr,activity_max_hr,activity_calories,activity_pace_sec_km,activity_rpe,activity_enjoyment,activity_attribution,activity_synced_at').eq('workout_date',date).eq('workout_kind','run').eq('source','Tredict').order('activity_duration_sec',{ascending:false,nullsFirst:false}).limit(3);
      if(error)throw error;
      const eventData=(data||[]).find(x=>x.activity_duration_sec||x.activity_distance_m)||null;if(!eventData){decorateRun(null,'waiting');return}
      if(eventData.activity_distance_m)setField('miles',(Number(eventData.activity_distance_m)/1609.344).toFixed(2));
      const sec=eventData.activity_duration_total_sec||eventData.activity_duration_sec;if(sec)setField('time',secondsToClock(sec));
      if(eventData.activity_avg_hr)setField('hr',Math.round(eventData.activity_avg_hr));if(eventData.activity_rpe)setField('rpe',Number(eventData.activity_rpe));
      if(!runDone.checked){runDone.checked=true;runDone.dispatchEvent(new Event('change',{bubbles:true}));setTimeout(()=>decorateRun(eventData,'synced'),180)}else decorateRun(eventData,'synced');
    }catch(err){console.warn('Hybrid Coach automatic run log unavailable',err);decorateRun(null,'waiting')}
  }
  function scheduleRunSync(delay=300){clearTimeout(runSyncTimer);runSyncTimer=setTimeout(syncRunMetrics,delay)}

  function attachEvents(){
    document.addEventListener('hc:overview-rendered',()=>setTimeout(ensureOverviewNav,55));
    document.addEventListener('change',e=>{const id=e.target?.id;if(id==='week'||id==='day'){setTimeout(()=>{ensureTodayBar();ensureOverviewNav();scheduleRunSync(320)},120)}else if(id==='runDone'){setTimeout(()=>scheduleRunSync(250),120)}},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.tab[data-tab="overview"]'))setTimeout(ensureOverviewNav,120);if(e.target?.closest?.('.tab[data-tab="workout"]'))setTimeout(()=>{ensureTodayBar();scheduleRunSync(250)},120)},true);
    document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'){const nowIso=isoDate(today());if(lastCalendarDate&&lastCalendarDate!==nowIso)goToday();else scheduleRunSync(300)}});
    window.addEventListener('focus',()=>scheduleRunSync(300));
    setInterval(()=>{const nowIso=isoDate(today());if(lastCalendarDate&&lastCalendarDate!==nowIso)goToday();else scheduleRunSync(250)},300000);
  }

  function start(){injectStyles();wrapDayHandler();attachEvents();setTimeout(goToday,450);setTimeout(()=>{ensureOverviewNav();scheduleRunSync(450)},1900)}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
