(()=>{
  const SUPABASE_URL='https://ecmosmmqloyahsdcxvpz.supabase.co';
  const SUPABASE_KEY='sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ';
  const BASE_DATE='2026-10-26';
  const AUTH_STORAGE_KEY='hybrid-coach-command-center-auth';
  let sb=null;
  let user=null;
  let pendingCompletion=null;

  function addStyles(){
    if(document.getElementById('ccSyncStyles')) return;
    const style=document.createElement('style');
    style.id='ccSyncStyles';
    style.textContent=`
      .cc-sync-pill{border:1px solid var(--border);border-radius:999px;padding:7px 10px;font-size:12px;color:var(--muted);background:var(--panel);min-height:38px}
      .cc-sync-pill.connected{color:var(--ok);border-color:#3b7152;background:#13291c}
      .cc-sync-pill.error{color:var(--bad);border-color:#7d4141;background:#301818}
      .cc-sync-dialog{border:1px solid var(--border);border-radius:18px;background:var(--card);color:var(--text);width:min(440px,calc(100% - 24px));padding:0;box-shadow:0 30px 90px rgba(0,0,0,.45)}
      .cc-sync-dialog::backdrop{background:rgba(0,0,0,.68);backdrop-filter:blur(4px)}
      .cc-sync-dialog form{padding:18px}.cc-sync-dialog h2{margin:0 0 6px}.cc-sync-dialog p{margin:0 0 14px;color:var(--muted);font-size:12px;line-height:1.5}
      .cc-sync-actions{display:flex;gap:8px;justify-content:flex-end;margin-top:14px}.cc-sync-msg{min-height:18px;margin-top:8px;font-size:12px;color:var(--muted)}
    `;
    document.head.appendChild(style);
  }

  function addUI(){
    addStyles();
    if(document.getElementById('ccSyncBtn')) return;
    const top=document.querySelector('.top .row');
    if(!top) return;
    const button=document.createElement('button');
    button.id='ccSyncBtn';
    button.className='cc-sync-pill';
    button.type='button';
    button.textContent='Command Center · Connect';
    button.addEventListener('click',openConnect);
    top.prepend(button);

    const dialog=document.createElement('dialog');
    dialog.id='ccSyncDialog';
    dialog.className='cc-sync-dialog';
    dialog.innerHTML=`
      <form method="dialog" id="ccSyncForm">
        <h2>Connect Command Center</h2>
        <p>Sign in with the same account you use in School Command Center. Once connected, checking <b>Lifting</b> complete here marks that day's strength workout complete in Command Center.</p>
        <label>Email<input id="ccEmail" type="email" autocomplete="email" required></label>
        <label style="display:block;margin-top:8px">Password<input id="ccPassword" type="password" autocomplete="current-password" required></label>
        <div id="ccSyncMsg" class="cc-sync-msg"></div>
        <div class="cc-sync-actions">
          <button type="button" class="btn" id="ccCancel">Cancel</button>
          <button type="submit" class="btn primary">Connect</button>
        </div>
      </form>`;
    document.body.appendChild(dialog);
    dialog.querySelector('#ccCancel').addEventListener('click',()=>dialog.close());
    dialog.querySelector('#ccSyncForm').addEventListener('submit',connectAccount);
  }

  function setStatus(text,kind=''){
    const b=document.getElementById('ccSyncBtn');
    if(!b) return;
    b.textContent=text;
    b.className='cc-sync-pill'+(kind?' '+kind:'');
  }

  function loadSdk(){
    return new Promise((resolve,reject)=>{
      if(window.supabase?.createClient) return resolve();
      const s=document.createElement('script');
      s.src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';
      s.onload=resolve;
      s.onerror=()=>reject(new Error('Could not load cloud sync'));
      document.head.appendChild(s);
    });
  }

  async function initCloud(){
    try{
      await loadSdk();
      sb=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY,{
        auth:{persistSession:true,storageKey:AUTH_STORAGE_KEY,autoRefreshToken:true,detectSessionInUrl:false}
      });
      const {data}=await sb.auth.getSession();
      user=data.session?.user||null;
      setStatus(user?'Command Center · Connected':'Command Center · Connect',user?'connected':'');
      sb.auth.onAuthStateChange((_event,session)=>{
        user=session?.user||null;
        setStatus(user?'Command Center · Connected':'Command Center · Connect',user?'connected':'');
      });
      if(user) await syncCompletedHistory();
    }catch(err){
      console.warn('Command Center sync unavailable',err);
      setStatus('Command Center · Offline','error');
    }
  }

  function openConnect(){
    if(user){
      if(confirm('Command Center sync is connected on this device. Sign out?')) sb.auth.signOut();
      return;
    }
    const msg=document.getElementById('ccSyncMsg');
    if(msg) msg.textContent='';
    document.getElementById('ccSyncDialog')?.showModal();
  }

  async function connectAccount(e){
    e.preventDefault();
    const msg=document.getElementById('ccSyncMsg');
    msg.textContent='Connecting…';
    try{
      const email=document.getElementById('ccEmail').value.trim();
      const password=document.getElementById('ccPassword').value;
      const {data,error}=await sb.auth.signInWithPassword({email,password});
      if(error) throw error;
      user=data.user;
      setStatus('Command Center · Connected','connected');
      msg.textContent='Connected.';
      await syncCompletedHistory();
      if(pendingCompletion){const p=pendingCompletion;pendingCompletion=null;await sendCompletion(p)}
      setTimeout(()=>document.getElementById('ccSyncDialog')?.close(),350);
    }catch(err){msg.textContent=err?.message||'Could not connect.'}
  }

  function workoutDate(weekIndex,dayName){
    const offsets={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6};
    const d=new Date(`${BASE_DATE}T12:00:00`);
    d.setDate(d.getDate()+Number(weekIndex)*7+(offsets[dayName]??0));
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  }

  async function sendCompletion({weekIndex,dayName,title}){
    if(!sb) return false;
    if(!user){pendingCompletion={weekIndex,dayName,title};openConnect();return false}
    const date=workoutDate(weekIndex,dayName);
    const row={user_id:user.id,source:'Hybrid Coach',external_id:`hybrid-${date}-lift`,workout_date:date,workout_kind:'lift',title:title||null};
    const {error}=await sb.from('workout_completion_events').insert(row);
    if(error&&error.code!=='23505'){
      console.warn('Command Center sync failed',error);
      setStatus('Command Center · Sync issue','error');
      return false;
    }
    setStatus('Command Center · Connected','connected');
    return true;
  }

  async function syncCompletedHistory(){
    if(!user) return;
    let raw;
    try{raw=JSON.parse(localStorage.getItem('hybridCoachData_v1')||'null')}catch{return}
    if(!raw?.days) return;
    for(const [key,value] of Object.entries(raw.days)){
      if(!value?.liftDone) continue;
      const [weekIndex,dayName]=key.split('-');
      await sendCompletion({weekIndex,dayName,title:'Completed strength training'});
    }
  }

  document.addEventListener('change',event=>{
    const t=event.target;
    if(!(t instanceof HTMLInputElement)||t.id!=='liftDone'||!t.checked) return;
    const weekIndex=document.getElementById('week')?.value||'0';
    const dayName=document.getElementById('day')?.value||'Mon';
    const title=document.querySelector('#workout .dayhead h2')?.textContent.trim()||'Strength training';
    setTimeout(()=>sendCompletion({weekIndex,dayName,title}),0);
  },true);

  addUI();
  initCloud();
})();
