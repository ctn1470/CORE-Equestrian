import test from 'node:test';
import assert from 'node:assert/strict';
import {validateImport,historyRows,historicalAgenda,periodStats} from '../public/domain.js';
import {Store} from '../public/store.js';
const row={source_key:'source-1',date:'2026-10-13',horse_name:'Noor',activity:null,raw_text:'Texto original',outcome:'unknown'};
test('Importa incrementos de tamaño variable y conserva una actividad histórica vacía',()=>{
 assert.equal(validateImport([row])[0].activity,null);
 assert.equal(validateImport([{...row,activity:'Caminar'}])[0].activity,'Caminar');
 assert.equal(validateImport([{...row,activity:'D/nto'}])[0].activity,'D/nto');
 assert.throws(()=>validateImport([]));assert.throws(()=>validateImport([row,row]));
});
test('Un plan no puede hacerse pasar por ejecución y una ejecución debe tener estado',()=>{
 assert.throws(()=>validateImport([{...row,outcome:'done',record_kind:'plan'}]));
 assert.throws(()=>validateImport([{...row,record_kind:'execution'}]));
 assert.equal(validateImport([{...row,outcome:'done',record_kind:'execution'}])[0].outcome,'done');
});
test('Historial conserva cambios y distingue fuentes; dashboard solo cuenta ejecuciones',()=>{
 const data={activities:[],executions:[],history:[{...row,horse_id:'h',record_kind:'plan'},{...row,source_key:'change',horse_id:'h',record_kind:'revision',revision_keys:['source-1']},{...row,source_key:'excel',horse_id:'h',record_kind:'execution',source_system:'Excel MA Dressage',outcome:'done',activity:'Clase'}]};
 assert.equal(historyRows(data).length,3);
 assert.equal(historyRows(data).find(r=>r.source_key==='excel').source,'Histórico Excel Cristina');
 assert.equal(periodStats(data,row.date,row.date).real.length,1);
 assert.deepEqual(historicalAgenda(data,row.date).map(r=>r.source_key),['change']);
 data.activities.push({historical_source_key:'change'});assert.equal(historicalAgenda(data,row.date).length,0);
});
test('El paquete con nombres usa importación atómica y devuelve nuevos vs existentes',async()=>{
 const store=new Store({supabaseUrl:'https://test.supabase.co',supabaseKey:'public'});store.org='org';store.data={membership:{role:'admin'}};store.load=async()=>{};let request;
 store.request=async(path,args)=>{request={path,...args};return 1;};
 assert.deepEqual(await store.importHistory({format:'core-history-v2',records:[row]}),{inserted:1,total:1});
 assert.equal(request.path,'rpc/import_named_history');assert.equal(request.body.p_rows[0].horse_name,'Noor');
});
