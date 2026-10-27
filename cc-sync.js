(()=>{
  const SUPABASE_URL='https://ecmosmmqloyahsdcxvpz.supabase.co';
  const SUPABASE_KEY='sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ';
  const BASE_DATE='2026-10-26';
  const AUTH_STORAGE_KEY='hybrid-coach-command-center-auth';
  const TRAINING_STORAGE_KEY='hybridCoachData_v1';
  const RUN_PLAN=[
    {Mon:['Tempo Progression — 2 × 10 Min','12 min easy warm-up, 2 × 10 min controlled tempo with 3 min easy between, then cool down.'],Tue:['Recovery Run — 30 Min','Very easy recovery effort. Keep the legs moving without adding fatigue.'],Wed:['Long Run — 8.5 Miles Easy','Keep the entire run conversational and mostly easy; practice fluids/fueling.']},
    {Mon:['Tempo — 3 × 8 Min','12 min easy warm-up, 3 × 8 min tempo with 3 min easy between, then cool down.'],Tue:['Recovery Run — 30 Min','Very easy recovery effort.'],Wed:['Long Run — 9 Miles Easy','Conversational long run; practice fluids/fueling.']},
    {Mon:['Threshold — 6 × 3 Min','Controlled threshold intervals with easy recovery between reps.'],Tue:['Recovery Run — 35 Min','Easy recovery only.'],Wed:['Long Run — 9.5 Miles Easy','Conversational long run.']},
    {Mon:['Steady Run — 20 Min','Short controlled steady effort; this is a cutback week.'],Tue:['Recovery Run — 30 Min','Very easy recovery effort.'],Wed:['Long Run — 8 Miles Easy','Cutback long run; relaxed throughout.']},
    {Mon:['Tempo — 2 × 15 Min','Two controlled 15-minute tempo blocks with easy recovery.'],Tue:['Recovery Run — 35 Min','Very easy recovery effort.'],Wed:['Long Run — 10 Miles Easy','Conversational long run; practice fueling.']},
    {Mon:['Threshold — 4 × 8 Min','Four controlled threshold blocks with easy recovery.'],Tue:['Recovery Run — 35 Min','Very easy recovery effort.'],Wed:['Long Run — 10.5 Miles Easy','Conversational long run.']},
    {Mon:['Tempo — 3 × 10 Min','Three controlled tempo blocks with easy recovery.'],Tue:['Recovery Run — 35 Min','Very easy recovery effort.'],Wed:['Long Run — 11 Miles Easy','Conversational long run; practice fueling.']},
    {Mon:['Brisk Intervals — 8 × 2 Min','Eight short brisk reps with easy recovery; cutback volume.'],Tue:['Recovery Run — 30 Min','Very easy recovery effort.'],Wed:['Long Run — 9 Miles Easy','Cutback long run.']},
    {Mon:['Tempo — 2 × 15 + 10 Min','15 min tempo, easy recovery, 15 min tempo, easy recovery, then 10 min tempo.'],Tue:['Recovery Run — 35 Min','Very easy recovery effort.'],Wed:['Long Run — 11.5 Miles Easy','Peak-build long run; practice race fueling.']},
    {Mon:['Threshold — 3 × 10 Min','Three controlled threshold blocks with easy recovery.'],Tue:['Recovery Run — 35 Min','Very easy recovery effort.'],Wed:['Long Run — 12 Miles Easy','Peak long run; stay conversational and practice race fueling.']},
    {Mon:['Tempo — 2 × 8 Min','Short taper tempo session; keep it controlled.'],Tue:['Recovery Run — 30 Min','Very easy recovery effort.'],Wed:['Long Run — 8 Miles Easy','Taper long run; relaxed.']},
    {Mon:['Race Effort — 3 × 5 Min','Three short race-effort reps with plenty of easy running around them.'],Tue:['Shakeout Run — 20 Min','Very easy shakeout.'],Wed:['Easy Run — 25 Min','Short easy run during race week.']}
  ];

  let sb=null,user=null,pendingCompletion=null,plannerChannel=null,applyingRemote=false;

  function addStyles(){
    if(document.getElementById('ccSyncStyles')) return;
    const style=document.createElement('style');
    style.id='ccSyncStyles';
    style.textContent=`.cc-sync-pill{border:1px solid var(--border);border-radius:999px;padding:7px 10px;font-size:12px;color:var(--muted);background:var(--panel);min-height:38px}.cc-sync-pill.connected{color:var(--ok);border-color:#3b7152;background:#13291c}.cc-sync-pill.error{color:var(--bad);border-color:#7d4141;background:#301818}.cc-sync-dialog{border:1px solid var(--border);border-radius:18px;background:var(--card);color:var(--text);width:min(440px,calc(100% - 24px));padding:0;box-shadow:0 30px 90px rgba(0,0,0,.45)}.cc-sync-dialog::backdrop{background:rgba(0,0,0,.68);backdrop-filter:blur(4px)}.cc-sync-dialog form{padding:18px}.cc-sync-dialog h2{margin:0 0 6px}.cc-sync-dialog p{margin:0 0 14px;color:var(--muted);font-size:12px;line-height:1.5}.cc-sync-actions{display:flex;gap:8px;justify-content:flex-end;margin-top:14px}.cc-sync-msg{min-height:18px;margin-top:8px;font-size:12px;color:var(--muted)}.cc-strength-only{opacity:.64}.cc-strength-only .checkline{opacity:.55}`;
    document.head.appendChild(style);
  }

  function addUI(){
    addStyles();
    if(document.getElementById('ccSyncBtn')) return;
    const top=document.querySelector('.top .row');if(!top)return;
    const button=document.createElement('button');button.id='ccSyncBtn';button.className='cc-sync-pill';button.type='button';button.textContent='Command Center · Connect';button.addEventListener('click',openConnect);top.prepend(button);
    const dialog=document.createElement('dialog');dialog.id='ccSyncDialog';dialog.className='cc-sync-dialog';dialog.innerHTML=`<form method="dialog" id="ccSyncForm"><h2>Connect Command Center</h2><p>Use the same account as School Command Center. Runs and lifts sync both directions: checking one complete here updates Command Center, and Garmin/Tredict completions flow back here.</p><label>Email<input id="ccEmail" type="email" autocomplete="email" required></label><label style="display:block;margin-top:8px">Password<input id="ccPassword" type="password" autocomplete="current-password" required></label><div id="ccSyncMsg" class="cc-sync-msg"></div><div class="cc-sync-actions"><button type="button" class="btn" id="ccCancel">Cancel</button><button type="submit" class="btn primary">Connect</button></div></form>`;document.body.appendChild(dialog);dialog.querySelector('#ccCancel').addEventListener('click',()=>dialog.close());dialog.querySelector('#ccSyncForm').addEventListener('submit',connectAccount);
  }

  function setStatus(text,kind=''){const b=document.getElementById('ccSyncBtn');if(!b)return;b.textContent=text;b.className='cc-sync-pill'+(kind?' '+kind:'')}
  function loadSdk(){return new Promise((resolve,reject)=>{if(window.supabase?.createClient)return resolve();const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';s.onload=resolve;s.onerror=()=>reject(new Error('Could not load cloud sync'));document.head.appendChild(s)})}
  function workoutDate(weekIndex,dayName){const offsets={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6};const d=new Date(`${BASE_DATE}T12:00:00`);d.setDate(d.getDate()+Number(weekIndex)*7+(offsets[dayName]??0));return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`}
  function canonicalRun(weekIndex,dayName){return RUN_PLAN[Number(weekIndex)]?.[dayName]||null}
  function canonicalRunCount(){let raw;try{raw=JSON.parse(localStorage.getItem(TRAINING_STORAGE_KEY)||'null')}catch{return 0}let n=0;for(const [key,value] of Object.entries(raw?.days||{})){const dayName=key.split('-')[1];if(['Mon','Tue','Wed'].includes(dayName)&&value?.runDone)n++}return n}

  function applyCanonicalRunUI(){
    const weekEl=document.getElementById('week'),dayEl=document.getElementById('day'),runDone=document.getElementById('runDone');if(!weekEl||!dayEl||!runDone)return;
    const section=runDone.closest('section');if(!section)return;const title=[...section.querySelectorAll(':scope > strong')][0]||section.querySelector('strong');const guide=section.querySelector('p.tiny');const plan=canonicalRun(weekEl.value,dayEl.value);section.classList.toggle('cc-strength-only',!plan);runDone.disabled=!plan;
    if(plan){if(title&&title.textContent!==plan[0])title.textContent=plan[0];if(guide&&guide.textContent!==plan[1])guide.textContent=plan[1]}else{if(title&&title.textContent!=='No run planned')title.textContent='No run planned';if(guide&&guide.textContent!=='Strength only today.')guide.textContent='Strength only today.'}
    const top=document.getElementById('runTop');if(top)top.textContent=`${canonicalRunCount()} / 36`;
    document.querySelectorAll('#runPlan .weekBtn').forEach((btn,i)=>{const p=RUN_PLAN[i];if(!p)return;const tiny=btn.querySelectorAll('.tiny')[1]||btn.querySelector('.tiny:last-child');if(tiny){const text=`Mon ${p.Mon[0]} · Tue ${p.Tue[0]} · Wed ${p.Wed[0]} · Thu strength only`;if(tiny.textContent!==text)tiny.textContent=text}})
  }

  function markCurrentDone(kind){const id=kind==='run'?'runDone':'liftDone',box=document.getElementById(id);if(!box||box.checked)return;applyingRemote=true;box.checked=true;box.dispatchEvent(new Event('change',{bubbles:true}));applyingRemote=false;setTimeout(applyCanonicalRunUI,0)}
  function applyCloudPlanner(data){const weekIndex=document.getElementById('week')?.value||'0',dayName=document.getElementById('day')?.value||'Mon',date=workoutDate(weekIndex,dayName),items=Array.isArray(data?.items)?data.items:[];const completedRun=items.some(i=>i?.category==='workout'&&i?.date===date&&i?.completed===true&&(String(i.type||'').toLowerCase()==='run'||String(i.course||'').toLowerCase()==='training'));const completedLift=items.some(i=>i?.category==='workout'&&i?.date===date&&i?.completed===true&&(String(i.type||'').toLowerCase()==='lift'||String(i.course||'').toLowerCase()==='strength'));if(completedRun)markCurrentDone('run');if(completedLift)markCurrentDone('lift');applyCanonicalRunUI()}
  async function pullCompletionState(){if(!sb||!user)return;const {data,error}=await sb.from('planner_state').select('data').eq('user_id',user.id).maybeSingle();if(error){console.warn('Could not pull Command Center workout status',error);return}if(data?.data)applyCloudPlanner(data.data)}
  function subscribePlanner(){if(!sb||!user)return;if(plannerChannel)sb.removeChannel(plannerChannel);plannerChannel=sb.channel(`hybrid-coach-planner-${user.id}`).on('postgres_changes',{event:'*',schema:'public',table:'planner_state',filter:`user_id=eq.${user.id}`},payload=>{if(payload.new?.data)applyCloudPlanner(payload.new.data)}).subscribe()}

  async function initCloud(){
    try{await loadSdk();sb=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,storageKey:AUTH_STORAGE_KEY,autoRefreshToken:true,detectSessionInUrl:false}});const {data}=await sb.auth.getSession();user=data.session?.user||null;setStatus(user?'Command Center · Connected':'Command Center · Connect',user?'connected':'');sb.auth.onAuthStateChange((_event,session)=>{user=session?.user||null;setStatus(user?'Command Center · Connected':'Command Center · Connect',user?'connected':'');if(user){subscribePlanner();setTimeout(pullCompletionState,0)}});if(user){await syncCompletedHistory();subscribePlanner();await pullCompletionState()}}
    catch(err){console.warn('Command Center sync unavailable',err);setStatus('Command Center · Offline','error')}
  }

  function openConnect(){if(user){if(confirm('Command Center sync is connected on this device. Sign out?'))sb.auth.signOut();return}const msg=document.getElementById('ccSyncMsg');if(msg)msg.textContent='';document.getElementById('ccSyncDialog')?.showModal()}
  async function connectAccount(e){e.preventDefault();const msg=document.getElementById('ccSyncMsg');msg.textContent='Connecting…';try{const email=document.getElementById('ccEmail').value.trim(),password=document.getElementById('ccPassword').value;const {data,error}=await sb.auth.signInWithPassword({email,password});if(error)throw error;user=data.user;setStatus('Command Center · Connected','connected');msg.textContent='Connected.';await syncCompletedHistory();subscribePlanner();await pullCompletionState();if(pendingCompletion){const p=pendingCompletion;pendingCompletion=null;await sendCompletion(p)}setTimeout(()=>document.getElementById('ccSyncDialog')?.close(),350)}catch(err){msg.textContent=err?.message||'Could not connect.'}}

  async function sendCompletion({weekIndex,dayName,kind,title}){if(!sb)return false;if(!user){pendingCompletion={weekIndex,dayName,kind,title};openConnect();return false}const date=workoutDate(weekIndex,dayName),row={user_id:user.id,source:'Hybrid Coach',external_id:`hybrid-${date}-${kind}`,workout_date:date,workout_kind:kind,title:title||null};const {error}=await sb.from('workout_completion_events').insert(row);if(error&&error.code!=='23505'){console.warn('Command Center sync failed',error);setStatus('Command Center · Sync issue','error');return false}setStatus('Command Center · Connected','connected');return true}
  async function syncCompletedHistory(){if(!user)return;let raw;try{raw=JSON.parse(localStorage.getItem(TRAINING_STORAGE_KEY)||'null')}catch{return}if(!raw?.days)return;for(const [key,value] of Object.entries(raw.days)){const [weekIndex,dayName]=key.split('-');if(value?.runDone&&canonicalRun(weekIndex,dayName))await sendCompletion({weekIndex,dayName,kind:'run',title:canonicalRun(weekIndex,dayName)[0]});if(value?.liftDone)await sendCompletion({weekIndex,dayName,kind:'lift',title:'Completed strength training'})}}
  function completionFromCheckbox(t){if(!t.checked)return null;const weekIndex=document.getElementById('week')?.value||'0',dayName=document.getElementById('day')?.value||'Mon';if(t.id==='runDone'){const plan=canonicalRun(weekIndex,dayName);if(!plan)return null;return {weekIndex,dayName,kind:'run',title:plan[0]}}if(t.id==='liftDone')return {weekIndex,dayName,kind:'lift',title:document.querySelector('#workout .dayhead h2')?.textContent.trim()||'Strength training'};return null}

  document.addEventListener('change',event=>{const t=event.target;if(t instanceof HTMLInputElement&&(t.id==='runDone'||t.id==='liftDone')){if(!applyingRemote){const completion=completionFromCheckbox(t);if(completion)setTimeout(()=>sendCompletion(completion),0)}setTimeout(()=>{applyCanonicalRunUI();pullCompletionState()},20);return}if(t?.id==='week'||t?.id==='day')setTimeout(()=>{applyCanonicalRunUI();pullCompletionState()},20)},true);
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'){applyCanonicalRunUI();pullCompletionState()}});window.addEventListener('focus',()=>{applyCanonicalRunUI();pullCompletionState()});
  const workoutRoot=document.getElementById('workout');if(workoutRoot)new MutationObserver(()=>applyCanonicalRunUI()).observe(workoutRoot,{childList:true,subtree:true});const runPlanRoot=document.getElementById('runPlan');if(runPlanRoot)new MutationObserver(()=>applyCanonicalRunUI()).observe(runPlanRoot,{childList:true,subtree:true});
  addUI();applyCanonicalRunUI();initCloud();setInterval(()=>{applyCanonicalRunUI();pullCompletionState()},120000);
})();
