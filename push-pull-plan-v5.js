(()=>{
  if(window.__hybridCoachPushPullV5)return;
  window.__hybridCoachPushPullV5=true;

  const VERSION='2026-10-27-v5-whoop-optimized';
  const TRAINING_KEY='hybridCoachData_v1';

  const PLAN={
    Mon:{
      title:'Push — WHOOP Backbone + Complete Chest / 3 Delts / Triceps',
      coverage:'Mid chest · upper chest · chest adduction · anterior delt · lateral delt (2 stimuli) · posterior delt · triceps long / lateral / medial heads · serratus anterior',
      note:'WHOOP-style heavy pressing stays the backbone, but redundant slots are replaced with complementary work. Chest gets flat + incline + fly; lateral delts get two different resistance profiles; rear delts get a dedicated reverse-fly slot; triceps get a heavy press + skull crusher + pressdown.',
      exercises:[
        {original:'Flat barbell bench press',name:'Bench Press — Barbell',reps:'4–8',region:'Mid / sternal chest',role:'Primary heavy strength press',rest:'3–5 min',swaps:['Smith Machine Bench Press','Dumbbell Bench Press','Machine Chest Press'],how:'Use this as the first priority lift. Set the shoulder blades down and back, plant the feet, and use a repeatable touch point. Lower under control and press hard. Keep most work sets at about 1–2 RIR so load and technique stay high.'},
        {original:'Incline dumbbell press',name:'Overhead Press — Barbell',reps:'5–8',region:'Anterior delt / triceps',role:'Primary shoulder strength press',rest:'3–4 min',swaps:['Seated Dumbbell Shoulder Press','Machine Shoulder Press','Smith Shoulder Press'],how:'Brace the trunk and keep the ribs stacked instead of leaning backward. Press overhead through a comfortable path and finish with the arms overhead without shrugging excessively. Keep 1–2 RIR on the heavy sets.'},
        {original:'Weighted dip — chest bias',name:'Bench Press — Incline — Dumbbell',reps:'6–10',region:'Upper / clavicular chest',role:'Upper-chest hypertrophy press',rest:'2–3 min',swaps:['Low-Incline Smith Press','Incline Machine Press','Incline Barbell Press'],how:'Use roughly a 20–35 degree incline. Lower the dumbbells under control into a comfortable pec stretch and press up and slightly inward. Keep the upper chest as the target instead of turning the bench too steep.'},
        {original:'Seated dumbbell shoulder press',name:'Machine Chest Fly / Pec Deck',reps:'10–15',region:'Pecs / horizontal adduction',role:'Chest isolation / long-ROM fly',rest:'75–120 sec',swaps:['Cable Chest Fly','Cable Crossover','Single-Arm Cable Fly'],how:'Set the seat so the handles or pads line up around mid-chest. Keep a soft elbow bend, allow the pecs to lengthen without the shoulders rolling forward, then bring the upper arms together by squeezing the chest.'},
        {original:'Chest-supported lateral raise',name:'Behind-Body Cable Lateral Raise',reps:'10–15',region:'Lateral delt',role:'Lengthened lateral-delt stimulus',rest:'60–120 sec',swaps:['Lean-Away Cable Lateral Raise','Single-Arm Cable Lateral Raise','Chest-Supported Lateral Raise'],how:'Stand slightly in front of a low cable so the working arm starts a little behind the torso. Lead with the elbow and raise in the scapular plane. Keep the trap relaxed and control the stretched bottom position.'},
        {original:'Standing lateral raise',name:'Machine Lateral Raise',reps:'12–20',region:'Lateral delt',role:'Stable high-tension lateral-delt stimulus',rest:'60–120 sec',swaps:['Lateral Shoulder Raise — Dumbbell','Cable Lateral Raise','Chest-Supported Lateral Raise'],how:'Use the machine for a stable second lateral-delt stimulus. Drive the upper arm out and up without shrugging. Keep constant tension and push the final set very close to failure when recovery is good.'},
        {original:'Single-arm cable rear-delt fly',name:'Reverse Pec Deck — Rear-Delt Bias',reps:'12–20',region:'Posterior delt',role:'Direct rear-delt isolation',rest:'60–120 sec',swaps:['Machine Shoulder Fly — Rear-Delt Setup','Reverse Fly — Dumbbell','Single-Arm Cable Rear-Delt Fly'],how:'Use the reverse-fly setup. Keep a soft elbow bend and sweep the upper arms outward. Let the posterior delt move the shoulder and avoid turning the exercise into a row with excessive scapular retraction.'},
        {original:'Close-grip bench press',name:'Close-Grip Chest Press — Barbell',reps:'5–8',region:'Triceps / pressing strength',role:'Heavy triceps overload',rest:'2.5–4 min',swaps:['Close-Grip Bench Press','Smith Close-Grip Bench Press','JM Press'],how:'Use a moderately narrow grip that keeps the wrists stacked over the forearms. Lower under control with the elbows tracking naturally and drive hard. Keep 1–2 RIR because this is the heavy triceps movement.'},
        {original:'Overhead cable triceps extension',name:'EZ-Bar Skull Crusher',reps:'8–12',region:'Triceps long head',role:'Lengthened triceps isolation',rest:'90–150 sec',swaps:['Incline Skull Crusher','Dumbbell Skull Crusher','Cable Skull Crusher'],how:'Angle the upper arms slightly back and lower the bar toward or just behind the top of the head. Let the elbows flex deeply, then extend without swinging the shoulders. Use a controlled eccentric and stop if the elbows become irritated.'},
        {original:'Rope pressdown',name:'Triceps Pulldown — Rope',reps:'10–15',region:'Triceps lateral / medial heads',role:'Cable pressdown isolation',rest:'60–120 sec',swaps:['Straight-Bar Pressdown','V-Bar Pressdown','Single-Arm Cable Pressdown'],how:'Pin the upper arms near the torso and move only through the elbows. Extend fully, separate the rope slightly at the bottom, and control the return. The final set can be pushed to 0–1 RIR when form stays clean.'},
        {original:'Push-up plus',name:'Push-Up Plus / Serratus Punch',reps:'12–20',region:'Serratus anterior',role:'Scapular protraction / shoulder support',rest:'60–90 sec',swaps:['Cable Serratus Punch','Serratus Wall Slide'],how:'At the top of the push-up, continue pushing the floor away so the shoulder blades wrap forward around the rib cage. Keep the neck relaxed and do not shrug. The extra scapular protraction is the target.'}
      ]
    },
    Tue:{
      title:'Pull — WHOOP Backbone + Complete Lats / Back / Traps / Arms',
      coverage:'Lat width · lat shoulder extension · teres major · rhomboids · upper traps · mid traps · lower traps · external rotators · biceps long / short regions · brachialis · brachioradialis / forearms · pull-up capacity',
      note:'WHOOP’s wide pulldown, seated row and unilateral row pattern stay. Redundant incline-row and curl slots are converted into missing functions: straight-arm lat work, upper/mid/lower trap work, cuff/scapular work and forearms. Pull-ups stay last as the finisher.',
      exercises:[
        {original:'Weighted pull-up / neutral pulldown',name:'Lat Pulldown — Wide-Grip Front Pull',reps:'6–10',region:'Lats / teres major',role:'Primary vertical pull / lat width',rest:'2.5–4 min',swaps:['Medium-Wide Pronated Lat Pulldown','Wide Neutral-Grip Pulldown','Plate-Loaded Pulldown'],how:'Use a grip wider than shoulder width without going so wide that range of motion collapses. Keep the torso mostly tall, drive the elbows down toward the ribs, and control the full overhead stretch. Never pull behind the neck.'},
        {original:'Chest-supported T-bar row',name:'Seated Row',reps:'6–10',region:'Mid back / rhomboids / mid traps',role:'Primary horizontal pull',rest:'2.5–4 min',swaps:['Seated Cable Row','Seated Plate-Loaded Row','Chest-Supported T-Bar Row'],how:'Allow the shoulder blades to reach forward under control, then drive the elbows back and retract the scapulae. Pull toward the lower-to-mid ribs without excessive torso rocking. Keep the last hard reps strict.'},
        {original:'Single-arm cable lat row — elbow to hip',name:'Independent-Arm Plate-Loaded Row — Right / Left',reps:'8–12 each',region:'Lats / mid back',role:'Unilateral row / side-to-side balance',rest:'90–150 sec',swaps:['Incline Row — Machine','Iso-Lateral Row Machine','Single-Arm Dumbbell Row on Flat Bench'],how:'Use the machine with independently moving right and left arms when available. Reach forward to lengthen the back, then drive one elbow back without rotating the torso. Match reps and effort side to side.'},
        {original:'Wide high row',name:'Chest-Supported High Row — Elbows ~45°',reps:'8–12',region:'Upper back / rhomboids',role:'Upper-back thickness',rest:'2–3 min',swaps:['Incline Row — Dumbbell','Wide-Grip Machine Row','High Cable Row'],how:'Keep the chest supported and use an elbow path around 45 degrees from the torso. Pull toward the upper ribs. This complements the seated row by biasing the upper-back fibers rather than repeating the same low-row path.'},
        {original:'Straight-arm cable pulldown',name:'Straight-Arm Cable Pulldown / Pullover',reps:'10–15',region:'Lats',role:'Shoulder-extension lat isolation',rest:'75–120 sec',swaps:['Machine Pullover','Rope Straight-Arm Pulldown','Dumbbell Pullover'],how:'Start with the arms overhead and ribs controlled. Let the lats lengthen, then sweep the upper arms toward the thighs with only a soft elbow bend. Do not turn it into a triceps pressdown.'},
        {original:'Dumbbell shrug',name:'Smith or Dumbbell Shrug',reps:'8–12',region:'Upper traps',role:'Heavy upper-trap work',rest:'2–3 min',swaps:['Machine Shrug','Trap-Bar Shrug','Cable Shrug'],how:'Let the shoulders settle at the bottom, then elevate them upward through a comfortable range. Pause briefly at the top and avoid rolling the shoulders in circles. Use straps if grip limits trap loading.'},
        {original:'Cable Y-raise',name:'Cable Y-Raise / Trap-3 Raise',reps:'12–15',region:'Lower traps',role:'Lower-trap control',rest:'60–90 sec',swaps:['Prone Incline Y-Raise','Trap-3 Raise'],how:'Use a light load and raise the arms into a Y while keeping the ribs down. Focus on scapular upward rotation and posterior tilt rather than shrugging. This is precision work, not a heavy lift.'},
        {original:'Reverse pec deck',name:'Chest-Supported Kelso Shrug / Scapular Row',reps:'12–20',region:'Mid traps / rhomboids',role:'Direct scapular retraction',rest:'75–120 sec',swaps:['Chest-Supported Scapular Row','Cable Scapular Retraction','Prone Bench Shrug'],how:'Use a chest-supported row setup but keep the elbows nearly straight. Let the shoulder blades protract, then retract them hard without turning it into an arm row. This directly fills the mid-trap/rhomboid gap.'},
        {original:'Face pull with external rotation',name:'Cable Face Pull + External Rotation',reps:'12–20',region:'External rotators / scapular stabilizers',role:'Cuff + shoulder-balance work',rest:'60–90 sec',swaps:['Cable External Rotation at 90°','High Rope Face Pull','Band External Rotation'],how:'Pull the rope toward the face or forehead while rotating the hands apart. Keep the shoulders away from the ears and control the return. Rear delts contribute, but the goal here is cuff and scapular function rather than another rear-delt isolation slot.'},
        {original:'Incline dumbbell curl',name:'Bayesian Cable Curl',reps:'8–12',region:'Biceps',role:'Lengthened biceps stimulus',rest:'75–120 sec',swaps:['Incline Dumbbell Curl','Behind-Body Cable Curl'],how:'Stand slightly in front of the cable so the upper arm begins behind the torso. Keep the shoulder stable and curl without driving the elbow forward. Control the long bottom position.'},
        {original:'Preacher curl',name:'Preacher Curl',reps:'8–12',region:'Biceps',role:'Stable shortened-to-midrange overload',rest:'75–120 sec',swaps:['Machine Preacher Curl','EZ-Bar Preacher Curl','Spider Curl'],how:'Keep the upper arm planted on the pad and lower until the elbow is nearly extended without losing tension. Curl without lifting the arm off the support and avoid bouncing out of the bottom.'},
        {original:'Hammer curl',name:'Hammer Curl — Dumbbell',reps:'10–15',region:'Brachialis / brachioradialis',role:'Neutral-grip elbow flexion',rest:'60–120 sec',swaps:['Rope Hammer Curl','Cross-Body Hammer Curl'],how:'Keep a neutral thumb-up grip and the elbows close to the body. Curl without torso swing and lower fully. This is the direct brachialis/brachioradialis slot.'},
        {original:'Reverse EZ-bar curl',name:'Reverse EZ-Bar Curl',reps:'10–15',region:'Brachioradialis / forearm extensors',role:'Forearm coverage',rest:'60–90 sec',swaps:['Cable Reverse Curl','Dumbbell Reverse Curl'],how:'Use an overhand grip with neutral wrists. Keep the elbows fixed and use less weight than a normal curl. Control the lowering phase and do not let the wrists collapse.'},
        {original:'Farmer carry',name:'Pull-Up Finisher',reps:'AMRAP clean',region:'Lats / biceps / upper back',role:'Final bodyweight vertical pull',rest:'2–3 min',swaps:['Neutral-Grip Pull-Up Finisher','Assisted Pull-Up Finisher','Chin-Up Finisher'],how:'Do these last, as requested. Start from a full hang and perform only clean reps. Stop when another technically good rep is unlikely. If fatigue reduces bodyweight reps too far, use assistance and keep the range full.'}
      ]
    }
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
    const original=(box.dataset.hcOriginalId||box.dataset.hcId||select.options?.[0]?.value||select.options?.[0]?.textContent||'').trim();
    if(!box.dataset.hcOriginalId)box.dataset.hcOriginalId=original;
    if(!box.dataset.hcId)box.dataset.hcId=original;
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
    if(select.value!==next){select.value=next;select.dispatchEvent(new Event('change',{bubbles:true}))}
  }
  function applyWorkoutPlan(){
    const day=document.getElementById('day')?.value,p=PLAN[day],root=document.getElementById('workout');
    if(!p||!root)return;
    const title=root.querySelector('.dayhead h2'),coverage=root.querySelector('.dayhead .coverage');
    if(title&&title.textContent!==p.title)title.textContent=p.title;
    if(coverage&&coverage.textContent!==p.coverage)coverage.textContent=p.coverage;
    const article=root.querySelector('article.card');
    if(article){
      let note=article.querySelector('.hc-push-pull-note');
      if(!note){note=document.createElement('div');note.className='hc-push-pull-note tiny';note.style.cssText='margin-top:7px;padding:8px 10px;border:1px solid var(--border);border-radius:10px;background:var(--panel);line-height:1.45;color:var(--muted)';article.querySelector('.dayhead')?.insertAdjacentElement('afterend',note)}
      const text=`Coach-optimized WHOOP plan: ${p.note} Heavy compounds stay mostly 1–2 RIR with full rest. Isolation work is usually 1 RIR; only the final safe isolation set should reach 0–1 RIR when recovery is good.`;
      if(note.textContent!==text)note.textContent=text;
    }
    [...root.querySelectorAll('#exercises .exercise')].forEach(box=>{
      if(box.classList.contains('hc-custom-exercise'))return;
      const found=planForBox(day,box);if(!found)return;
      const {item,idx}=found,select=box.querySelector('.choice');
      setOptions(select,item,selectedChoice(day,idx));
      const meta=box.querySelector('.exmain .tiny'),setCount=box.querySelectorAll('.setrow:not(.head)').length;
      const metaText=`${item.region} · ${item.role} · ${setCount||'?'}×${item.reps}`;
      if(meta&&meta.textContent!==metaText)meta.textContent=metaText;
      const how=box.querySelector('.how');
      if(how){const html=`<strong>How to do it</strong><br>${esc(item.how)}<br><span class="tiny"><b>Rest:</b> ${esc(item.rest)}</span>`;if(how.innerHTML!==html)how.innerHTML=html}
    });
  }
  let timer=null;
  function schedule(ms=0){clearTimeout(timer);timer=setTimeout(applyWorkoutPlan,ms)}
  function start(){
    schedule(0);
    const root=document.getElementById('workout');if(root)new MutationObserver(()=>schedule(15)).observe(root,{childList:true,subtree:true});
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day')schedule(30)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.tab,.weekBtn,.howbtn'))schedule(45)},true);
    console.info('Hybrid Coach WHOOP-optimized push/pull plan loaded',VERSION);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(start,50),{once:true});else setTimeout(start,50);
})();
