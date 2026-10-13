import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,join} from 'node:path';

const [input,output]=process.argv.slice(2);
if(!input||!output)throw new Error('Uso: node scripts/stage-whatsapp.mjs archivo.txt directorio-salida');
const bytes=await readFile(input),text=bytes.toString('utf8');
const hash=value=>createHash('sha256').update(value).digest('hex');
// Preserve exact source slices, including multiline messages and invisible marks.
const header=/^[\u200e\u200f]?\[(\d{1,2})\/(\d{1,2})\/(\d{2,4}), ([^\]]+)\] ([^\r\n]*?):/gm;
const matches=[...text.matchAll(header)],seen=new Map();
const messages=matches.map((m,i)=>{
  const raw=text.slice(m.index,matches[i+1]?.index??text.length);
  const date=`${m[3].length===2?'20'+m[3]:m[3]}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`;
  const fingerprint=hash(raw.replace(/\r\n/g,'\n').replace(/\n+$/,''));
  const occurrence=(seen.get(fingerprint)??0)+1;seen.set(fingerprint,occurrence);
  return {message_key:`wa-message-v1:${fingerprint}:${occurrence}`,message_date:date,source_time:m[4],sender:m[5],line_start:text.slice(0,m.index).split('\n').length,raw_text:raw,body:raw.slice(m[0].length),status:'uninterpreted'};
});
if(!messages.length)throw new Error('No se reconocieron encabezados; no se generó una base vacía.');
const selected=messages.filter(m=>m.message_date>='2026-05-01');
const dir=resolve(output);await mkdir(dir,{recursive:true});
await writeFile(join(dir,'whatsapp-original.txt'),bytes);
await writeFile(join(dir,'messages.json'),JSON.stringify(selected,null,2));
const manifest={status:'staged_not_consolidated',source_sha256:hash(bytes),total_messages:messages.length,messages_from_may:selected.length,first_message_date:selected[0]?.message_date,last_message_date:selected.at(-1)?.message_date,preamble:text.slice(0,matches[0].index),required_inputs:['Historico cerrado con identificadores y punto de corte','Reglas aprobadas, aliases, binomios y correcciones manuales'],notes:['Las fechas son fechas de mensaje, no fechas de actividad.','No se infieren actividades, ejecuciones ni responsables.','El identificador de mensaje no sustituye la clave histórica existente.','Cada actividad requerirá su propia clave dentro del mensaje; no deduplicar por fecha y caballo.','Ningún registro preparado aquí está aprobado para importar.']};
await writeFile(join(dir,'manifest.json'),JSON.stringify(manifest,null,2));
console.log(JSON.stringify(manifest,null,2));
