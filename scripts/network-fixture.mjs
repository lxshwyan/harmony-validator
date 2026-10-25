import http from 'node:http';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

/** Loopback only. Cancellation is observed through premature response closure. */
export async function startNetworkFixture(port = 0) {
  const events = [];
  const listeners = new Set();
  const record = event => {events.push(event);for(const listener of [...listeners]) listener(event);};
  const server=http.createServer((req,res)=>{
    const url=new URL(req.url,'http://localhost');
    if(url.pathname==='/events') {res.setHeader('Content-Type','application/json');res.end(JSON.stringify(events));return;}
    if(url.pathname!=='/check'){res.writeHead(404).end();return;}
    const value=url.searchParams.get('value')||'';
    record({type:'received',value});
    if(value==='disconnect'){req.socket.destroy();return;}
    const delay=value.startsWith('slow-native-exit') ? 15000 : value.startsWith('slow') ? 1500 : 5;
    const timer=setTimeout(()=>{
      if(value==='error'){res.writeHead(503).end();return;}
      res.setHeader('Content-Type','application/json');
      res.end(JSON.stringify({available:value!=='taken'}));
      record({type:'completed',value});
    },delay);
    res.once('close',()=>{clearTimeout(timer);if(!res.writableEnded)record({type:'aborted',value});});
  });
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve);});
  const waitFor=(type,value)=>{
    const old=events.find(e=>e.type===type&&e.value===value);if(old)return Promise.resolve(old);
    return new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>{listeners.delete(listener);reject(new Error(`Missing server event ${type}:${value}`));},3000);
      const listener=event=>{if(event.type===type&&event.value===value){clearTimeout(timer);listeners.delete(listener);resolve(event);}};
      listeners.add(listener);
    });
  };
  return {events,waitFor,url:`http://127.0.0.1:${server.address().port}`,
    async close(){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const port=Number(process.argv[2]||18743);
  if(!Number.isInteger(port)||port<1||port>65535)throw new Error('Invalid local port');
  const fixture=await startNetworkFixture(port);console.log(`HTTP fixture listening ${fixture.url}`);
  const stop=async()=>{await fixture.close();process.exit(0);};
  process.once('SIGINT',stop);process.once('SIGTERM',stop);
}
