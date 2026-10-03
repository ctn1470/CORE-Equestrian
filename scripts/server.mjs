import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
const base=resolve(fileURLToPath(new URL('../public/',import.meta.url)));
const port=Number(process.env.PORT||4173);
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml'};
http.createServer(async(req,res)=>{try{const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);const file=resolve(base,'.'+(pathname==='/'?'/index.html':pathname));if(file!==base&&!file.startsWith(base+sep)){res.writeHead(403);return res.end();}const bytes=await readFile(file);res.writeHead(200,{'Content-Type':mime[extname(file)]||'application/octet-stream','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'strict-origin-when-cross-origin'});res.end(bytes);}catch{res.writeHead(404);res.end('No encontrado');}}).listen(port,'127.0.0.1',()=>console.log(`CORE Equestrian disponible en http://127.0.0.1:${port}`));
