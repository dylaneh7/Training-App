const CACHE='hybrid-coach-v9-week44-sync';
const ASSETS=['./','./index.html','./manifest.webmanifest','./icon-180.png','./icon-512.png'];

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

async function withCloudLoader(resp){
  if(!resp)return resp;
  const type=resp.headers.get('content-type')||'';
  if(!type.includes('text/html'))return resp;
  let text=await resp.text();
  text=text.replace(/<script[^>]+src=["'][^"']*cc-sync(?:-v2)?\.js[^"']*["'][^>]*><\/script>\s*/gi,'');
  text=text.replace(/<script[^>]*data-hybrid-cloud-loader[^>]*>[\s\S]*?<\/script>\s*/gi,'');
  const loader=`<script data-hybrid-cloud-loader>setTimeout(function(){try{var s=document.createElement('script');s.src='./cc-sync-v2.js?v=9';s.async=true;document.body.appendChild(s)}catch(e){console.warn('Cloud sync loader failed',e)}},350);<\/script>`;
  text=text.replace('</body>',loader+'\n</body>');
  const headers=new Headers(resp.headers);
  headers.delete('content-length');headers.delete('content-encoding');headers.delete('etag');
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
        const page=await withCloudLoader(network);
        caches.open(CACHE).then(c=>c.put('./index.html',page.clone())).catch(()=>{});
        return page;
      }catch{
        return (await caches.match('./index.html')) || Response.error();
      }
    })());
    return;
  }

  e.respondWith((async()=>{
    try{
      const network=await fetch(e.request,{cache:'no-store'});
      if(network&&network.ok){caches.open(CACHE).then(c=>c.put(e.request,network.clone())).catch(()=>{})}
      return network;
    }catch{
      return (await caches.match(e.request)) || Response.error();
    }
  })());
});
