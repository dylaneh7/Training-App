(()=>{
  if(window.__hybridCoachPushPullV2)return;
  window.__hybridCoachPushPullV2=true;

  const VERSION='2026-10-27-v2';
  const TRAINING_KEY='hybridCoachData_v1';

  const PLAN={
    Mon:{
      title:'Push — Chest + All 3 Delts + Triceps + Serratus',
      coverage:'Upper / clavicular chest · mid / sternal chest · lower chest · anterior delt · lateral delt · posterior delt · triceps long / lateral / medial heads · serratus anterior',
      note:'Direct rear-delt work lives here on Push. Heavy presses stay shy of failure; isolation work can be pushed harder when recovery is good.',
      exercises:[
        {original:'Flat barbell bench press',name:'Flat barbell bench press',sets:4,reps:'4–6',region:'Mid / sternal chest',role:'Primary strength press',rest:'3–5 min',swaps:['Smith machine bench press','Dumbbell bench press','Machine chest press'],how:'Retract and depress the shoulder blades, plant the feet, and use a repeatable touch point on the lower-to-mid chest. Keep forearms close to vertical at the bottom. Drive hard while keeping the shoulders pinned. Target about 1–2 RIR on work sets rather than grinding every set to failure.'},
        {original:'Incline dumbbell press',name:'Low-incline dumbbell press',sets:3,reps:'6–10',region:'Upper / clavicular chest',role:'Upper-pec hypertrophy',rest:'2–3 min',swaps:['Low-incline Smith press','Incline machine press','Incline barbell press'],how:'Use roughly a 20–35° bench angle so the clavicular pec stays the priority instead of turning this into a shoulder press. Lower under control into a comfortable stretch and press up and slightly inward. Keep 1–2 RIR until the final set.'},
        {original:'Weighted dip — chest bias',name:'Weighted dip — chest bias',sets:3,reps:'6–10',region:'Lower chest',role:'Lower-pec heavy press',rest:'2.5–4 min',swaps:['Decline machine press','Decline barbell press','High-to-low cable press'],how:'Lean the torso slightly forward and let the elbows travel naturally. Descend only as far as the shoulder stays comfortable, then drive up without bouncing. Add load only when the full ROM is controlled. If the front of the shoulder feels pinched, use a decline press instead.'},
        {original:'Seated dumbbell shoulder press',name:'Seated dumbbell shoulder press',sets:3,reps:'6–10',region:'Anterior delt',role:'Heavy shoulder press',rest:'2.5–4 min',swaps:['Machine shoulder press','Neutral-grip dumbbell shoulder press','Smith shoulder press'],how:'Sit tall with ribs stacked over the pelvis. Start with forearms vertical and press overhead without turning the movement into a low-back extension. Keep 1–2 RIR so the pressing quality stays high after chest work.'},
        {original:'Chest-supported lateral raise',name:'Behind-body cable lateral raise',sets:3,reps:'10–15',region:'Lateral delt',role:'Lengthened lateral-delt work',rest:'75–120 sec',swaps:['Lean-away cable lateral raise','Chest-supported lateral raise','Single-arm cable lateral raise'],how:'Stand slightly in front of a low cable so the working arm starts a little behind the torso. Lead with the elbow and raise in the scapular plane to about shoulder height. Keep the trap relaxed and control the bottom stretch instead of using momentum.'},
        {original:'Standing lateral raise',name:'Machine lateral raise',sets:3,reps:'12–20',region:'Lateral delt',role:'Stable lateral-delt overload',rest:'60–120 sec',swaps:['Standing dumbbell lateral raise','Cable lateral raise','Chest-supported lateral raise'],how:'Set the machine so the shoulder starts in a comfortable slightly adducted position. Drive the upper arm out and up without shrugging. Keep constant tension and take the final set to roughly 0–1 RIR only when recovery is good.'},
        {original:'Single-arm cable rear-delt fly',name:'Reverse pec deck — neutral grip',sets:3,reps:'12–20',region:'Posterior delt',role:'Direct rear-delt isolation',rest:'60–120 sec',swaps:['Single-arm cable rear-delt fly','Chest-supported rear-delt raise','Prone rear-delt fly'],how:'Use a neutral or comfortable grip and sweep the upper arms outward in horizontal abduction. Keep a soft elbow bend and avoid turning it into a row. The goal is the posterior delt, not maximal scapular retraction.'},
        {original:'Close-grip bench press',name:'Close-grip bench press',sets:3,reps:'5–8',region:'Triceps',role:'Heavy triceps press',rest:'2.5–4 min',swaps:['JM press','Smith close-grip bench press','Weighted close-grip push-up'],how:'Use a moderately narrow grip that keeps the wrists stacked over the forearms. Lower under control with the elbows tracking naturally, then drive hard. Keep 1–2 RIR; this is a strength-oriented triceps slot, not a failure exercise.'},
        {original:'Overhead cable triceps extension',name:'Overhead cable triceps extension',sets:3,reps:'10–15',region:'Triceps long head',role:'Lengthened long-head triceps',rest:'75–120 sec',swaps:['Single-arm overhead cable extension','Incline skull crusher','Dumbbell overhead extension'],how:'Keep the upper arms pointed forward or slightly upward and let the elbows flex deeply so the long head is trained at a long muscle length. Extend hard without letting the shoulders drift. The last set may reach 0–1 RIR.'},
        {original:'Rope pressdown',name:'Single-arm cable pressdown',sets:2,reps:'10–15',region:'Triceps lateral / medial heads',role:'Triceps isolation',rest:'60–90 sec',swaps:['Rope pressdown','Straight-bar pressdown','V-bar pressdown'],how:'Pin the upper arm to the side and move only through the elbow. Use a full controlled return and finish with a hard elbow extension. Push these close to failure with clean technique.'},
        {original:'Push-up plus',name:'Push-up plus / serratus punch',sets:2,reps:'12–20',region:'Serratus anterior',role:'Scapular protraction',rest:'60–90 sec',swaps:['Cable serratus punch','Serratus wall slide'],how:'At the top of the push-up, continue pushing the floor away so the shoulder blades wrap forward around the rib cage. Keep the neck relaxed and do not shrug. On a cable punch, reach forward through the scapula without rotating the torso.'}
      ]
    },
    Tue:{
      title:'Pull — Lats + Complete Upper Back + Traps + Arms + Grip',
      coverage:'Lats · teres major · rhomboids · upper / mid / lower traps · rotator-cuff external rotators · biceps long / short heads · brachialis · brachioradialis · forearms · grip',
      note:'No direct rear-delt isolation on Pull. Rows will still recruit the posterior delt indirectly, but the direct delt volume is kept on Push.',
      exercises:[
        {original:'Weighted pull-up / neutral pulldown',name:'Weighted neutral-grip pull-up / pulldown',sets:4,reps:'5–8',region:'Lats / teres major',role:'Primary vertical pull',rest:'3–5 min',swaps:['Neutral-grip lat pulldown','Weighted pull-up','Assisted neutral-grip pull-up'],how:'Start from long arms and let the shoulder blades upwardly rotate at the top. Initiate by driving the elbows down toward the ribs. Keep the torso mostly tall and avoid turning the last reps into a swinging row. Use about 1–2 RIR.'},
        {original:'Chest-supported T-bar row',name:'Chest-supported T-bar row',sets:4,reps:'6–10',region:'Mid back / rhomboids / mid traps',role:'Heavy thickness row',rest:'3–4 min',swaps:['Chest-supported dumbbell row','Plate-loaded chest-supported row','Seal row'],how:'Keep the chest firmly supported. Allow a controlled reach at the bottom, then drive the elbows toward the lower-to-mid ribs and retract the shoulder blades. Pause briefly without hyperextending the shoulder. Keep 1–2 RIR.'},
        {original:'Single-arm cable lat row — elbow to hip',name:'Single-arm cable lat row — elbow to hip',sets:3,reps:'8–12',region:'Lower lats',role:'Lat-biased row',rest:'90–150 sec',swaps:['Half-kneeling cable lat row','1-arm machine lat row','1-arm dumbbell row — lat bias'],how:'Reach forward to lengthen the lat, then pull the elbow down and back toward the hip. Keep the shoulder away from the ear and avoid torso rotation. Think shoulder extension rather than squeezing the shoulder blades together.'},
        {original:'Wide high row',name:'Chest-supported high row — elbows ~45°',sets:3,reps:'8–12',region:'Upper back / rhomboids',role:'Upper-back row',rest:'2–3 min',swaps:['Wide-grip machine row','High cable row','Chest-supported wide dumbbell row'],how:'Keep the chest supported and use an elbow path around 45° from the torso rather than flaring to 90°. Pull toward the upper ribs. This loads rhomboids and traps heavily while the posterior delt remains an indirect contributor rather than the target.'},
        {original:'Straight-arm cable pulldown',name:'Cable pullover / straight-arm pulldown',sets:3,reps:'10–15',region:'Lats',role:'Long-ROM lat isolation',rest:'75–120 sec',swaps:['Machine pullover','Rope straight-arm pulldown','Dumbbell pullover'],how:'Start with the arms overhead and ribs controlled. Let the lats lengthen, then sweep the upper arms toward the thighs with only a soft elbow bend. Do not turn it into a triceps pressdown. Use a controlled stretch and hard finish.'},
        {original:'Dumbbell shrug',name:'Smith or dumbbell shrug',sets:3,reps:'8–12',region:'Upper traps',role:'Heavy trap work',rest:'2–3 min',swaps:['Machine shrug','Trap-bar shrug','Cable shrug'],how:'Let the shoulders settle at the bottom, then elevate them straight upward and slightly back only as your anatomy allows. Pause at the top. Do not roll the shoulders in circles. Use straps if grip would otherwise limit trap loading.'},
        {original:'Cable Y-raise',name:'Cable Y-raise / trap-3 raise',sets:2,reps:'12–15',region:'Lower traps',role:'Lower-trap scapular control',rest:'60–90 sec',swaps:['Prone incline Y-raise','Trap-3 raise'],how:'Use light resistance and raise the arms into a Y while keeping ribs down. Focus on controlled scapular upward rotation and posterior tilt rather than shrugging the load. This is precision work, not a max-load exercise.'},
        {original:'Reverse pec deck',name:'Chest-supported Kelso shrug / scapular row',sets:3,reps:'12–20',region:'Mid traps / rhomboids',role:'Direct scapular retraction',rest:'75–120 sec',swaps:['Chest-supported scapular row','Cable scapular retraction','Prone bench shrug'],how:'Use a chest-supported row setup but keep the elbows nearly straight. Let the shoulder blades protract, then retract them hard without turning the movement into an arm row. This directly trains the mid traps and rhomboids while minimizing extra rear-delt isolation.'},
        {original:'Face pull with external rotation',name:'Cable external rotation at 90°',sets:2,reps:'12–20',region:'Rotator cuff external rotators',role:'Infraspinatus / teres minor',rest:'60–90 sec',swaps:['Side-lying dumbbell external rotation','Cable external rotation — elbow at side','Band external rotation'],how:'Use a light load. With the upper arm supported or held around shoulder height, rotate the forearm backward without letting the elbow or shoulder drift. Control both directions. The goal is the external rotators, not another rear-delt exercise.'},
        {original:'Incline dumbbell curl',name:'Bayesian cable curl',sets:3,reps:'8–12',region:'Biceps long head',role:'Lengthened biceps work',rest:'75–120 sec',swaps:['Incline dumbbell curl','Behind-body cable curl'],how:'Stand slightly in front of the cable so the upper arm begins behind the torso. Keep the shoulder stable and curl without driving the elbow forward. Lower into a controlled long-length position. Stop around 1 RIR until the last set.'},
        {original:'Preacher curl',name:'Preacher curl',sets:3,reps:'8–12',region:'Biceps short head',role:'Stable biceps overload',rest:'75–120 sec',swaps:['Machine preacher curl','EZ-bar preacher curl','Spider curl'],how:'Keep the upper arm supported and lower until the elbow is nearly extended without losing tension. Curl without lifting the arm off the pad. Use a controlled eccentric and avoid bouncing out of the bottom.'},
        {original:'Hammer curl',name:'Hammer curl',sets:3,reps:'10–15',region:'Brachialis / brachioradialis',role:'Neutral-grip elbow flexion',rest:'60–120 sec',swaps:['Rope hammer curl','Cross-body hammer curl'],how:'Keep a neutral thumb-up grip and the elbows close to the body. Curl without torso swing, then lower fully. This is your direct brachialis and brachioradialis volume.'},
        {original:'Reverse EZ-bar curl',name:'Reverse EZ-bar curl',sets:2,reps:'10–15',region:'Brachioradialis / forearm extensors',role:'Forearm accessory',rest:'60–90 sec',swaps:['Cable reverse curl','Dumbbell reverse curl'],how:'Use an overhand grip with neutral wrists. Keep the elbows fixed and use less weight than a regular curl. Control the lowering phase and do not let the wrists collapse.'},
        {original:'Farmer carry',name:'Heavy farmer carry',sets:2,reps:'30–45 sec',region:'Grip / forearm flexors',role:'Grip finisher',rest:'90–180 sec',swaps:['Heavy static dumbbell hold','Dead hang','Trap-bar carry'],how:'Use a load that challenges the grip while posture stays tall. Keep ribs stacked and shoulders controlled. Walk slowly without leaning side to side. If grip fails before posture, that is the intended limiter.'}
      ]
    }
  };

  const REGION_REMAP={
    'Mid chest':'Mid / sternal chest',
    'Upper chest':'Upper / clavicular chest',
    'Lat width':'Lats / teres major',
    'Mid back':'Mid back / rhomboids / mid traps',
    'Upper back':'Upper back / rhomboids',
    'Rear delts':'Mid traps / rhomboids',
    'Rotator cuff / rear delt':'Rotator cuff external rotators',
    'Biceps long head':'Biceps long head',
    'Biceps short head':'Biceps short head',
    'Forearms / brachioradialis':'Brachioradialis / forearm extensors',
    'Grip / forearms':'Grip / forearm flexors'
  };

  function esc(v){return String(v??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;')}
  function selectedChoice(day,idx){
    try{
      const raw=localStorage.getItem(TRAINING_KEY);if(!raw)return'';
      const state=JSON.parse(raw),week=document.getElementById('week')?.value||'0';
      return state?.days?.[`${week}-${day}`]?.choice?.[idx]||'';
    }catch{return''}
  }
  function planForBox(day,box){
    const p=PLAN[day];if(!p)return null;
    const select=box.querySelector('.choice');if(!select)return null;
    const original=box.dataset.hcOriginalId||box.dataset.hcId||select.options?.[0]?.value||select.options?.[0]?.textContent||'';
    if(!box.dataset.hcOriginalId)box.dataset.hcOriginalId=original.trim();
    if(!box.dataset.hcId)box.dataset.hcId=original.trim();
    const idx=p.exercises.findIndex(x=>x.original===box.dataset.hcOriginalId);
    return idx>=0?{item:p.exercises[idx],idx}:null;
  }

  function setOptions(select,item,desired){
    const vals=[item.name,...item.swaps];
    const signature=vals.join('|');
    if(select.dataset.hcPlanSig!==signature){
      select.innerHTML=vals.map(v=>`<option value="${esc(v)}">${esc(v)}</option>`).join('');
      select.dataset.hcPlanSig=signature;
    }
    const next=vals.includes(desired)?desired:item.name;
    if(select.value!==next){
      select.value=next;
      select.dispatchEvent(new Event('change',{bubbles:true}));
    }
  }

  function applyWorkoutPlan(){
    const day=document.getElementById('day')?.value;
    const p=PLAN[day];
    const root=document.getElementById('workout');
    if(!p||!root)return;

    const title=root.querySelector('.dayhead h2');
    const coverage=root.querySelector('.dayhead .coverage');
    if(title&&title.textContent!==p.title)title.textContent=p.title;
    if(coverage&&coverage.textContent!==p.coverage)coverage.textContent=p.coverage;

    const article=root.querySelector('article.card');
    if(article){
      let note=article.querySelector('.hc-push-pull-note');
      if(!note){
        note=document.createElement('div');
        note.className='hc-push-pull-note tiny';
        note.style.cssText='margin-top:7px;padding:8px 10px;border:1px solid var(--border);border-radius:10px;background:var(--panel);line-height:1.45';
        article.querySelector('.dayhead')?.insertAdjacentElement('afterend',note);
      }
      const text=`Aggressive training rule: compounds 1–2 RIR with full rest; isolation work 1 RIR and only the final isolation set at 0–1 RIR when recovery is good. ${p.note}`;
      if(note.textContent!==text)note.textContent=text;
    }

    [...root.querySelectorAll('#exercises .exercise')].forEach(box=>{
      if(box.classList.contains('hc-custom-exercise'))return;
      const found=planForBox(day,box);if(!found)return;
      const {item,idx}=found;
      const select=box.querySelector('.choice');
      const desired=selectedChoice(day,idx);
      setOptions(select,item,desired);

      const meta=box.querySelector('.exmain .tiny');
      const setCount=box.querySelectorAll('.setrow:not(.head)').length||item.sets;
      const metaText=`${item.region} · ${item.role} · ${setCount}×${item.reps}`;
      if(meta&&meta.textContent!==metaText)meta.textContent=metaText;

      const how=box.querySelector('.how');
      if(how){
        const html=`<strong>How to do it</strong><br>${esc(item.how)}<br><span class="tiny"><b>Rest:</b> ${esc(item.rest)} · Keep technique strict; use the RIR target rather than forcing ugly reps.</span>`;
        if(how.innerHTML!==html)how.innerHTML=html;
      }
    });
  }

  function remapVolumeText(){
    document.querySelectorAll('#weekVolume .statline span,#targetVolume .statline span').forEach(span=>{
      const mapped=REGION_REMAP[span.textContent.trim()];
      if(mapped)span.textContent=mapped;
    });
  }

  function addStyles(){
    if(document.getElementById('hcPushPullV2Style'))return;
    const s=document.createElement('style');
    s.id='hcPushPullV2Style';
    s.textContent='.hc-push-pull-note{color:var(--muted)}';
    document.head.appendChild(s);
  }

  let timer=null;
  function schedule(ms=0){clearTimeout(timer);timer=setTimeout(()=>{addStyles();applyWorkoutPlan();remapVolumeText()},ms)}

  function start(){
    schedule(0);
    const root=document.getElementById('workout');
    if(root)new MutationObserver(()=>schedule(10)).observe(root,{childList:true,subtree:true});
    const vol=document.getElementById('targetVolume');
    if(vol)new MutationObserver(()=>schedule(10)).observe(vol,{childList:true,subtree:true});
    const wk=document.getElementById('weekVolume');
    if(wk)new MutationObserver(()=>schedule(10)).observe(wk,{childList:true,subtree:true});
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day')schedule(25)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.tab,.weekBtn,.howbtn'))schedule(40)},true);
    console.info('Hybrid Coach refined push/pull plan loaded',VERSION);
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(start,50),{once:true});
  else setTimeout(start,50);
})();
