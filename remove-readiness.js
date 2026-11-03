(()=>{
  if(window.__hybridCoachRemoveReadiness)return;
  window.__hybridCoachRemoveReadiness=true;

  function addStyles(){
    if(document.getElementById('hcRemoveReadinessStyles'))return;
    const s=document.createElement('style');
    s.id='hcRemoveReadinessStyles';
    s.textContent=`
      .hc-readiness-hidden{display:none!important}
      .hc-readiness-grid{grid-template-columns:repeat(3,1fr)!important}
      @media(max-width:720px){.hc-readiness-grid{grid-template-columns:1fr 1fr!important}}
    `;
    document.head.appendChild(s);
  }

  function hideMetric(id){
    const el=document.getElementById(id);
    const metric=el?.closest?.('.metric');
    if(metric){
      metric.classList.add('hc-readiness-hidden');
      metric.parentElement?.classList.add('hc-readiness-grid');
    }
  }

  function removeWorkoutReadiness(){
    document.querySelectorAll('#workout .dayhead').forEach(head=>{
      [...head.children].forEach(child=>{
        const strong=child.querySelector?.('strong');
        const text=(strong?.textContent||'').trim();
        if(/^(Green|Yellow|Red|—)(?:\s*·.*)?$/i.test(text))child.classList.add('hc-readiness-hidden');
      });
    });
  }

  function removeDashboardReadiness(){
    hideMetric('dashReady');
    const recovery=document.getElementById('recoveryDash');
    if(recovery?.closest?.('.card'))recovery.closest('.card').classList.add('hc-readiness-hidden');
  }

  function scrubCoachText(){
    const box=document.getElementById('coachText');
    if(!box?.value)return;
    box.value=box.value.replace(/Recovery:\s*[^|\n]*\|\s*Sleep/g,'Recovery log: Sleep');
  }

  function apply(){
    addStyles();
    hideMetric('readyTop');
    removeDashboardReadiness();
    removeWorkoutReadiness();
  }

  const observer=new MutationObserver(()=>apply());
  function start(){
    apply();
    observer.observe(document.body,{childList:true,subtree:true});

    document.getElementById('buildCoach')?.addEventListener('click',()=>setTimeout(scrubCoachText,0));
    document.addEventListener('click',e=>{
      const target=e.target?.closest?.('#copyCoach,#shareCoach');
      if(!target)return;
      const box=document.getElementById('coachText');
      if(box&&!box.value){
        document.getElementById('buildCoach')?.click();
      }
      scrubCoachText();
    },true);
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
  else start();
})();
