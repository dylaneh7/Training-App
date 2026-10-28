(()=>{
  if(window.__hybridCoachPushPullV4)return;
  window.__hybridCoachPushPullV4=true;

  const VERSION='2026-10-27-v4-whoop-match';
  const TRAINING_KEY='hybridCoachData_v1';

  const PLAN={
    Mon:{
      title:'Push — WHOOP Style + Complete Chest / Delts / Triceps',
      coverage:'Mid chest · upper chest · chest adduction · anterior delt · lateral delt · posterior delt · triceps long / lateral / medial heads · serratus anterior',
      note:'Built around your typical WHOOP Heavy Upper Push flow. Flat bench, overhead press, incline dumbbell press, machine shoulder fly, close-grip press, chest fly, lateral raise, skull crusher and rope pressdown are the backbone. Serratus and a small extra long-head triceps slot close the remaining gaps.',
      exercises:[
        {original:'Flat barbell bench press',name:'Bench Press — Barbell',reps:'5–8',region:'Mid / sternal chest',role:'Primary heavy press',rest:'3–5 min',swaps:['Smith Machine Bench Press','Dumbbell Bench Press','Machine Chest Press'],how:'Set the shoulder blades down and back, plant the feet, and use the same touch point every rep. Lower under control and press hard without letting the shoulders roll forward. Keep most work sets around 1–2 RIR.'},
        {original:'Incline dumbbell press',name:'Overhead Press — Barbell',reps:'5–8',region:'Anterior delt / triceps',role:'Primary shoulder press',rest:'2.5–4 min',swaps:['Seated Dumbbell Shoulder Press','Machine Shoulder Press','Smith Shoulder Press'],how:'Brace the trunk and keep the ribs stacked rather than leaning back into a standing incline press. Press the bar overhead through a comfortable path and finish with the biceps near the ears. Keep 1–2 RIR on the heavy sets.'},
        {original:'Weighted dip — chest bias',name:'Bench Press — Incline — Dumbbell',reps:'6–10',region:'Upper / clavicular chest',role:'Must-do upper-chest press',rest:'2–3 min',swaps:['Low-Incline Smith Press','Incline Machine Press','Incline Barbell Press'],how:'Use a low-to-moderate incline, roughly 20–35 degrees. Lower the dumbbells under control into a deep but comfortable pec stretch, then press up and slightly inward. Do not turn it into a near-vertical shoulder press.'},
        {original:'Seated dumbbell shoulder press',name:'Machine Shoulder Fly — Rear-Delt Bias',reps:'10–15',region:'Posterior delt',role:'Direct rear-delt work',rest:'60–120 sec',swaps:['Reverse Pec Deck','Reverse Fly — Dumbbell','Single-Arm Cable Rear-Delt Fly'],how:'Use the machine in the reverse-fly/rear-delt setup. Keep a soft elbow bend and sweep the upper arms outward. Avoid turning the movement into a row by over-pulling the shoulder blades together.'},
        {original:'Chest-supported lateral raise',name:'Close-Grip Chest Press — Barbell',reps:'6–10',region:'Triceps / pressing strength',role:'Heavy triceps press',rest:'2.5–4 min',swaps:['Close-Grip Bench Press','Smith Close-Grip Bench Press','JM Press'],how:'Use a moderately narrow grip that keeps the wrists stacked over the forearms. Lower under control with the elbows tracking naturally and drive hard. This is the heavy triceps slot, so keep a rep or two in reserve rather than grinding.'},
        {original:'Standing lateral raise',name:'Machine Chest Fly / Pec Deck',reps:'10–15',region:'Pecs / horizontal adduction',role:'Chest isolation',rest:'75–120 sec',swaps:['Cable Chest Fly','Cable Crossover','Single-Arm Cable Fly'],how:'Set the seat so the handles or pads line up around mid-chest. Keep a slight elbow bend, allow a controlled stretch, then bring the upper arms together by squeezing the pecs. Do not shorten the range just to move more weight.'},
        {original:'Single-arm cable rear-delt fly',name:'Lateral Shoulder Raise — Dumbbell',reps:'10–15',region:'Lateral delt',role:'Direct middle-delt work',rest:'60–120 sec',swaps:['Cable Lateral Raise','Machine Lateral Raise','Behind-Body Cable Lateral Raise'],how:'Lead with the elbows and raise the arms in the scapular plane to around shoulder height. Keep the neck relaxed and do not shrug the weight upward. Use strict reps; the final set may reach about 0–1 RIR when recovery is good.'},
        {original:'Close-grip bench press',name:'EZ-Bar Skull Crusher',reps:'8–12',region:'Triceps long head',role:'Lengthened elbow extension',rest:'90–150 sec',swaps:['Incline Skull Crusher','Dumbbell Skull Crusher','Cable Skull Crusher'],how:'Keep the upper arms angled slightly back and lower the implement toward or just behind the top of the head. Let the elbows flex deeply, then extend without letting the shoulders swing. Stop or swap if the elbows become irritated.'},
        {original:'Overhead cable triceps extension',name:'Triceps Pulldown — Rope',reps:'10–15',region:'Triceps lateral / medial heads',role:'Primary cable pressdown',rest:'60–120 sec',swaps:['Straight-Bar Pressdown','V-Bar Pressdown','Single-Arm Cable Pressdown'],how:'Pin the upper arms close to the torso and move only through the elbows. Extend fully, separate the rope slightly at the bottom, and control the return. Push the last set hard with clean form.'},
        {original:'Rope pressdown',name:'Single-Arm Overhead Cable Triceps Extension',reps:'12–15',region:'Triceps long head',role:'Coverage add-on',rest:'60–90 sec',swaps:['Overhead Rope Extension','Standing Dumbbell Triceps Extension','Single-Arm Cross-Body Extension'],how:'Keep the upper arm pointed forward or slightly upward and allow a deep elbow bend. This gives the long head another lengthened-position exposure without needing another heavy press. Keep it controlled and close to failure.'},
        {original:'Push-up plus',name:'Push-Up Plus / Serratus Punch',reps:'12–20',region:'Serratus anterior',role:'Coverage add-on',rest:'60–90 sec',swaps:['Cable Serratus Punch','Serratus Wall Slide'],how:'At the top of the push-up, continue pushing the floor away so the shoulder blades wrap forward around the rib cage. Keep the neck relaxed and do not shrug. The extra protraction is the point of the movement.'}
      ]
    },
    Tue:{
      title:'Pull — WHOOP Style + Complete Back / Biceps + Pull-Up Finish',
      coverage:'Lats · teres major · rhomboids · upper / mid / lower traps · posterior delts · external rotators · biceps · brachialis · brachioradialis · pull-up capacity',
      note:'Built around your typical WHOOP Pull 90 workout: wide-grip pulldown, seated row, incline machine row, incline dumbbell row, left/right single-arm rows, reverse fly, face pulls and four curl patterns. Trap-3 raises and pull-ups are the only coach-added coverage pieces.',
      exercises:[
        {original:'Weighted pull-up / neutral pulldown',name:'Lat Pulldown — Wide-Grip Front Pull',reps:'6–10',region:'Lats / teres major',role:'Primary vertical pull',rest:'2.5–4 min',swaps:['Medium-Wide Pronated Lat Pulldown','Wide Neutral-Grip Pulldown','Plate-Loaded Pulldown'],how:'Use a grip wider than shoulder width without going so wide that the range becomes tiny. Keep the torso tall with a slight lean and drive the elbows down toward the ribs. Control the full overhead stretch; never pull behind the neck.'},
        {original:'Chest-supported T-bar row',name:'Seated Row',reps:'6–10',region:'Mid back / rhomboids / mid traps',role:'Primary horizontal pull',rest:'2.5–4 min',swaps:['Seated Cable Row','Seated Plate-Loaded Row','Chest-Supported T-Bar Row'],how:'Let the shoulder blades reach forward under control, then drive the elbows back and retract the scapulae. Pull toward the lower-to-mid ribs without excessive torso rocking. Keep the hard reps strict.'},
        {original:'Single-arm cable lat row — elbow to hip',name:'Incline Row — Machine',reps:'8–12',region:'Lats / mid back',role:'Stable heavy row',rest:'90–150 sec',swaps:['Chest-Supported Machine Row','Iso-Lateral Incline Row','Plate-Loaded High Row'],how:'Keep the chest supported and allow a controlled reach at the bottom. Pull the elbows back through a full range without lifting the torso away from the pad. Use a neutral-to-moderate elbow path to share load between lats and mid back.'},
        {original:'Wide high row',name:'Incline Row — Dumbbell',reps:'8–12',region:'Upper / mid back',role:'Free-weight supported row',rest:'90–150 sec',swaps:['Chest-Supported Dumbbell Row','Prone Incline Dumbbell Row','Seal Row'],how:'Lie chest-down on the incline bench and row the dumbbells toward the lower-to-mid ribs. Let the shoulder blades protract at the bottom and retract at the top. Avoid turning it into a shrug or bouncing the chest off the bench.'},
        {original:'Straight-arm cable pulldown',name:'Row — Single Arm L — Dumbbell',reps:'8–12',region:'Left lat / mid back',role:'Unilateral row',rest:'60–120 sec',swaps:['Single-Arm Machine Row — Left','Bench-Supported Dumbbell Row — Left'],how:'Support the body on a flat bench, reach long at the bottom, then drive the left elbow back toward the hip or lower ribs. Keep the torso square and avoid twisting to finish the rep.'},
        {original:'Dumbbell shrug',name:'Row — Single Arm R — Dumbbell',reps:'8–12',region:'Right lat / mid back',role:'Unilateral row',rest:'60–120 sec',swaps:['Single-Arm Machine Row — Right','Bench-Supported Dumbbell Row — Right'],how:'Mirror the left side exactly. Reach long at the bottom, then drive the right elbow back while keeping the torso square. Match the weaker side for reps and load rather than letting the stronger side do extra.'},
        {original:'Cable Y-raise',name:'Reverse Fly — Dumbbell',reps:'12–20',region:'Posterior delts / upper back',role:'Rear-delt isolation',rest:'60–90 sec',swaps:['Reverse Pec Deck','Chest-Supported Rear-Delt Raise','Cable Rear-Delt Fly'],how:'Use light-to-moderate weight and sweep the arms outward with a soft elbow bend. Keep the movement at the shoulder instead of turning it into a row. Control the lowering phase.'},
        {original:'Reverse pec deck',name:'Cable Face Pulls',reps:'12–20',region:'Rear delts / external rotators / mid-lower traps',role:'Scapular + cuff work',rest:'60–90 sec',swaps:['Rope Face Pull With External Rotation','High Cable Face Pull'],how:'Pull the rope toward the face or forehead while rotating the hands apart. Keep the shoulders away from the ears and finish with the elbows high enough to involve the external rotators and mid/lower traps.'},
        {original:'Face pull with external rotation',name:'Preacher Curl',reps:'8–12',region:'Biceps',role:'Stable elbow flexion',rest:'75–120 sec',swaps:['Machine Preacher Curl','EZ-Bar Preacher Curl','Spider Curl'],how:'Keep the upper arm planted on the pad and lower until the elbow is nearly extended without losing tension. Curl without lifting the arm off the support and avoid bouncing out of the bottom.'},
        {original:'Incline dumbbell curl',name:'Bicep Curl — Cable',reps:'10–15',region:'Biceps',role:'Constant-tension curl',rest:'60–120 sec',swaps:['Bayesian Cable Curl','Straight-Bar Cable Curl','Single-Arm Cable Curl'],how:'Keep the shoulder stable and curl through a full range without drifting the elbow forward. Use the cable to keep tension through the movement and control the eccentric.'},
        {original:'Preacher curl',name:'Bicep Curl — Dumbbell',reps:'8–12',region:'Biceps',role:'Free-weight curl',rest:'60–120 sec',swaps:['Alternating Dumbbell Curl','Incline Dumbbell Curl','Supinating Dumbbell Curl'],how:'Start with the elbows near the sides and supinate as you curl. Do not swing the torso. Lower completely under control before starting the next rep.'},
        {original:'Hammer curl',name:'Hammer Curl — Dumbbell',reps:'10–15',region:'Brachialis / brachioradialis',role:'Neutral-grip elbow flexion',rest:'60–120 sec',swaps:['Rope Hammer Curl','Cross-Body Hammer Curl'],how:'Keep a neutral thumb-up grip and curl without swinging. This is the arm slot that directly covers brachialis and brachioradialis, so keep the grip neutral through the entire rep.'},
        {original:'Reverse EZ-bar curl',name:'Cable Y-Raise / Trap-3 Raise',reps:'12–15',region:'Lower traps',role:'Coverage add-on',rest:'60–90 sec',swaps:['Prone Incline Y-Raise','Trap-3 Raise'],how:'Use a light load and raise the arms into a Y while keeping the ribs down. Focus on controlled scapular upward rotation and posterior tilt rather than shrugging the shoulders. This is precision work, not a max-load movement.'},
        {original:'Farmer carry',name:'Pull-Up Finisher',reps:'AMRAP clean',region:'Lats / biceps / upper back',role:'Final bodyweight pull',rest:'2–3 min',swaps:['Neutral-Grip Pull-Up Finisher','Assisted Pull-Up Finisher','Chin-Up Finisher'],how:'Do these last. Start from a full hang and use clean reps only. Stop when another technically good rep is unlikely rather than kicking or shortening the range. If bodyweight reps are too low after the session, use assistance.'}
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
    if(select.value!==next){
      select.value=next;
      select.dispatchEvent(new Event('change',{bubbles:true}));
    }
  }

  function applyWorkoutPlan(){
    const day=document.getElementById('day')?.value;
    const p=PLAN[day],root=document.getElementById('workout');
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
        note.style.cssText='margin-top:7px;padding:8px 10px;border:1px solid var(--border);border-radius:10px;background:var(--panel);line-height:1.45;color:var(--muted)';
        article.querySelector('.dayhead')?.insertAdjacentElement('afterend',note);
      }
      const text=`WHOOP-match plan: ${p.note} Heavy compounds: mostly 1–2 RIR. Isolation work: usually 1 RIR, with the final safe isolation set allowed to reach 0–1 RIR when recovery is good.`;
      if(note.textContent!==text)note.textContent=text;
    }

    [...root.querySelectorAll('#exercises .exercise')].forEach(box=>{
      if(box.classList.contains('hc-custom-exercise'))return;
      const found=planForBox(day,box);if(!found)return;
      const {item,idx}=found,select=box.querySelector('.choice');
      setOptions(select,item,selectedChoice(day,idx));

      const meta=box.querySelector('.exmain .tiny');
      const setCount=box.querySelectorAll('.setrow:not(.head)').length;
      const metaText=`${item.region} · ${item.role} · ${setCount||'?'}×${item.reps}`;
      if(meta&&meta.textContent!==metaText)meta.textContent=metaText;

      const how=box.querySelector('.how');
      if(how){
        const html=`<strong>How to do it</strong><br>${esc(item.how)}<br><span class="tiny"><b>Rest:</b> ${esc(item.rest)}</span>`;
        if(how.innerHTML!==html)how.innerHTML=html;
      }
    });
  }

  let timer=null;
  function schedule(ms=0){clearTimeout(timer);timer=setTimeout(applyWorkoutPlan,ms)}

  function start(){
    schedule(0);
    const root=document.getElementById('workout');
    if(root)new MutationObserver(()=>schedule(15)).observe(root,{childList:true,subtree:true});
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day')schedule(30)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.tab,.weekBtn,.howbtn'))schedule(45)},true);
    console.info('Hybrid Coach WHOOP-matched push/pull plan loaded',VERSION);
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(start,50),{once:true});
  else setTimeout(start,50);
})();
