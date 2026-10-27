const CACHE='hybrid-coach-v6-week44-cloud-runs';
const ASSETS=['./','./index.html','./manifest.webmanifest','./icon-180.png','./icon-512.png','./cc-sync-v2.js'];

self.addEventListener('install',e=>{
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)));
});

self.addEventListener('activate',e=>{
  e.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
  );
});

async function withCommandCenterSync(resp){
  if(!resp)return resp;
  const type=resp.headers.get('content-type')||'';
  if(!type.includes('text/html'))return resp;
  let text=await resp.text();
  text=text.replace(/<script[^>]+src=["'][^"']*cc-sync(?:-v2)?\.js[^"']*["'][^>]*><\/script>\s*/gi,'');
  text=text.replace('</body>','<script src="./cc-sync-v2.js?v=6"></script>\n</body>');
  return new Response(text,{status:resp.status,statusText:resp.statusText,headers:resp.headers});
}

self.addEventListener('fetch',e=>{
  if(e.request.mode==='navigate'){
    e.respondWith((async()=>{
      try{
        const network=await fetch(e.request);
        const injected=await withCommandCenterSync(network);
        const copy=injected.clone();
        caches.open(CACHE).then(c=>c.put('./index.html',copy));
        return injected;
      }catch{
        return caches.match('./index.html');
      }
    })());
    return;
  }

  e.respondWith(
    caches.match(e.request).then(cached=>{
      const fetchPromise=fetch(e.request).then(resp=>{
        const copy=resp.clone();
        caches.open(CACHE).then(c=>c.put(e.request,copy));
        return resp;
      }).catch(()=>cached);
      return cached||fetchPromise;
    })
  );
});