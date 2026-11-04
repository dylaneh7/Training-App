(function recoveryAutoModule(){
  if(window.__hybridCoachRecoveryAuto)return;
  window.__hybridCoachRecoveryAuto=true;
  const URL='https://ecmosmmqloyahsdcxvpz.supabase.co';
  const KEY='sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ';
  const AUTH='hybrid-coach-command-center-auth';
  const OFFSETS={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6,RestWed:2,UpperThu:3,LegsFri:4};
  let client=null,timer=null,request=0,panelRef=null,retries=0;
  function dateISO(){
    const wi=Number(document.getElementById('week')?.value||0);
    const day=document.getElementById('day')?.value||'Mon';
    const d=new Date(2026,9,26,12);
    d.setDate(d.getDate()+wi*7+(OFFSETS[day]??0));
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  }
  function hms(sec){
    const n=Number(sec);
    if(!Number.isFinite(n)||n<=0)return '—';
    const total=Math.round(n/60);
    return `${Math.floor(total/60)}h ${String(total%60).padStart(2,'0')}m`;
  }
  function number(v){
    if(v===null||v===undefined||v==='')return null;
    const n=Number(v);
    return Number.isFinite(n)?n:null;
  }
  function styles(){
    if(document.getElementById('hcAutoRecoveryStyles'))return;
    const s=document.createElement('style');
    s.id='hcAutoRecoveryStyles';
    s.textContent=`
      .hc-recovery-manual-hidden{display:none!important}
      .hc-auto-recovery{padding:12px 13px;margin:12px 0;border:1px solid var(--border);border-radius:13px;background:var(--panel)}
      .hc-auto-recovery-head{display:flex;flex-wrap:wrap;gap:7px;align-items:baseline;justify-content:space-between}
      .hc-auto-recovery-head strong{font-size:13px}
      .hc-auto-recovery-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-top:10px}
      .hc-auto-recovery-cell{border:1px solid var(--border);border-radius:10px;background:var(--card);padding:9px}
      .hc-auto-recovery-cell .k{color:var(--muted);font-size:11px}
      .hc-auto-recovery-cell .v{font-size:19px;font-weight:750;margin-top:4px}
      .hc-auto-recovery-cell .tiny{font-size:10px;margin-top:4px}
      .hc-auto-recovery-foot{margin-top:9px;font-size:11px;color:var(--muted);line-height:1.5}
      @media(max-width:600px){.hc-auto-recovery-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
    `;
    document.head.appendChild(s);
  }
  function ensurePanel(){
    const root=document.getElementById('workout'),article=root?.querySelector('article.card');
    if(!article)return null;
    for(const guide of article.querySelectorAll('.guidebox')){
      const label=guide.querySelector(':scope > strong')?.textContent?.trim();
      if(label==='Daily recovery')guide.classList.add('hc-recovery-manual-hidden');
    }
    let panel=article.querySelector(':scope > .hc-auto-recovery');
    if(!panel){
      panel=document.createElement('div');
      panel.className='hc-auto-recovery';
      panel.setAttribute('aria-live','polite');
      const head=article.querySelector(':scope > .dayhead');
      head?head.insertAdjacentElement('afterend',panel):article.prepend(panel);
    }
    if(panelRef!==panel){panelRef=panel;panel.dataset.view='';}
    return panel;
  }
  function draw(markup,signature){
    const panel=ensurePanel();
    if(!panel)return;
    if(panel.dataset.view===signature)return;
    panel.dataset.view=signature;
    panel.innerHTML=markup;
  }
  function header(note){
    return `<div class="hc-auto-recovery-head"><strong>Recovery · Tredict</strong><span class="tiny">${note}</span></div>`;
  }
  function message(msg,tag){
    draw(`${header('Garmin-connected data')}<div class="hc-auto-recovery-foot">${msg}</div>`,`${dateISO()}|${tag}`);
  }
  function display(x,iso){
    if(!x){message('No recovery measurements are available for this date. Nothing to fill in.','none');return;}
    const sleep=hms(x.sleep_seconds),baseline=hms(x.sleep_baseline_seconds);
    const hrv=number(x.hrv_ms),hrvBaseline=number(x.hrv_baseline_ms),low=number(x.daily_low_hr_bpm);
    const hrText=hrv===null?'—':`${Math.round(hrv)} ms`;
    const lowText=low===null?'—':`${Math.round(low)} bpm`;
    const sleepBase=baseline==='—'?'Baseline unavailable':`Typical sleep: ${baseline}`;
    const hrvBase=hrvBaseline===null?'Baseline unavailable':`14-day baseline: ${Math.round(hrvBaseline)} ms`;
    const html=`${header(iso)}<div class="hc-auto-recovery-grid">
      <div class="hc-auto-recovery-cell"><div class="k">Sleep recorded</div><div class="v">${sleep}</div><div class="tiny">${sleepBase}</div></div>
      <div class="hc-auto-recovery-cell"><div class="k">Overnight HRV</div><div class="v">${hrText}</div><div class="tiny">${hrvBase}</div></div>
      <div class="hc-auto-recovery-cell"><div class="k">Daily lowest HR</div><div class="v">${lowText}</div><div class="tiny">Not the same as resting HR</div></div>
      </div><div class="hc-auto-recovery-foot">Automatically synced from Tredict where available. No manual check-in or calculated readiness score; Garmin cannot measure soreness, motivation or pain.</div>`;
    draw(html,`${iso}|${x.synced_at}|${sleep}|${hrText}|${lowText}`);
  }
  async function load(){
    const panel=ensurePanel();
    if(!panel)return;
    const iso=dateISO(),token=++request;
    if(!client){
      if(!window.supabase?.createClient){
        message('Preparing automatic recovery sync. No entry is needed.','sdk');
        if(retries++<12)schedule(1200);
        return;
      }
      client=window.supabase.createClient(URL,KEY,{auth:{persistSession:true,storageKey:AUTH,autoRefreshToken:true,detectSessionInUrl:false}});
    }
    try{
      const {data:sessionData,error:sessionError}=await client.auth.getSession();
      if(token!==request||iso!==dateISO())return;
      if(sessionError)throw sessionError;
      if(!sessionData?.session?.user){message('Connect Command Center to view your Garmin/Tredict recovery measurements. No form to complete.','connect');return;}
      const userId=sessionData.session.user.id;
      const {data,error}=await client.from('recovery_daily_metrics')
        .select('metric_date,sleep_seconds,sleep_baseline_seconds,hrv_ms,hrv_baseline_ms,daily_low_hr_bpm,synced_at')
        .eq('user_id',userId).eq('metric_date',iso).maybeSingle();
      if(error)throw error;
      if(token!==request||iso!==dateISO())return;
      display(data,iso);
    }catch(err){
      console.warn('Recovery metrics could not be loaded',err);
      message('Recovery sync is unavailable right now. No manual entries required.','error');
    }
  }
  function schedule(ms=300){clearTimeout(timer);timer=setTimeout(load,ms);}
  function start(){
    styles();
    const root=document.getElementById('workout');
    if(root){
      new MutationObserver(()=>{
        const old=panelRef,newPanel=ensurePanel();
        if(newPanel!==old)schedule(350);
      }).observe(root,{childList:true,subtree:true});
    }
    document.addEventListener('change',e=>{if(e.target?.id==='week'||e.target?.id==='day')schedule(320)},true);
    document.addEventListener('click',e=>{if(e.target?.closest?.('.weekBtn,.tab[data-tab="workout"]'))schedule(400)},true);
    window.addEventListener('focus',()=>schedule(200));
    document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')schedule(200)});
    setInterval(()=>schedule(400),300000);
    schedule(2100);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
