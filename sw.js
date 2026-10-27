const CACHE='hybrid-coach-v7-stable-load';
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
  text=text.replace('</body>','<script src="./cc-sync-v2.js?v=7"></script>\n</body>');
  const headers=new Headers(resp.headers);
  headers.delete('content-length');
  headers.delete('content-encoding');
  headers.delete('etag');
  return new Response(text,{status:resp.status,statusText:resp.statusText,headers});
}

self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET')return;
  const url=new URL(e.request.url);
  if(url.origin!==self.location.origin)return;

  if(e.request.mode==='navigate'){
    e.respondWith((async()=>{
      try{
        const network=await fetch(e.request,{cache:'no-store'});
        const injected=await withCommandCenterSync(network);
        const copy=injected.clone();
        caches.open(CACHE).then(c=>c.put('./index.html',copy)).catch(()=>{});
        return injected;
      }catch{
        return (await caches.match('./index.html')) || Response.error();
      }
    })());
    return;
  }

  e.respondWith((async()=>{
    try{
      const network=await fetch(e.request);
      if(network&&network.ok){const copy=network.clone();caches.open(CACHE).then(c=>c.put(e.request,copy)).catch(()=>{})}
      return network;
    }catch{
      return (await caches.match(e.request)) || Response.error();
    }
  })());
});