(()=>{
  if(window.__healthCoachNativePlanPublisher)return;
  window.__healthCoachNativePlanPublisher=true;

  const url='https://ecmosmmqloyahsdcxvpz.supabase.co';
  const publishable='sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ';
  const storageKey='hybrid-coach-command-center-auth';
  const offset={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6,RestWed:2,UpperThu:3,LegsFri:4,SatUpper:5};
  let client=null,timer=null,busy=false,lastSuccess='',lastAttempt='';
  const clean=x=>String(x||'').trim();
  function isoDate(){
    const week=Number(document.getElementById('week')?.value||0);
    const day=document.getElementById('day')?.value||'Mon';
    const d=new Date(2026,9,26,12);
    d.setDate(d.getDate()+week*7+(offset[day]??0));
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  }
  const original={
    SatUpper:['Flat barbell bench press','Neutral-grip lat pulldown','Incline dumbbell press','Seated Row','Seated dumbbell shoulder press','Cable lateral raise','Reverse pec deck','Rope pressdown','Hammer curl'],
    Mon:['Flat barbell bench press','Incline dumbbell press','Weighted dip — chest bias','Seated dumbbell shoulder press','Chest-supported lateral raise','Standing lateral raise','Single-arm cable rear-delt fly','Close-grip bench press','Overhead cable triceps extension','Rope pressdown','Push-up plus'],
    Tue:['Weighted pull-up / neutral pulldown','Chest-supported T-bar row','Single-arm cable lat row — elbow to hip','Wide high row','Straight-arm cable pulldown','Dumbbell shrug','Cable Y-raise','Reverse pec deck','Face pull with external rotation','Incline dumbbell curl','Preacher curl','Hammer curl','Reverse EZ-bar curl','Farmer carry'],
    Wed:['Paused bench press','Low-to-high cable fly','Neutral-grip pulldown','Chest-supported machine row','Cable lateral raise','Cable rear-delt fly','Rope pressdown','Cable curl','Cable external rotation'],
    Thu:['Back squat / hack squat','Romanian deadlift','Leg press','Bulgarian split squat','Leg extension','Seated leg curl','Hip thrust','Standing calf raise','Seated soleus raise','Cable crunch / ab wheel']
  };
  const normalized=x=>clean(x).toLowerCase().replace(/[—–]/g,'-').replace(/\s+/g,' ');
  function extract(){
    const week=document.getElementById('week')?.value,day=document.getElementById('day')?.value;
    const box=document.getElementById('workout'),holder=box?.querySelector('#exercises');
    if(!week||!day||!holder)return null;
    const date=isoDate();
    const base=day==='UpperThu'?'Wed':day==='LegsFri'?'Thu':day;
    const names=original[base]||original[day]||[];
    const visible=[...holder.querySelectorAll(':scope > .exercise')].filter(n=>n.style.display!=='none');
    if(!visible.length)return null;
    const exercises=[];
    for(const card of visible){
      const selector=card.querySelector('.choice');
      const originalName=clean(card.dataset.hcOriginalId||card.dataset.hcId||selector?.options?.[0]?.value||selector?.options?.[0]?.textContent||card.querySelector('.hc-custom-name')?.textContent);
      const name=clean(selector?.value||card.querySelector('.hc-custom-name')?.textContent||originalName);
      if(!name)continue;
      const index=names.findIndex(n=>normalized(n)===normalized(originalName));
      const sourceID=originalName||name;
      const extra=card.classList.contains('hc-custom-exercise');
      const rawMeta=card.querySelector('.hc-custom-meta,.exmain .tiny')?.textContent||'';
      const range=rawMeta.match(/×\s*(\d+)\s*[–-]\s*(\d+)/)||rawMeta.match(/×\s*(\d+)/);
      const lower=range?Number(range[1]):8,upper=range?Number(range[2]||range[1]):12;
      const rows=[...card.querySelectorAll(':scope > .setrow:not(.head)')].filter(r=>!r.classList.contains('hc-set-hidden')&&r.style.display!=='none');
      const first=rows[0]?.querySelector('input');
      const load=first&&clean(first.value)!==''?Number(first.value):null;
      exercises.push({
        id:extra?`custom-${sourceID}`:`${week}-${day}-${index>=0?index:exercises.length}`,
        name,
        originalName:sourceID,
        exerciseIndex:index>=0?index:Math.min(40,25+exercises.length),
        prescribedSets:Math.max(1,rows.length),
        repMin:Math.max(1,lower),
        repMax:Math.max(lower,upper),
        suggestedWeightLb:Number.isFinite(load)?load:null,
        restSeconds:/bench|squat|deadlift|press|row|pulldown/i.test(name)?150:75
      });
    }
    if(!exercises.length)return null;
    const title=clean(box.querySelector('.dayhead h2')?.textContent)||'Strength Workout';
    return {
      id:`${date}-${week}-${day}`,
      date,
      sessionKey:`${week}-${day}`,
      title,
      exercises,
      isPreview:false
    };
  }
  async function publish(){
    if(busy)return;
    const plan=extract();if(!plan)return;
    const signature=JSON.stringify(plan);
    if(signature===lastSuccess||signature===lastAttempt)return;
    if(!window.supabase?.createClient)return;
    busy=true;lastAttempt=signature;
    try{
      client=client||window.supabase.createClient(url,publishable,{auth:{
        persistSession:true,storageKey,autoRefreshToken:true,detectSessionInUrl:false
      }});
      const {data:{session},error:authError}=await client.auth.getSession();
      if(authError)throw authError;
      if(!session?.user?.id){lastAttempt='';return;}
      const {error}=await client.from('health_coach_native_plans').upsert({
        user_id:session.user.id,workout_date:plan.date,plan,updated_at:new Date().toISOString()
      },{onConflict:'user_id,workout_date'});
      if(error)throw error;
      lastSuccess=signature;
    }catch(error){
      console.warn('Health Coach watch-plan publish unavailable',error);
      lastAttempt='';
    }finally{busy=false}
  }
  function schedule(ms=1100){clearTimeout(timer);timer=setTimeout(publish,ms)}
  function start(){
    document.addEventListener('change',e=>{
      if(e.target?.closest?.('#week,#day,#exercises'))schedule(1300);
    },true);
    document.addEventListener('input',e=>{
      if(e.target?.closest?.('#exercises'))schedule(1800);
    },true);
    document.addEventListener('click',e=>{
      if(e.target?.closest?.('.weekBtn,.tab,#hcBackToday,#hcOverviewToday,#hcOpenNextWorkout'))schedule(2000);
    },true);
    const root=document.getElementById('exercises')?.parentElement||document.getElementById('workout');
    root?.addEventListener('hc:set-editor-change',()=>schedule(1000));
    setInterval(()=>schedule(1200),180000);
    window.addEventListener('focus',()=>schedule(1200));
    schedule(2600);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
  else start();
})();