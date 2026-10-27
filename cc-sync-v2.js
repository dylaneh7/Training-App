(()=>{
  if(window.__hybridCoachCloudLoader)return;
  window.__hybridCoachCloudLoader=true;

  function loadCloud(){
    setTimeout(()=>{
      try{
        if(document.querySelector('script[data-hybrid-cloud-runtime]'))return;
        const s=document.createElement('script');
        s.src='./cc-cloud.js?v=1';
        s.async=true;
        s.dataset.hybridCloudRuntime='1';
        document.body.appendChild(s);
      }catch(err){
        console.warn('Hybrid Coach cloud loader failed',err);
      }
    },1200);
  }

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',loadCloud,{once:true});
  }else{
    loadCloud();
  }
})();
