(()=>{
  if(window.__hybridCoachWeek44StrengthSchedule)return;
  window.__hybridCoachWeek44StrengthSchedule=true;

  const week=document.getElementById('week');
  const day=document.getElementById('day');
  const root=document.getElementById('workout');
  if(!week||!day||!root)return;

  const coreDayChange=day.onchange;
  const coreWeekChange=week.onchange;
  const WEEK44='0';
  const WEEK45='1';
  const SPECIAL={
    RestWed:{slot:null,label:'Wednesday — Rest / Recovery',calendar:'Wed'},
    UpperThu:{slot:'Wed',label:'Thursday — Upper Support',calendar:'Thu'},
    LegsFri:{slot:'Thu',label:'Friday — Legs',calendar:'Fri'}
  };

  function isWeek44(){return [WEEK44,WEEK45].includes(String(week.value))}
  function isWeek45(){return String(week.value)===WEEK45}
  function slotFor(v){return SPECIAL[v]?.slot||v}
  function makeOption(value,text){const o=document.createElement('option');o.value=value;o.textContent=text;return o}

  function defaultOptions(prefer){
    const map=[['Mon','Monday — Push'],['Tue','Tuesday — Pull'],['Wed','Wednesday — Upper Support'],['Thu','Thursday — Legs']];
    day.innerHTML='';map.forEach(([v,t])=>day.appendChild(makeOption(v,t)));
    day.value=map.some(([v])=>v===prefer)?prefer:'Mon';
  }

  function todayWeek44Value(){
    const d=new Date();
    const y=d.getFullYear(),m=d.getMonth()+1,n=d.getDate();
    if(y===2026&&m===10&&n===28)return'RestWed';
    if(y===2026&&m===10&&n===29)return'UpperThu';
    if(y===2026&&m===10&&n===30)return'LegsFri';
    if(y===2026&&m===11&&n===4)return'RestWed';
    if(y===2026&&m===11&&n===5)return'UpperThu';
    if(y===2026&&m===11&&n===6)return'LegsFri';
    return null;
  }

  function week44Options(prefer){
    const previous=prefer||day.value;
    day.innerHTML='';
    day.appendChild(makeOption('Mon','Monday — Push'));
    day.appendChild(makeOption('Tue','Tuesday — Pull'));
    day.appendChild(makeOption('RestWed',SPECIAL.RestWed.label));
    day.appendChild(makeOption('UpperThu',SPECIAL.UpperThu.label));
    day.appendChild(makeOption('LegsFri',SPECIAL.LegsFri.label));
    const wanted=['Mon','Tue','RestWed','UpperThu','LegsFri'].includes(previous)?previous:(todayWeek44Value()||'Mon');
    day.value=wanted;
  }

  function disableRunSection(message){
    const runDone=root.querySelector('#runDone');
    const section=runDone?.closest('section');
    if(!section)return;
    section.classList.remove('complete');
    section.innerHTML=`<div class="guidebox"><strong>No run planned</strong><p class="tiny" style="font-size:12px;line-height:1.5;margin-bottom:0">${message}</p></div>`;
  }

  function patchHeader(calendar,title,coverage,kicker){
    const head=root.querySelector('.dayhead');
    if(!head)return;
    const tiny=head.querySelector('.tiny');
    const h2=head.querySelector('h2');
    const cov=head.querySelector('.coverage');
    if(tiny)tiny.textContent=`${calendar.toUpperCase()} · ${kicker}`;
    if(h2&&title)h2.textContent=title;
    if(cov&&coverage)cov.textContent=coverage;
  }

  function renderRest(){
    if(isWeek45()&&typeof coreDayChange==='function'){
      // Keep Wednesday's planned run, but replace the strength card with recovery.
      day.value='Wed';
      coreDayChange.call(day);
      day.value='RestWed';
      const lift=root.querySelector('#liftDone')?.closest('section');
      if(lift){
        lift.classList.remove('complete');
        lift.innerHTML='<div class="guidebox"><strong>Strength rest / recovery</strong><p class="tiny">No upper-body lifting Wednesday, November 4. Upper Support has been moved to Thursday, November 5; Legs to Friday, November 6.</p></div>';
      }
      patchHeader('Wed','Rest from Strength','Upper Support Thursday · Legs Friday · Running plan unchanged','LIFT REST DAY');
      return;
    }
    root.innerHTML=`
      <article class="card">
        <div class="dayhead">
          <div>
            <div class="tiny">WED · RECOVERY GAP</div>
            <h2>Rest / Recovery Day</h2>
            <div class="coverage">No lifting today · Upper Support moved to Thursday · Legs moved to Friday</div>
          </div>
          <div style="text-align:right"><strong class="status-green">REST</strong><div class="tiny">Use the gap to recover for the next two lifting days.</div></div>
        </div>
        <div class="guidebox" style="margin-top:12px">
          <strong>Wednesday, October 28</strong>
          <p class="tiny" style="font-size:13px;line-height:1.55;margin-bottom:0">This is the intentional gap you requested. No strength workout is scheduled today. Upper Support is Thursday, October 29, and Legs is Friday, October 30.</p>
        </div>
      </article>`;
  }

  function bindThursdayRun(){
    // Strength inputs belong to the original Upper slot; the run inputs must
    // use Thursday's own log instead of accidentally rewriting Wednesday's run.
    const old=root.querySelector('#runDone')?.closest('section');
    if(!old)return;
    const section=old.cloneNode(true);
    old.replaceWith(section);
    const runDone=section.querySelector('#runDone');
    const storageKey='hybridCoachData_v1';
    const sk=String(week.value)+'-Thu';
    function read(){try{return JSON.parse(localStorage.getItem(storageKey)||'{}')}catch{return {}}}
    function dayData(state){
      state.days=state.days||{};
      if(!state.days[sk])state.days[sk]={runDone:false,liftDone:false,run:{},rec:{},sets:{},choice:{}};
      if(!state.days[sk].run)state.days[sk].run={};
      return state.days[sk];
    }
    const st=read(),entry=dayData(st);
    if(runDone)runDone.checked=!!entry.runDone;
    section.classList.toggle('complete',!!entry.runDone);
    section.querySelectorAll('[data-run]').forEach(el=>{
      el.value=entry.run?.[el.dataset.run]??'';
      el.addEventListener('input',()=>{
        const next=read(),d=dayData(next);
        d.run[el.dataset.run]=el.value;
        localStorage.setItem(storageKey,JSON.stringify(next));
      });
    });
    runDone?.addEventListener('change',()=>{
      const next=read(),d=dayData(next);
      d.runDone=!!runDone.checked;
      localStorage.setItem(storageKey,JSON.stringify(next));
      section.classList.toggle('complete',d.runDone);
    });
    const title=section.querySelector(':scope > strong');
    const note=section.querySelector('p.tiny');
    if(title)title.textContent='Recovery Run — 30 Min';
    if(note)note.textContent='Easy recovery run scheduled for Thursday, November 5, in Command Center / Tredict.';
    if(runDone)runDone.disabled=false;
  }

  function renderMoved(value){
    const spec=SPECIAL[value];
    if(!spec?.slot||typeof coreDayChange!=='function')return;
    const custom=value;
    day.value=spec.slot;
    coreDayChange.call(day);
    day.value=custom;

    if(value==='UpperThu'){
      patchHeader('Thu','Upper Support — Bench + Back Frequency','Chest · upper back · lats · lateral delt · rear delt · triceps · biceps · rotator cuff','UPPER SESSION');
      if(isWeek45())bindThursdayRun();
      else disableRunSection('Upper Support only for this shifted Week 44 session. The lifting workout was moved here from Wednesday.');
    }else if(value==='LegsFri'){
      patchHeader('Fri','Legs — Heavy + Hypertrophy','Quads · hamstrings · glutes · calves · soleus · core','LEGS SESSION');
      disableRunSection(isWeek45()?'Friday, November 6, is a leg-strength day. No run is scheduled in Command Center for Friday.':'Leg day only for this shifted Week 44 session. The lifting workout was moved here from Thursday.');
    }
  }

  function renderCurrent(){
    if(!isWeek44()){
      if(typeof coreDayChange==='function')coreDayChange.call(day);
      return;
    }
    if(day.value==='RestWed')renderRest();
    else if(day.value==='UpperThu'||day.value==='LegsFri')renderMoved(day.value);
    else if(typeof coreDayChange==='function')coreDayChange.call(day);
  }

  day.onchange=function(){renderCurrent()};
  week.onchange=function(){
    const old=day.value;
    if(isWeek44()){
      week44Options(todayWeek44Value()||old);
      renderCurrent();
    }else{
      defaultOptions(slotFor(old));
      if(typeof coreWeekChange==='function')coreWeekChange.call(week);
      else if(typeof coreDayChange==='function')coreDayChange.call(day);
    }
  };

  document.addEventListener('click',e=>{
    const tab=e.target?.closest?.('.tab');
    if(!tab||!isWeek44()||!SPECIAL[day.value])return;
    const custom=day.value,spec=SPECIAL[custom];
    if(!spec.slot)return;
    day.value=spec.slot;
    setTimeout(()=>{if(isWeek44()){day.value=custom;if(tab.dataset.tab==='workout')renderMoved(custom)}},0);
  },true);

  document.addEventListener('click',e=>{
    const btn=e.target?.closest?.('.weekBtn');
    if(!btn)return;
    const custom=day.value;
    if(SPECIAL[custom]?.slot)day.value=SPECIAL[custom].slot;
    setTimeout(()=>{
      if(isWeek44()){week44Options(todayWeek44Value()||custom);renderCurrent()}
      else if(!['Mon','Tue','Wed','Thu'].includes(day.value))defaultOptions('Mon');
    },20);
  },true);

  function relabelCoachText(){
    const box=document.getElementById('coachText');
    if(!box||!box.value)return;
    box.value=box.value
      .replace(/WEEK 1 \(Oct 26\) — Thu/g,'WEEK 1 (Oct 26) — Fri (Legs moved from Thu)')
      .replace(/WEEK 1 \(Oct 26\) — Wed/g,'WEEK 1 (Oct 26) — Thu (Upper Support moved from Wed)');
  }
  document.getElementById('buildCoach')?.addEventListener('click',()=>setTimeout(relabelCoachText,0));
  document.getElementById('copyCoach')?.addEventListener('click',()=>setTimeout(relabelCoachText,0),true);
  document.getElementById('shareCoach')?.addEventListener('click',()=>setTimeout(relabelCoachText,0),true);

  if(isWeek44()){
    const initial=todayWeek44Value()||(['Wed','Thu'].includes(day.value)?(day.value==='Wed'?'RestWed':'UpperThu'):day.value);
    week44Options(initial);
    renderCurrent();
  }
})();
