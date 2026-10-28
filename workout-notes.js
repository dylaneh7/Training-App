(()=>{
  if(window.__hybridCoachWorkoutNotes)return;
  window.__hybridCoachWorkoutNotes=true;

  const NOTES_KEY='hybridCoachWorkoutNotes_v1';
  const MARKER='COACH NOTES / CHANGE REQUESTS';

  function readStore(){
    try{
      const raw=localStorage.getItem(NOTES_KEY);
      const parsed=raw?JSON.parse(raw):null;
      if(parsed&&parsed.days)return parsed;
    }catch(e){}
    return {version:1,days:{}};
  }

  function writeStore(store){
    try{localStorage.setItem(NOTES_KEY,JSON.stringify(store))}catch(e){}
  }

  function currentKey(){
    const week=document.getElementById('week');
    const day=document.getElementById('day');
    return week&&day?`${week.value}-${day.value}`:null;
  }

  function ensureDay(store,key){
    if(!store.days[key])store.days[key]={workout:'',exercises:{}};
    if(!store.days[key].exercises)store.days[key].exercises={};
    return store.days[key];
  }

  function injectStyle(){
    if(document.getElementById('hybridCoachNotesStyle'))return;
    const style=document.createElement('style');
    style.id='hybridCoachNotesStyle';
    style.textContent=`
      .coach-note-btn{min-height:40px;border:1px solid var(--border);background:var(--panel);color:var(--text);border-radius:9px;padding:0 10px;white-space:nowrap}
      .coach-note-btn.has-note{border-color:#5f89c3;color:var(--accent)}
      .coach-note-panel{margin-top:8px;padding:10px;border:1px solid #34445a;border-radius:10px;background:#111923}
      .coach-note-panel textarea{min-height:82px;line-height:1.4}
      .coach-note-actions{display:flex;gap:7px;align-items:center;justify-content:space-between;margin-bottom:7px}
      .coach-note-title{font-size:12px;font-weight:700;color:var(--accent)}
      .coach-note-daily{margin-top:10px;border:1px solid var(--border);border-radius:11px;background:var(--panel);overflow:hidden}
      .coach-note-daily>button{width:100%;min-height:44px;padding:0 11px;border:0;background:transparent;color:var(--text);display:flex;align-items:center;justify-content:space-between;text-align:left}
      .coach-note-daily .coach-note-panel{margin:0;border:0;border-top:1px solid var(--border);border-radius:0}
      .coach-note-hint{font-size:11px;color:var(--muted);line-height:1.35}
      @media(max-width:520px){.coach-note-btn{padding:0 8px;font-size:12px}}
    `;
    document.head.appendChild(style);
  }

  function makePanel(value,onInput,placeholder){
    const panel=document.createElement('div');
    panel.className='coach-note-panel';
    panel.hidden=true;

    const head=document.createElement('div');
    head.className='coach-note-actions';
    head.innerHTML='<span class="coach-note-title">Note for your coach</span><span class="coach-note-hint">Autosaves</span>';

    const ta=document.createElement('textarea');
    ta.value=value||'';
    ta.placeholder=placeholder;
    ta.setAttribute('aria-label','Coach note');
    ta.addEventListener('input',()=>onInput(ta.value));

    const hint=document.createElement('div');
    hint.className='coach-note-hint';
    hint.style.marginTop='6px';
    hint.textContent='Use this for form cues, a set that felt different, equipment changes, pain/discomfort, or something you want changed next time.';

    panel.append(head,ta,hint);
    return panel;
  }

  function enhanceDailyNote(){
    const root=document.getElementById('workout');
    const article=root?.querySelector('article.card');
    if(!article||article.querySelector('.coach-note-daily'))return;
    const key=currentKey();
    if(!key)return;

    const store=readStore();
    const d=ensureDay(store,key);
    const wrap=document.createElement('div');
    wrap.className='coach-note-daily';

    const btn=document.createElement('button');
    btn.type='button';
    const refreshLabel=()=>{
      const has=(d.workout||'').trim();
      btn.innerHTML=`<span><strong>Workout notes for coach</strong><br><span class="coach-note-hint">Overall session changes, questions, or reminders</span></span><span>${has?'● ':''}▾</span>`;
    };
    refreshLabel();

    const panel=makePanel(d.workout||'',value=>{
      const s=readStore();
      ensureDay(s,key).workout=value;
      writeStore(s);
      d.workout=value;
      refreshLabel();
    },'Example: Bench felt strong, but move close-grip bench later next time. Left shoulder was tight on the final press set.');

    btn.addEventListener('click',()=>{
      panel.hidden=!panel.hidden;
      const arrow=panel.hidden?'▾':'▴';
      const span=btn.lastElementChild;
      if(span)span.textContent=`${(d.workout||'').trim()?'● ':''}${arrow}`;
      if(!panel.hidden)setTimeout(()=>panel.querySelector('textarea')?.focus(),0);
    });

    wrap.append(btn,panel);
    const recovery=article.querySelector('.guidebox');
    if(recovery)recovery.insertAdjacentElement('afterend',wrap);
    else article.prepend(wrap);
  }

  function enhanceExercises(){
    const key=currentKey();
    if(!key)return;
    const store=readStore();
    const d=ensureDay(store,key);
    const boxes=[...document.querySelectorAll('#exercises .exercise')];

    boxes.forEach((box,ei)=>{
      if(box.dataset.coachNotesReady==='1')return;
      box.dataset.coachNotesReady='1';
      const head=box.querySelector('.exhead');
      if(!head)return;
      const choice=box.querySelector('.choice');
      const saved=d.exercises?.[ei];

      const btn=document.createElement('button');
      btn.type='button';
      btn.className='coach-note-btn';
      const refresh=()=>{
        const s=readStore().days?.[key]?.exercises?.[ei];
        const has=!!(s?.text||'').trim();
        btn.classList.toggle('has-note',has);
        btn.textContent=has?'Notes ●':'Notes';
      };
      refresh();

      const panel=makePanel(saved?.text||'',value=>{
        const s=readStore();
        const day=ensureDay(s,key);
        day.exercises[ei]={exercise:choice?.value||saved?.exercise||`Exercise ${ei+1}`,text:value};
        writeStore(s);
        refresh();
      },'Example: Set 3 felt unstable at 185 lb. Try a slightly narrower grip next time, or change this exercise/set setup.');

      btn.addEventListener('click',()=>{
        panel.hidden=!panel.hidden;
        btn.textContent=panel.hidden?((panel.querySelector('textarea')?.value||'').trim()?'Notes ●':'Notes'):'Hide notes';
        if(!panel.hidden)setTimeout(()=>panel.querySelector('textarea')?.focus(),0);
      });

      choice?.addEventListener('change',()=>{
        const s=readStore();
        const day=ensureDay(s,key);
        const existing=day.exercises[ei];
        if(existing){existing.exercise=choice.value;writeStore(s)}
      });

      const how=head.querySelector('.howbtn');
      if(how)head.insertBefore(btn,how);
      else head.appendChild(btn);
      box.appendChild(panel);
    });
  }

  function enhance(){
    injectStyle();
    enhanceDailyNote();
    enhanceExercises();
  }

  function noteSectionText(){
    const store=readStore();
    const lines=[];
    Object.entries(store.days||{}).sort().forEach(([key,d])=>{
      const hasWorkout=!!(d.workout||'').trim();
      const ex=Object.values(d.exercises||{}).filter(v=>(v?.text||'').trim());
      if(!hasWorkout&&!ex.length)return;
      const [wi,day]=key.split('-');
      lines.push(`Week ${Number(wi)+1} — ${day}`);
      if(hasWorkout)lines.push(`  Workout note: ${d.workout.trim()}`);
      ex.forEach((n,i)=>lines.push(`  ${n.exercise||`Exercise ${i+1}`}: ${n.text.trim()}`));
      lines.push('');
    });
    if(!lines.length)return'';
    return `${MARKER}\n${lines.join('\n').trim()}`;
  }

  function decorateCoachText(){
    const ta=document.getElementById('coachText');
    if(!ta)return;
    let base=ta.value||'';
    const idx=base.indexOf(`\n\n${MARKER}`);
    if(idx>=0)base=base.slice(0,idx);
    const section=noteSectionText();
    ta.value=section?`${base.trimEnd()}\n\n${section}`:base;
  }

  function hookCoachShare(){
    const build=document.getElementById('buildCoach');
    const share=document.getElementById('shareCoach');
    const copy=document.getElementById('copyCoach');
    if(!build||!share||!copy||build.dataset.coachNotesHooked==='1')return;
    build.dataset.coachNotesHooked='1';

    const originalBuild=build.onclick;
    const originalShare=share.onclick;
    const originalCopy=copy.onclick;

    build.onclick=e=>{
      if(originalBuild)originalBuild.call(build,e);
      decorateCoachText();
    };
    share.onclick=e=>{
      const ta=document.getElementById('coachText');
      if(!ta?.value.trim()&&originalBuild)originalBuild.call(build,e);
      decorateCoachText();
      if(originalShare)return originalShare.call(share,e);
    };
    copy.onclick=e=>{
      const ta=document.getElementById('coachText');
      if(!ta?.value.trim()&&originalBuild)originalBuild.call(build,e);
      decorateCoachText();
      if(originalCopy)return originalCopy.call(copy,e);
    };
  }

  function hookBackup(){
    const make=document.getElementById('makeBackup');
    const restore=document.getElementById('restoreBackup');
    const ta=document.getElementById('backupText');
    if(!make||!restore||!ta||make.dataset.coachNotesHooked==='1')return;
    make.dataset.coachNotesHooked='1';
    const originalMake=make.onclick;
    const originalRestore=restore.onclick;

    make.onclick=e=>{
      if(originalMake)originalMake.call(make,e);
      try{
        const obj=JSON.parse(ta.value);
        obj.workoutNotes=readStore();
        ta.value=JSON.stringify(obj);
      }catch(err){}
    };

    restore.onclick=e=>{
      let notes=null;
      try{notes=JSON.parse(ta.value)?.workoutNotes||null}catch(err){}
      if(originalRestore)originalRestore.call(restore,e);
      if(notes?.days){writeStore(notes);setTimeout(enhance,20)}
    };
  }

  function start(){
    enhance();
    hookCoachShare();
    hookBackup();

    const root=document.getElementById('workout');
    if(root){
      const mo=new MutationObserver(()=>setTimeout(enhance,0));
      mo.observe(root,{childList:true,subtree:true});
    }
    document.addEventListener('change',e=>{
      if(e.target?.id==='week'||e.target?.id==='day')setTimeout(enhance,25);
    },true);
    document.addEventListener('click',e=>{
      if(e.target?.closest?.('.weekBtn'))setTimeout(enhance,60);
    },true);
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(start,50),{once:true});
  else setTimeout(start,50);
})();
