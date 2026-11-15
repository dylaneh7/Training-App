(()=>{
  if(window.__hcDailyActivityLog)return;
  window.__hcDailyActivityLog=true;
  const SUPABASE_URL='https://ecmosmmqloyahsdcxvpz.supabase.co';
  const SUPABASE_KEY='sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ';
  const AUTH_KEY='hybrid-coach-command-center-auth';
  let cloudClient=null,remoteItems=[],lastDate='',fetchSeq=0;
  const root=()=>document.querySelector('[data-panel="workout"]');
  const pad=n=>String(n).padStart(2,'0');
  function dateISO(d){return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate())}
  const today=()=>dateISO(new Date());
  const escapeHTML=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const storage=()=>window.healthCoachActivities;
  function activities(){return storage()?.list()||[]}
  function save(items){
    if(!storage())return;
    storage().save(items);
    document.dispatchEvent(new Event('change',{bubbles:true}));
    render();
  }
  function selectedDate(){return document.getElementById('hcActivityDate')?.value||today()}
  function inject(){
    if(document.getElementById('hcDailyActivity'))return;
    const panel=root(),workout=document.getElementById('workout');
    if(!panel||!workout||!storage())return;
    const style=document.createElement('style');
    style.id='hcDailyActivityStyles';
    style.textContent='.hc-activity-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}.hc-activity-form{display:grid;grid-template-columns:1fr 1fr;gap:9px;margin-top:12px}.hc-activity-form label{display:block}.hc-activity-form .wide{grid-column:1/-1}.hc-activity-item{padding:10px 0;border-bottom:1px solid var(--border)}.hc-activity-item:last-child{border-bottom:0}.hc-activity-head{display:flex;gap:8px;justify-content:space-between;align-items:start}.hc-activity-badge{font-size:11px;border:1px solid var(--border);border-radius:999px;padding:3px 7px;white-space:nowrap}.hc-activity-success{color:var(--ok);border-color:#42725a}.hc-activity-datebar{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.hc-activity-datebar input{max-width:185px}.hc-activity-list{margin-top:10px}@media(max-width:600px){.hc-activity-form{grid-template-columns:1fr 1fr}.hc-activity-head{flex-wrap:wrap}}';
    document.head.appendChild(style);
    const card=document.createElement('div');
    card.id='hcDailyActivity';card.className='card';
    card.innerHTML='<div class="section-title"><div><h2 style="margin:0 0 3px">Daily activity</h2><div class="tiny">Planned workouts and completed workouts are separate. Add a run or lift on any day.</div></div></div>'+
      '<div class="hc-activity-datebar"><label for="hcActivityDate">Date</label><button type="button" class="btn" id="hcActivityPrev" aria-label="Previous date">‹</button><input id="hcActivityDate" type="date" value="'+today()+'"><button type="button" class="btn" id="hcActivityNext" aria-label="Next date">›</button><button type="button" class="btn" id="hcActivityToday">Today</button></div>'+
      '<div id="hcActivitySummary" class="tiny" style="margin-top:7px"></div><div id="hcActivityList" class="hc-activity-list"></div>'+
      '<details id="hcActivityAdd" style="margin-top:12px"><summary class="btn primary" style="display:inline-block;list-style:none">+ Create a workout or run</summary>'+
      '<form id="hcActivityForm" class="hc-activity-form">'+
      '<label>Activity<select id="hcActivityType"><option value="run">Run</option><option value="lift">Strength workout</option><option value="walk">Walk</option><option value="other">Other</option></select></label>'+
      '<label>Duration (minutes)<input id="hcActivityMinutes" inputmode="decimal" type="number" min="0" max="1440" step="any" placeholder="Optional"></label>'+
      '<label class="wide">Workout name<input id="hcActivityTitle" maxlength="120" placeholder="e.g. Easy 3-mile run or Upper-body workout"></label>'+
      '<label id="hcActivityMilesLabel">Distance (miles)<input id="hcActivityMiles" inputmode="decimal" type="number" min="0" max="1000" step="0.01" placeholder="Optional"></label>'+
      '<label>Notes<input id="hcActivityNotes" maxlength="500" placeholder="Optional"></label>'+
      '<div class="hc-activity-actions wide"><button class="btn primary" type="submit" name="action" value="complete">Log completed</button><button class="btn" type="submit" name="action" value="plan">Schedule for this day</button></div>'+
      '</form></details><div id="hcActivityCloud" class="tiny" style="margin-top:12px"></div>';
    workout.parentNode.insertBefore(card,workout);
    const dateInput=document.getElementById('hcActivityDate');
    dateInput.addEventListener('change',()=>{remoteItems=[];render();fetchRemote()});
    function shift(n){const d=new Date(selectedDate()+'T12:00:00');d.setDate(d.getDate()+n);dateInput.value=dateISO(d);remoteItems=[];render();fetchRemote()}
    document.getElementById('hcActivityPrev').onclick=()=>shift(-1);
    document.getElementById('hcActivityNext').onclick=()=>shift(1);
    document.getElementById('hcActivityToday').onclick=()=>{dateInput.value=today();remoteItems=[];render();fetchRemote()};
    document.getElementById('hcActivityForm').addEventListener('submit',event=>{
      event.preventDefault();
      const button=event.submitter;
      const done=button?.value==='complete';
      const type=document.getElementById('hcActivityType').value;
      const title=document.getElementById('hcActivityTitle').value.trim()||({run:'Run',lift:'Strength workout',walk:'Walk',other:'Workout'}[type]);
      const min=document.getElementById('hcActivityMinutes').value;
      const mi=document.getElementById('hcActivityMiles').value;
      const notes=document.getElementById('hcActivityNotes').value.trim();
      if(min!==''&&(!Number.isFinite(Number(min))||Number(min)<0||Number(min)>1440))return;
      if(mi!==''&&(!Number.isFinite(Number(mi))||Number(mi)<0||Number(mi)>1000))return;
      const entry={id:'manual-'+Date.now()+'-'+Math.random().toString(36).slice(2,8),date:selectedDate(),kind:type,title,durationMinutes:min===''?null:Number(min),miles:mi===''?null:Number(mi),notes,completed:done,createdAt:new Date().toISOString(),source:'Manual'};
      save([...activities(),entry]);
      document.getElementById('hcActivityForm').reset();
      document.getElementById('hcActivityAdd').open=false;
    });
    document.getElementById('hcActivityList').addEventListener('click',event=>{
      const b=event.target.closest('button[data-activity-id]');if(!b)return;
      const id=b.getAttribute('data-activity-id'),action=b.getAttribute('data-activity-action');
      const rows=activities();
      if(action==='delete'){
        if(!confirm('Remove this manual workout?'))return;
        save(rows.filter(x=>x.id!==id));
      }else if(action==='toggle')save(rows.map(x=>x.id===id?{...x,completed:!x.completed}:x));
    });
    document.getElementById('hcActivityType').addEventListener('change',()=>{
      const type=document.getElementById('hcActivityType').value;
      document.getElementById('hcActivityMilesLabel').style.display=(type==='run'||type==='walk')?'':'none';
    });
    render();fetchRemote();
  }
  function itemHTML(x,remote){
    const kind={run:'Run',lift:'Strength',walk:'Walk',other:'Other'}[x.kind]||'Workout';
    const details=[];
    if(x.durationMinutes!==null&&x.durationMinutes!==undefined&&x.durationMinutes!=='')details.push(Number(x.durationMinutes).toFixed(0)+' min');
    if(x.miles!==null&&x.miles!==undefined&&x.miles!=='')details.push(Number(x.miles).toFixed(2)+' mi');
    if(x.notes)details.push(x.notes);
    const tag=remote?'Synced':x.completed?'Completed':'Planned';
    const actions=remote?'':'<div class="hc-activity-actions"><button class="btn" type="button" data-activity-id="'+escapeHTML(x.id)+'" data-activity-action="toggle">'+(x.completed?'Mark as planned':'Mark completed')+'</button><button class="btn" type="button" data-activity-id="'+escapeHTML(x.id)+'" data-activity-action="delete">Remove</button></div>';
    return '<div class="hc-activity-item"><div class="hc-activity-head"><div><strong>'+escapeHTML(x.title||kind)+'</strong><div class="tiny">'+escapeHTML(kind)+(remote?' · '+escapeHTML(x.source||'Command Center'):'')+(details.length?' · '+escapeHTML(details.join(' · ')):'')+'</div></div><span class="hc-activity-badge '+((remote||x.completed)?'hc-activity-success':'')+'">'+tag+'</span></div>'+actions+'</div>';
  }
  function render(){
    const list=document.getElementById('hcActivityList');if(!list)return;
    const date=selectedDate(),local=activities().filter(x=>x.date===date);
    const synced=remoteItems.filter(x=>x.date===date);
    const complete=local.filter(x=>x.completed).length+synced.length,planned=local.filter(x=>!x.completed).length;
    document.getElementById('hcActivitySummary').textContent=complete+' completed · '+planned+' planned · '+date;
    list.innerHTML=local.map(x=>itemHTML(x,false)).join('')+synced.map(x=>itemHTML(x,true)).join('')||'<div class="tiny">No completed or manually planned activity logged for this date. You can add one even when the training calendar is empty.</div>';
  }
  async function fetchRemote(){
    const date=selectedDate(),seq=++fetchSeq;
    const label=document.getElementById('hcActivityCloud');
    if(label)label.textContent='Checking connected workout history…';
    if(!window.supabase?.createClient){if(label)label.textContent='Manual workouts save locally and join your Command Center backup when connected.';return}
    try{
      cloudClient=cloudClient||window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,storageKey:AUTH_KEY,autoRefreshToken:true,detectSessionInUrl:false}});
      const {data:{session}}=await cloudClient.auth.getSession();
      if(seq!==fetchSeq||date!==selectedDate())return;
      if(!session?.user?.id){if(label)label.textContent='Connect Command Center to see automatically imported workouts here.';return}
      const {data,error}=await cloudClient.from('workout_completion_events')
        .select('id,source,title,workout_kind,activity_started_at,activity_duration_sec,activity_duration_total_sec,activity_distance_m')
        .eq('user_id',session.user.id).eq('workout_date',date)
        .order('created_at',{ascending:false}).limit(60);
      if(error)throw error;
      if(seq!==fetchSeq||date!==selectedDate())return;
      const seen=[];
      remoteItems=(data||[]).filter(x=>{
        const stamp=x.activity_started_at?new Date(x.activity_started_at).getTime():null;
        if(stamp&&seen.some(s=>s.kind===x.workout_kind&&s.stamp!==null&&Math.abs(s.stamp-stamp)<10*60*1000))return false;
        seen.push({kind:x.workout_kind,stamp});return true;
      }).map(x=>({id:x.id,date,kind:x.workout_kind||'other',title:x.title||'Completed workout',durationMinutes:(x.activity_duration_total_sec||x.activity_duration_sec)?(x.activity_duration_total_sec||x.activity_duration_sec)/60:null,miles:x.activity_distance_m?x.activity_distance_m/1609.344:null,source:x.source||'Command Center',completed:true}));
      if(label)label.textContent='Synced workouts come from Command Center; Apple Health-only sessions may still need importing.';
      render();
    }catch(error){if(label)label.textContent='Could not load synced workouts. Manual logging still works.';console.warn('Daily activity sync',error)}
  }
  function start(){
    inject();
    window.addEventListener('focus',()=>{if(document.getElementById('hcDailyActivity'))fetchRemote()});
    document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')fetchRemote()});
    document.addEventListener('click',e=>{if(e.target?.closest?.('.tab[data-tab="workout"]'))setTimeout(()=>{inject();fetchRemote()},160)},true);
    setInterval(()=>{if(document.visibilityState==='visible'&&document.getElementById('hcDailyActivity'))fetchRemote()},120000);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(start,2000),{once:true});
  else setTimeout(start,2000);
})();