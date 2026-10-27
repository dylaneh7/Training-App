(()=>{
  const SUPABASE_URL='https://ecmosmmqloyahsdcxvpz.supabase.co';
  const SUPABASE_KEY='sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ';
  const BASE_DATE='2026-10-26';
  const AUTH_STORAGE_KEY='hybrid-coach-command-center-auth';

  let sb=null;
  let user=null;
  let plannerData=null;
  let plannerChannel=null;
  let applyingRemote=false;
  let pendingCompletion=null;
  let refreshQueued=false;

  const dayOffsets={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6};

  function localDate(iso){return new Date(`${iso}T12:00:00`)}
  function addDays(date,n){const d=new Date(date);d.setDate(d.getDate()+n);return d}
  function isoDate(date){return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`}
  function weekStart(index){return addDays(localDate(BASE_DATE),Number(index)*7)}
  function workoutDate(index,dayName){return isoDate(addDays(weekStart(index),dayOffsets[dayName]??0))}
  function isoWeek(date){
    const d=new Date(Date.UTC(date.getFullYear(),date.getMonth(),date.getDate()));
    const day=d.getUTCDay()||7;
    d.setUTCDate(d.getUTCDate()+4-day);
    const yearStart=new Date(Date.UTC(d.getUTCFullYear(),0,1));
    return Math.ceil((((d-yearStart)/86400000)+1)/7);
  }
  function formatStart(date){return date.toLocaleDateString(undefined,{month:'short',day:'numeric'})}

  function addStyles(){
    if(document.getElementById('ccSyncStylesV2'))return;
    const style=document.createElement('style');
    style.id='ccSyncStylesV2';
    style.textContent=`.cc-sync-pill{border:1px solid var(--border);border-radius:999px;padding:7px 10px;font-size:12px;color:var(--muted);background:var(--panel);min-height:38px}.cc-sync-pill.connected{color:var(--ok);border-color:#3b7152;background:#13291c}.cc-sync-pill.error{color:var(--bad);border-color:#7d4141;background:#301818}.cc-sync-dialog{border:1px solid var(--border);border-radius:18px;background:var(--card);color:var(--text);width:min(440px,calc(100% - 24px));padding:0;box-shadow:0 30px 90px rgba(0,0,0,.45)}.cc-sync-dialog::backdrop{background:rgba(0,0,0,.68);backdrop-filter:blur(4px)}.cc-sync-dialog form{padding:18px}.cc-sync-dialog h2{margin:0 0 6px}.cc-sync-dialog p{margin:0 0 14px;color:var(--muted);font-size:12px;line-height:1.5}.cc-sync-actions{display:flex;gap:8px;justify-content:flex-end;margin-top:14px}.cc-sync-msg{min-height:18px;margin-top:8px;font-size:12px;color:var(--muted)}.cc-no-run{opacity:.64}`;
    document.head.appendChild(style);
  }

  function addUI(){
    addStyles();
    if(document.getElementById('ccSyncBtn'))return;
    const top=document.querySelector('.top .row');
    if(!top)return;
    const button=document.createElement('button');
    button.id='ccSyncBtn';button.className='cc-sync-pill';button.type='button';button.textContent='Command Center · Connect';button.addEventListener('click',openConnect);top.prepend(button);
    const dialog=document.createElement('dialog');
    dialog.id='ccSyncDialog';dialog.className='cc-sync-dialog';
    dialog.innerHTML=`<form method="dialog" id="ccSyncForm"><h2>Connect Command Center</h2><p>Command Center is the source of truth for your run schedule. Hybrid Coach uses the exact same run title, date and completion status.</p><label>Email<input id="ccEmail" type="email" autocomplete="email" required></label><label style="display:block;margin-top:8px">Password<input id="ccPassword" type="password" autocomplete="current-password" required></label><div id="ccSyncMsg" class="cc-sync-msg"></div><div class="cc-sync-actions"><button type="button" class="btn" id="ccCancel">Cancel</button><button type="submit" class="btn primary">Connect</button></div></form>`;
    document.body.appendChild(dialog);
    dialog.querySelector('#ccCancel').addEventListener('click',()=>dialog.close());
    dialog.querySelector('#ccSyncForm').addEventListener('submit',connectAccount);
  }

  function setStatus(text,kind=''){
    const b=document.getElementById('ccSyncBtn');if(!b)return;
    b.textContent=text;b.className='cc-sync-pill'+(kind?' '+kind:'');
  }

  function relabelWeeks(){
    const select=document.getElementById('week');
    if(select){
      [...select.options].forEach((option,index)=>{
        const start=weekStart(index), wk=isoWeek(start);
        const parts=option.textContent.split('·').map(x=>x.trim());
        const phase=parts.length>=3?` · ${parts.slice(2).join(' · ')}`:'';
        const desired=`Week ${wk} · ${formatStart(start)}${phase}`;
        if(option.textContent!==desired)option.textContent=desired;
      });
    }
    document.querySelectorAll('#runPlan .weekBtn').forEach((btn,index)=>{
      const strong=btn.querySelector('strong');if(!strong)return;
      const start=weekStart(index), wk=isoWeek(start);
      const desired=`Week ${wk} · ${formatStart(start)}`;
      if(strong.textContent!==desired)strong.textContent=desired;
    });
  }

  function items(){return Array.isArray(plannerData?.items)?plannerData.items:[]}
  function isRun(item){return item?.category==='workout'&&(String(item.type||'').toLowerCase()==='run'||String(item.course||'').toLowerCase()==='training')}
  function isLift(item){return item?.category==='workout'&&(String(item.type||'').toLowerCase()==='lift'||String(item.course||'').toLowerCase()==='strength')}
  function runForDate(date){
    const matches=items().filter(i=>isRun(i)&&i.date===date);
    if(!matches.length)return null;
    matches.sort((a,b)=>Number(Boolean(b.completed))-Number(Boolean(a.completed)));
    return matches[0];
  }
  function liftForDate(date){return items().find(i=>isLift(i)&&i.date===date)||null}

  function setDone(id,done){
    const box=document.getElementById(id);if(!box||box.checked===done)return;
    applyingRemote=true;
    box.checked=done;
    box.dispatchEvent(new Event('change',{bubbles:true}));
    applyingRemote=false;
  }

  function applySelectedDay(){
    const weekEl=document.getElementById('week'),dayEl=document.getElementById('day'),runDone=document.getElementById('runDone');
    if(!weekEl||!dayEl||!runDone)return;
    const date=workoutDate(weekEl.value,dayEl.value);
    const run=runForDate(date);
    const section=runDone.closest('section');
    if(section){
      const title=[...section.querySelectorAll(':scope > strong')][0]||section.querySelector('strong');
      const guide=section.querySelector('p.tiny');
      section.classList.toggle('cc-no-run',!run);
      runDone.disabled=!run;
      if(run){
        if(title&&title.textContent!==run.title)title.textContent=run.title;
        const note=run.notes||'Scheduled in Command Center.';
        if(guide&&guide.textContent!==note)guide.textContent=note;
        setDone('runDone',run.completed===true);
      }else{
        if(title&&title.textContent!=='No run planned')title.textContent='No run planned';
        if(guide&&guide.textContent!=='No run is scheduled in Command Center for this day.')guide.textContent='No run is scheduled in Command Center for this day.';
        setDone('runDone',false);
      }
    }
    const lift=liftForDate(date);
    if(lift)setDone('liftDone',lift.completed===true);
  }

  function applyPlanCards(){
    document.querySelectorAll('#runPlan .weekBtn').forEach((btn,index)=>{
      const tiny=[...btn.querySelectorAll('.tiny')].pop();if(!tiny)return;
      const parts=['Mon','Tue','Wed','Thu'].map(day=>{
        const run=runForDate(workoutDate(index,day));
        return run?`${day} ${run.title}`:null;
      }).filter(Boolean);
      const desired=parts.length?parts.join(' · '):'No Command Center runs scheduled';
      if(tiny.textContent!==desired)tiny.textContent=desired;
    });
  }

  function updateRunTop(){
    const runItems=items().filter(isRun);
    const total=runItems.length;
    const done=runItems.filter(i=>i.completed===true).length;
    const top=document.getElementById('runTop');if(top&&total)top.textContent=`${done} / ${total}`;
  }

  function applyPlanner(data){
    plannerData=data||plannerData;
    relabelWeeks();
    applyPlanCards();
    updateRunTop();
    applySelectedDay();
  }

  function queueApply(){
    if(refreshQueued)return;refreshQueued=true;
    requestAnimationFrame(()=>{refreshQueued=false;applyPlanner(plannerData)});
  }

  function loadSdk(){return new Promise((resolve,reject)=>{
    if(window.supabase?.createClient)return resolve();
    const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';s.onload=resolve;s.onerror=()=>reject(new Error('Could not load cloud sync'));document.head.appendChild(s);
  })}

  async function pullPlanner(){
    if(!sb||!user)return;
    const {data,error}=await sb.from('planner_state').select('data').eq('user_id',user.id).maybeSingle();
    if(error){console.warn('Could not pull Command Center planner',error);setStatus('Command Center · Sync issue','error');return}
    if(data?.data)applyPlanner(data.data);
  }

  function subscribePlanner(){
    if(!sb||!user)return;
    if(plannerChannel)sb.removeChannel(plannerChannel);
    plannerChannel=sb.channel(`hybrid-coach-planner-v2-${user.id}`).on('postgres_changes',{event:'*',schema:'public',table:'planner_state',filter:`user_id=eq.${user.id}`},payload=>{if(payload.new?.data)applyPlanner(payload.new.data)}).subscribe();
  }

  async function sendCompletion(kind){
    if(!sb)return false;
    const weekIndex=document.getElementById('week')?.value||'0';
    const dayName=document.getElementById('day')?.value||'Mon';
    const date=workoutDate(weekIndex,dayName);
    const target=kind==='run'?runForDate(date):liftForDate(date);
    if(kind==='run'&&!target)return false;
    const title=target?.title||document.querySelector('#workout .dayhead h2')?.textContent.trim()||'Strength training';
    if(!user){pendingCompletion=kind;openConnect();return false}
    const row={user_id:user.id,source:'Hybrid Coach',external_id:`hybrid-${date}-${kind}`,workout_date:date,workout_kind:kind,title};
    const {error}=await sb.from('workout_completion_events').insert(row);
    if(error&&error.code!=='23505'){console.warn('Command Center completion sync failed',error);setStatus('Command Center · Sync issue','error');return false}
    setStatus('Command Center · Connected','connected');
    setTimeout(pullPlanner,150);
    return true;
  }

  function openConnect(){
    if(user){if(confirm('Command Center sync is connected on this device. Sign out?'))sb.auth.signOut();return}
    const msg=document.getElementById('ccSyncMsg');if(msg)msg.textContent='';
    document.getElementById('ccSyncDialog')?.showModal();
  }

  async function connectAccount(e){
    e.preventDefault();const msg=document.getElementById('ccSyncMsg');msg.textContent='Connecting…';
    try{
      const email=document.getElementById('ccEmail').value.trim(),password=document.getElementById('ccPassword').value;
      const {data,error}=await sb.auth.signInWithPassword({email,password});if(error)throw error;
      user=data.user;setStatus('Command Center · Connected','connected');msg.textContent='Connected.';
      subscribePlanner();await pullPlanner();
      if(pendingCompletion){const kind=pendingCompletion;pendingCompletion=null;await sendCompletion(kind)}
      setTimeout(()=>document.getElementById('ccSyncDialog')?.close(),300);
    }catch(err){msg.textContent=err?.message||'Could not connect.'}
  }

  async function initCloud(){
    try{
      await loadSdk();
      sb=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,storageKey:AUTH_STORAGE_KEY,autoRefreshToken:true,detectSessionInUrl:false}});
      const {data}=await sb.auth.getSession();user=data.session?.user||null;
      setStatus(user?'Command Center · Connected':'Command Center · Connect',user?'connected':'');
      sb.auth.onAuthStateChange((_event,session)=>{user=session?.user||null;setStatus(user?'Command Center · Connected':'Command Center · Connect',user?'connected':'');if(user){subscribePlanner();setTimeout(pullPlanner,0)}});
      if(user){subscribePlanner();await pullPlanner()}
    }catch(err){console.warn('Command Center sync unavailable',err);setStatus('Command Center · Offline','error')}
  }

  document.addEventListener('change',event=>{
    const t=event.target;
    if(t instanceof HTMLInputElement&&(t.id==='runDone'||t.id==='liftDone')){
      if(!applyingRemote&&t.checked)setTimeout(()=>sendCompletion(t.id==='runDone'?'run':'lift'),0);
      setTimeout(queueApply,20);return;
    }
    if(t?.id==='week'||t?.id==='day')setTimeout(queueApply,20);
  },true);

  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'){queueApply();pullPlanner()}});
  window.addEventListener('focus',()=>{queueApply();pullPlanner()});
  window.addEventListener('online',pullPlanner);

  const observer=new MutationObserver(queueApply);
  const workoutRoot=document.getElementById('workout');if(workoutRoot)observer.observe(workoutRoot,{childList:true,subtree:true});
  const runPlanRoot=document.getElementById('runPlan');if(runPlanRoot)observer.observe(runPlanRoot,{childList:true,subtree:true});

  addUI();
  relabelWeeks();
  initCloud();
  setInterval(()=>{relabelWeeks();pullPlanner()},120000);
})();