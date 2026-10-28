(()=>{
  if(window.__hybridCoachRestPolicy)return;
  window.__hybridCoachRestPolicy=true;

  const REST_BY_EXERCISE={
    'Bench Press — Barbell':'2:00',
    'Overhead Press — Barbell':'2:00',
    'Bench Press — Incline — Dumbbell':'2:00',
    'Close-Grip Chest Press — Barbell':'2:00',
    'Lat Pulldown — Wide-Grip Front Pull':'2:00',
    'Seated Row':'2:00',
    'Pull-Up Finisher':'2:00',

    'Independent-Arm Plate-Loaded Row — Right / Left':'1:30',
    'Chest-Supported High Row — Elbows ~45°':'1:30',
    'Smith or Dumbbell Shrug':'1:30',
    'Machine Chest Fly / Pec Deck':'1:15',
    'Behind-Body Cable Lateral Raise':'1:15',
    'Machine Lateral Raise':'1:15',
    'Reverse Pec Deck — Rear-Delt Bias':'1:15',
    'EZ-Bar Skull Crusher':'1:30',
    'Triceps Pulldown — Rope':'1:15',
    'Push-Up Plus / Serratus Punch':'1:00',
    'Straight-Arm Cable Pulldown / Pullover':'1:15',
    'Cable Y-Raise / Trap-3 Raise':'1:00',
    'Chest-Supported Kelso Shrug / Scapular Row':'1:15',
    'Cable Face Pull + External Rotation':'1:00',
    'Bayesian Cable Curl':'1:15',
    'Preacher Curl':'1:15',
    'Hammer Curl — Dumbbell':'1:00',
    'Reverse EZ-Bar Curl':'1:00'
  };

  function currentExerciseName(box){
    const select=box.querySelector('.choice');
    return (select?.value||select?.selectedOptions?.[0]?.textContent||'').trim();
  }

  function applyRestPolicy(){
    const root=document.getElementById('workout');
    if(!root)return;
    root.querySelectorAll('#exercises .exercise').forEach(box=>{
      const name=currentExerciseName(box);
      const rest=REST_BY_EXERCISE[name];
      if(!rest)return;
      const how=box.querySelector('.how');
      if(!how)return;
      const restLabel=[...how.querySelectorAll('b,strong')].find(el=>/^Rest:?$/i.test((el.textContent||'').trim()));
      if(restLabel){
        let n=restLabel.nextSibling;
        while(n&&n.nodeType===3&&!(n.textContent||'').trim())n=n.nextSibling;
        if(n&&n.nodeType===3){n.textContent=' '+rest;}
        else restLabel.insertAdjacentText('afterend',' '+rest);
      }else{
        how.insertAdjacentHTML('beforeend',`<br><span class="tiny"><b>Rest:</b> ${rest}</span>`);
      }
    });

    const note=root.querySelector('.hc-push-pull-note');
    if(note&&!note.dataset.restPolicy){
      note.textContent += ' Rest policy: big compound lifts cap at 2:00; smaller/accessory and single-muscle work uses 1:00–1:30.';
      note.dataset.restPolicy='1';
    }
  }

  let timer;
  function schedule(ms=0){clearTimeout(timer);timer=setTimeout(applyRestPolicy,ms)}
  const observer=new MutationObserver(()=>schedule(60));
  function start(){
    const root=document.getElementById('workout');
    if(root)observer.observe(root,{childList:true,subtree:true,characterData:true});
    schedule(120);
  }
  document.addEventListener('change',e=>{
    if(e.target?.id==='week'||e.target?.id==='day'||e.target?.classList?.contains('choice'))schedule(100);
  },true);
  document.addEventListener('click',()=>schedule(120),true);
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
  else start();
})();
