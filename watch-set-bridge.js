(()=>{
  if(window.__healthCoachWatchSetBridge)return;
  window.__healthCoachWatchSetBridge=true;
  const url='https://ecmosmmqloyahsdcxvpz.supabase.co';
  const key='sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ';
  const auth='hybrid-coach-command-center-auth';
  const offset={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6,RestWed:2,UpperThu:3,LegsFri:4,SatUpper:5};
  let client=null,timer=null,serial=0,lastSig='',latest=[];
  const clean=t=>String(t||'').toLowerCase().replace(/[—–-]/g,' ').replace(/\s+/g,' ').trim();
  const currentKey=()=>`${document.getElementById('week')?.value||0}-${document.getElementById('day')?.value||'Mon'}`;
  function date(){
    const d=new Date(2026,9,26,12),wi=Number(document.getElementById('week')?.value||0),dy=document.getElementById('day')?.value||'Mon';
    d.setDate(d.getDate()+wi*7+(offset[dy]??0));
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  }
  const html=t=>String(t??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function card(){
    const holder=document.querySelector('#workout #exercises');
    if(!holder)return null;
    let panel=document.querySelector('#workout #hcWatchSetsPanel');
    if(!panel){
      panel=document.createElement('div');panel.id='hcWatchSetsPanel';panel.className='guidebox';
      panel.style.cssText='margin-top:14px;padding:12px;border:1px solid var(--border);border-radius:12px;';
      holder.insertAdjacentElement('afterend',panel);
    }
    return panel;
  }
  function applyToEmpty(){
    const holder=document.getElementById('exercises');if(!holder)return 0;
    const exercises=[...holder.querySelectorAll(':scope > .exercise')].filter(n=>n.style.display!=='none');
    let changed=0;
    for(const item of latest){
      if(item.session_key!==currentKey())continue;
      const match=exercises.find(box=>{
        const selected=box.querySelector('.choice')?.value||box.querySelector('.hc-custom-name')?.textContent||'';
        return clean(selected)===clean(item.exercise_name);
      });
      if(!match)continue;
      const rows=[...match.querySelectorAll(':scope > .setrow:not(.head)')].filter(r=>!r.classList.contains('hc-set-hidden')&&r.style.display!=='none');
      const row=rows[Number(item.set_index)-1],fields=row?.querySelectorAll('input');if(!fields?.length)continue;
      for(const [input,value] of [[fields[0],item.weight_lb],[fields[1],item.reps],[fields[2],item.rir]]){
        if(!input||value===null||value===undefined||String(input.value).trim()!=='')continue;
        input.value=String(value);
        input.dispatchEvent(new Event('input',{bubbles:true}));
        changed++;
      }
    }
    return changed;
  }
  function show(items,error=''){
    const panel=card();if(!panel)return;
    if(error){panel.innerHTML=`<strong>Apple Watch logs</strong><p class="tiny">${html(error)}</p><button class="btn" type="button" id="hcWatchRefresh">Refresh</button>`;}
    else {
      const summary=items.map(x=>`<div class="tiny" style="padding:3px 0">${html(x.exercise_name)} · ${x.weight_lb===null?'weight not recorded':html(x.weight_lb)+' lb'} × ${html(x.reps)} reps</div>`).join('');
      panel.innerHTML=`<strong>Apple Watch sets · ${items.length} saved</strong><p class="tiny">Wrist logs are backed up to Health Coach. Empty fields are imported automatically; existing weight/reps are never overwritten.</p>${summary||'<div class="tiny">No sets logged from your watch for this date.</div>'}<div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap"><button class="btn" id="hcWatchRefresh" type="button">Refresh watch logs</button><button class="btn" id="hcWatchApply" type="button">Import into empty sets</button></div>`;
    }
    panel.querySelector('#hcWatchRefresh')?.addEventListener('click',()=>schedule(20));
    panel.querySelector('#hcWatchApply')?.addEventListener('click',()=>{const c=applyToEmpty();if(c)show(latest)});
  }
  async function refresh(){
    const panel=card();if(!panel)return;
    const thisCall=++serial,day=date();
    if(!window.supabase?.createClient){schedule(3000);return}
    try{
      client=client||window.supabase.createClient(url,key,{auth:{persistSession:true,storageKey:auth,autoRefreshToken:true,detectSessionInUrl:false}});
      const {data:{session}}=await client.auth.getSession();
      if(thisCall!==serial||day!==date())return;
      if(!session?.user?.id){show([],'Connect Health Coach to Command Center to see your Apple Watch logs.');return}
      const {data,error}=await client.from('health_coach_watch_sets')
        .select('id,session_key,exercise_name,exercise_index,set_index,weight_lb,reps,rir')
        .eq('user_id',session.user.id).eq('workout_date',day)
        .order('completed_at',{ascending:true}).limit(120);
      if(error)throw error;
      if(thisCall!==serial||day!==date())return;
      latest=data||[];
      const sig=`${day}|${latest.map(x=>x.id).join(',')}`;
      if(sig!==lastSig){lastSig=sig;applyToEmpty();}
      show(latest);
    }catch(err){console.warn('Apple Watch log bridge unavailable',err);show([],'Watch logs could not be loaded. Try Refresh later.')}
  }
  function schedule(ms=300){clearTimeout(timer);timer=setTimeout(refresh,ms)}
  function start(){
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day')schedule(650)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.weekBtn,.tab[data-tab="workout"],#hcBackToday'))schedule(900)},true);
    window.addEventListener('focus',()=>schedule(250));
    setInterval(()=>schedule(300),90000);
    schedule(3200);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();