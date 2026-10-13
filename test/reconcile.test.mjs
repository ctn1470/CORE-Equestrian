import test from 'node:test';
import assert from 'node:assert/strict';
import {reconcile} from '../scripts/reconcile-history.mjs';
const row={source_key:'closed-1',date:'2026-05-01',horse_id:'h',activity:'Trabajo',notes:'Corrección manual',outcome:'unknown'};
test('Conserva correcciones y varias actividades del mismo caballo y fecha',()=>{
 const base=[{...row}],copy=structuredClone(base);
 const result=reconcile(base,[{...row},{...row,source_key:'new-2',activity:'Cuerda'}]);
 assert.deepEqual(base,copy);assert.deepEqual(result.master[0],row);assert.equal(result.added.length,1);assert.equal(result.duplicates.length,1);
});
test('Cambios bajo una clave existente son conflictos, nunca sobrescrituras',()=>{
 const result=reconcile([row],[{...row,notes:'Otra interpretación'}]);
 assert.equal(result.conflicts.length,1);assert.deepEqual(result.master,[row]);
});
test('Reimportación es idempotente y exige una base cerrada válida',()=>{
 const added={...row,source_key:'new-2'};
 const first=reconcile([row],[added]);assert.equal(reconcile(first.master,[added]).added.length,0);
 assert.throws(()=>reconcile([],[]));assert.throws(()=>reconcile([row,row],[]));
});
