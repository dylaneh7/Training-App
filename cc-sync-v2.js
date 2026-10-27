(()=>{
  const SUPABASE_URL='https://ecmosmmqloyahsdcxvpz.supabase.co';
  const SUPABASE_KEY='sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ';
  const BASE_DATE='2026-10-26';
  const AUTH_STORAGE_KEY='hybrid-coach-command-center-auth';
  const dayOffsets={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6};

  let sb=null,user=null,plannerData=null,plannerChannel=null,pendingCompletion=null,applyingRemote=false,applyTimer=null;

  const localDate=iso=>new Date(`${iso}T12:00:00`);
  const addDays=(date,n)=>{const d=new Date(date);d.setDate(d.getDate()+n);return d};
  const isoDate=date=>`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
  const weekStart=index=>addDays(localDate(BASE_DATE),Number(index)*7);
  const workoutDate=(index,day)=>isoDate(addDays(weekStart(index),dayOffsets[day]??0));
  function isoWeek(date){
    const d=new Date(Date.UTC(date.getFullYear(),date.getMonth(),date.getDate()));
    const day=d.getUTCDay()||7;d.setUTCDate(d.getUTCDate()+4-day);
    const y=new Date(Date.UTC(d.getUTCFullYear(),0,1));
    return Math.ceil((((d-y)/86400000)+1)/7);
  }
  const formatStart=date=>date.toLocaleDateString(undefined,{month:'short',day:'numeric'});

  function addStyles(){
    if(document.getElementById('ccSyncStylesV2'))return;
    const s=document.createElement('style');s.id='ccSyncStylesV2';
    s.textContent=`.cc-sync-pill{border:1px solid var(--border);border-radius:999px;padding:7px 10px;font-size:12px;color:var(--muted);background:var(--panel);min-height:38px}.cc-sync-pill.connected{color:var(--ok);border-color:#3b7152;background:#13291c}.cc-sync-pill.error{color:var(--bad);border-color:#7d4141;background:#301818}.cc-sync-dialog{border:1px solid var(--border);border-radius:18px;background:var(--card);color:var(--text);width:min(440px,calc(100% - 24px));padding:0;box-shadow:0 30px 90px rgba(0,0,0,.45)}.cc-sync-dialog::backdrop{background:rgba(0,0,0,.68);backdrop-filter:blur(4px)}.cc-sync-dialog form{padding:18px}.cc-sync-dialog h2{margin:0 0 6px}.cc-sync-dialog p{margin:0 0 14px;color:var(--muted);font-size:12px;line-height:1.5}.cc-sync-actions{display:flex;gap:8px;justify-content:flex-end;margin-top:14px}.cc-sync-msg{min-height:18px;margin-top:8px;font-size:12px;color:var(--muted)}.cc-no-run{opacity:.64}`;
    document.head.appendChild(s);
  }
  function addUI(){
    addStyles();if(document.getElementById('ccSyncBtn'))return;
    const top=document.querySelector('.top .row');if(!top)return;
    const b=document.createElement('button');b.id='ccSyncBtn';b.className='cc-sync-pill';b.type='button';b.textContent='Command Center · Connect';b.onclick=openConnect;top.prepend(b);
    const d=document.createElement('dialog');d.id='ccSyncDialog';d.className='cc-sync-dialog';
    d.innerHTML=`<form method="dialog" id="ccSyncForm"><h2>Connect Command Center</h2><p>Command Center is the source of truth for your run schedule and completion state.</p><label>Email<input id="ccEmail" type="email" autocomplete="email" required></label><label style="display:block;margin-top:8px">Password<input id="ccPassword" type="password" autocomplete="current-password" required></label><div id="ccSyncMsg" class="cc-sync-msg"></div><div class="cc-sync-actions"><button type="button" class="btn" id="ccCancel">Cancel</button><button type="submit" class="btn primary">Connect</button></div></form>`;
    document.body.appendChild(d);d.querySelector('#ccCancel').onclick=()=>d.close();d.querySelector('#ccSyncForm').addEventListener('submit',connectAccount);
  }
  function setStatus(text,kind=''){const b=document.getElementById('ccSyncBtn');if(!b)return;b.textContent=text;b.className='cc-sync-pill'+(kind?' '+kind:'')}
  function items(){return Array.isArray(plannerData?.items)?plannerData.items:[]}
  function isRun(i){return i?.category==='workout'&&(String(i.type||'').toLowerCase()==='run'||String(i.course||'').toLowerCase()==='training')}
  function isLift(i){return i?.category==='workout'&&(String(i.type||'').toLowerCase()==='lift'||String(i.course||'').toLowerCase()==='strength')}
  function runForDate(date){return items().find(i=>isRun(i)&&i.date===date)||null}
  function liftForDate(date){return items().find(i=>isLift(i)&&i.date===date)||null}

  function relabelWeeks(){
    const select=document.getElementById('week');
    if(select){[...select.options].forEach((o,index)=>{const start=weekStart(index),wk=isoWeek(start),parts=o.textContent.split('·').map(x=>x.trim()),phase=parts.length>=3?` · ${parts.slice(-1)[0]}`:'';o.textContent=`Week ${wk} · ${formatStart(start)}${phase}`})}
    document.querySelectorAll('#runPlan .weekBtn').forEach((btn,index)=>{const strong=btn.querySelector('strong');if(strong){const start=weekStart(index);strong.textContent=`Week ${isoWeek(start)} · ${formatStart(start)}`}});
  }
  function setDone(id,done){
    const box=document.getElementById(id);if(!box||box.checked===done)return;
    applyingRemote=true;box.checked=done;box.dispatchEvent(new Event('change',{bubbles:true}));applyingRemote=false;
  }
  function applySelectedDay(){
    const w=document.getElementById('week'),d=document.getElementById('day'),runDone=document.getElementById('runDone');if(!w||!d||!runDone)return;
    const date=workoutDate(w.value,d.value),run=runForDate(date),section=runDone.closest('section');
    if(section){const title=[...section.querySelectorAll(':scope > strong')][0]||section.querySelector('strong'),guide=section.querySelector('p.tiny');section.classList.toggle('cc-no-run',!run);runDone.disabled=!run;
      if(run){if(title)title.textContent=run.title||'Run';if(guide)guide.textContent=run.notes||'Scheduled in Command Center.';setDone('runDone',run.completed===true)}
      else{if(title)title.textContent='No run planned';if(guide)guide.textContent='No run is scheduled in Command Center for this day.';setDone('runDone',false)}
    }
    const lift=liftForDate(date);if(lift)setDone('liftDone',lift.completed===true);
  }
  function applyPlanCards(){
    document.querySelectorAll('#runPlan .weekBtn').forEach((btn,index)=>{const tiny=[...btn.querySelectorAll('.tiny')].pop();if(!tiny)return;const parts=['Mon','Tue','Wed','Thu'].map(day=>{const r=runForDate(workoutDate(index,day));return r?`${day} ${r.title}`:null}).filter(Boolean);tiny.textContent=parts.length?parts.join(' · '):'No Command Center runs scheduled'});
  }
  function updateRunTop(){const runs=items().filter(isRun),top=document.getElementById('runTop');if(top&&runs.length)top.textContent=`${runs.filter(x=>x.completed===true).length} / ${runs.length}`}
  function applyPlanner(data){if(data)plannerData=data;relabelWeeks();updateRunTop();applyPlanCards();applySelectedDay()}
  function scheduleApply(delay=60){clearTimeout(applyTimer);applyTimer=setTimeout(()=>applyPlanner(plannerData),delay)}

  function loadSdk(){return new Promise((resolve,reject)=>{if(window.supabase?.createClient)return resolve();const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';s.onload=resolve;s.onerror=()=>reject(new Error('Could not load cloud sync'));document.head.appendChild(s)})}
  async function pullPlanner(){if(!sb||!user)return;const {data,error}=await sb.from('planner_state').select('data').eq('user_id',user.id).maybeSingle();if(error){console.warn('Could not pull Command Center planner',error);setStatus('Command Center · Sync issue','error');return}if(data?.data)applyPlanner(data.data)}
  function subscribePlanner(){if(!sb||!user)return;if(plannerChannel)sb.removeChannel(plannerChannel);plannerChannel=sb.channel(`hybrid-coach-planner-v3-${user.id}`).on('postgres_changes',{event:'*',schema:'public',table:'planner_state',filter:`user_id=eq.${user.id}`},p=>{if(p.new?.data)applyPlanner(p.new.data)}).subscribe()}
  async function sendCompletion(kind){
    if(!sb)return false;const w=document.getElementById('week')?.value||'0',d=document.getElementById('day')?.value||'Mon',date=workoutDate(w,d),target=kind==='run'?runForDate(date):liftForDate(date);if(kind==='run'&&!target)return false;
    if(!user){pendingCompletion=kind;openConnect();return false}
    const title=target?.title||document.querySelector('#workout .dayhead h2')?.textContent.trim()||'Strength training';
    const {error}=await sb.from('workout_completion_events').insert({user_id:user.id,source:'Hybrid Coach',external_id:`hybrid-${date}-${kind}`,workout_date:date,workout_kind:kind,title});
    if(error&&error.code!=='23505'){console.warn('Completion sync failed',error);setStatus('Command Center · Sync issue','error');return false}
    setStatus('Command Center · Connected','connected');setTimeout(pullPlanner,150);return true;
  }
  function openConnect(){if(user){if(confirm('Command Center sync is connected on this device. Sign out?'))sb.auth.signOut();return}const msg=document.getElementById('ccSyncMsg');if(msg)msg.textContent='';document.getElementById('ccSyncDialog')?.showModal()}
  async function connectAccount(e){e.preventDefault();const msg=document.getElementById('ccSyncMsg');if(msg)msg.textContent='Connecting…';try{const email=document.getElementById('ccEmail').value.trim(),password=document.getElementById('ccPassword').value,{data,error}=await sb.auth.signInWithPassword({email,password});if(error)throw error;user=data.user;setStatus('Command Center · Connected','connected');subscribePlanner();await pullPlanner();if(pendingCompletion){const k=pendingCompletion;pendingCompletion=null;await sendCompletion(k)}if(msg)msg.textContent='Connected.';setTimeout(()=>document.getElementById('ccSyncDialog')?.close(),300)}catch(err){if(msg)msg.textContent=err?.message||'Could not connect.'}}
  async function initCloud(){try{await loadSdk();sb=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,storageKey:AUTH_STORAGE_KEY,autoRefreshToken:true,detectSessionInUrl:false}});const {data}=await sb.auth.getSession();user=data.session?.user||null;setStatus(user?'Command Center · Connected':'Command Center · Connect',user?'connected':'');sb.auth.onAuthStateChange((_e,s)=>{user=s?.user||null;setStatus(user?'Command Center · Connected':'Command Center · Connect',user?'connected':'');if(user){subscribePlanner();setTimeout(pullPlanner,0)}});if(user){subscribePlanner();await pullPlanner()}}catch(err){console.warn('Command Center sync unavailable',err);setStatus('Command Center · Offline','error')}}

  document.addEventListener('change',e=>{const t=e.target;if(t instanceof HTMLInputElement&&(t.id==='runDone'||t.id==='liftDone')){if(!applyingRemote&&t.checked)setTimeout(()=>sendCompletion(t.id==='runDone'?'run':'lift'),0);scheduleApply(100)}else if(t?.id==='week'||t?.id==='day')scheduleApply(100)},true);
  document.addEventListener('click',e=>{const t=e.target?.closest?.('.weekBtn,.tab');if(t)scheduleApply(120)},true);
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'){scheduleApply(80);pullPlanner()}});
  window.addEventListener('focus',()=>{scheduleApply(80);pullPlanner()});window.addEventListener('online',pullPlanner);

  addUI();relabelWeeks();scheduleApply(150);initCloud();setInterval(()=>{relabelWeeks();scheduleApply(50);pullPlanner()},60000);
})();