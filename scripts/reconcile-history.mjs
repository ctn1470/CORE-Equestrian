import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {isDeepStrictEqual} from 'node:util';
import {fileURLToPath} from 'node:url';

export function reconcile(closed,increment){
  if(!Array.isArray(closed)||!closed.length)throw new Error('Falta la base cerrada: no se permite reconstruirla desde el incremento.');
  if(!Array.isArray(increment))throw new Error('El incremento debe ser un arreglo.');
  const index=new Map(),added=[],duplicates=[],conflicts=[];
  for(const row of closed){
    if(!row.source_key||index.has(row.source_key))throw new Error('La base cerrada contiene claves vacías o repetidas.');
    index.set(row.source_key,row);
  }
  for(const row of increment){
    if(!row.source_key)throw new Error('El incremento contiene una clave vacía.');
    const existing=index.get(row.source_key);
    if(existing){
      if(isDeepStrictEqual(existing,row))duplicates.push(row.source_key);
      else conflicts.push({source_key:row.source_key,closed:existing,incoming:row});
    }else{index.set(row.source_key,row);added.push(row);}
  }
  return {master:[...closed,...added],added,duplicates,conflicts};
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const [base,delta,output]=process.argv.slice(2);
  if(!base||!delta||!output)throw new Error('Uso: node scripts/reconcile-history.mjs base.json incremento.json salida');
  const result=reconcile(JSON.parse(await readFile(base,'utf8')),JSON.parse(await readFile(delta,'utf8')));
  const dir=resolve(output);await mkdir(dir);
  // Never emit an importable master while conflicting source keys remain.
  await writeFile(join(dir,'reconciliation.json'),JSON.stringify({added:result.added.length,duplicates:result.duplicates,conflicts:result.conflicts,status:result.conflicts.length?'blocked_conflicts':'reconciled'},null,2));
  if(result.conflicts.length)throw new Error('Conflictos detectados. Base maestra no emitida; revisar reconciliation.json.');
  await writeFile(join(dir,'master.json'),JSON.stringify(result.master,null,2));
  await writeFile(join(dir,'increment.json'),JSON.stringify(result.added,null,2));
}
