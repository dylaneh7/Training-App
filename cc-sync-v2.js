(()=>{
  if(window.__hybridCoachCloudLoader)return;
  window.__hybridCoachCloudLoader=true;

  const WEEK44={
    Mon:{title:'Tempo Progression — 2 x 10 Min',guide:'Controlled tempo progression. Keep it smooth and sustainable; use HRM 600.'},
    Tue:{title:'Recovery Run — 30 Min',guide:'Very easy recovery effort. Keep the legs moving without adding fatigue.'},
    Wed:{title:'Long Run — 8.5 Miles Easy',guide:'Easy conversational long run. Small progression from 8 miles; no fast finish.'},
    Thu:null
  };

  function applyWeek44Fallback(){
    try{
      const week=document.getElementById('week');
      const day=document.getElementById('day');
      if(!week||!day)return;

      if(week.options[0])week.options[0].textContent='Week 44 · Oct 26 · Build';
      const firstPlan=document.querySelector('#runPlan .weekBtn:first-child');
      if(firstPlan){
        const strong=firstPlan.querySelector('strong');
        const tiny=[...firstPlan.querySelectorAll('.tiny')].pop();
        if(strong)strong.textContent='Week 44 · Oct 26';
        if(tiny)tiny.textContent='Mon Tempo Progression — 2 x 10 Min · Tue Recovery Run — 30 Min · Wed Long Run — 8.5 Miles Easy';
      }

      if(String(week.value)!=='0')return;
      const runDone=document.getElementById('runDone');
      if(!runDone)return;
      const section=runDone.closest('section');
      if(!section)return;
      const title=[...section.querySelectorAll(':scope > strong')][0]||section.querySelector('strong');
      const guide=section.querySelector('p.tiny');
      const run=WEEK44[day.value];
      section.classList.toggle('cc-no-run',!run);
      runDone.disabled=!run;
      if(run){
        if(title)title.textContent=run.title;
        if(guide)guide.textContent=run.guide;
      }else{
        if(title)title.textContent='No run planned';
        if(guide)guide.textContent='No run is scheduled in Command Center for this day.';
      }
    }catch(err){
      console.warn('Hybrid Coach Week 44 fallback failed',err);
    }
  }

  function loadScript(src,marker){
    try{
      if(document.querySelector(`script[${marker}]`))return;
      const s=document.createElement('script');s.src=src;s.async=true;s.setAttribute(marker,'1');document.body.appendChild(s);
    }catch(err){console.warn('Hybrid Coach add-on failed to load',err)}
  }

  function loadCloud(){
    applyWeek44Fallback();
    setTimeout(()=>loadScript('./exercise-editor.js?v=2','data-hybrid-exercise-editor'),180);
    setTimeout(()=>loadScript('./set-editor.js?v=1','data-hybrid-set-editor'),320);
    setTimeout(()=>loadScript('./progression-coach.js?v=1','data-hybrid-progression-coach'),520);
    setTimeout(()=>loadScript('./cc-cloud.js?v=3','data-hybrid-cloud-runtime'),900);
  }

  document.addEventListener('change',e=>{
    if(e.target?.id==='week'||e.target?.id==='day')setTimeout(applyWeek44Fallback,40);
  },true);
  document.addEventListener('click',e=>{
    if(e.target?.closest?.('.weekBtn,.tab'))setTimeout(applyWeek44Fallback,80);
  },true);

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',()=>setTimeout(loadCloud,80),{once:true});
  }else{
    setTimeout(loadCloud,80);
  }
})();
