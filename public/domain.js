export const ACTIVITIES = ['Clase','Trabajo','Paseo','Cuerda','Caminador','Potrero','Caminar de tiro','Veterinario','Recuperación'];
export const TEAM = ['Mariana','Cristina','Tata','Juan','Antonia','Alicia','Palafrenero'];
export const OPERATIONAL = ['Caminador','Potrero','Caminar de tiro','Veterinario','Recuperación'];
export function normalizeActivity(value) {
  const name=String(value??'').trim();
  if(name.toLowerCase()==='caminar') return 'Paseo';
  if(name.toLowerCase()==='soltar') return 'Potrero';
  return ACTIVITIES.find(a=>a.toLowerCase()===name.toLowerCase())??name;
}
export function today() { return new Intl.DateTimeFormat('en-CA',{timeZone:'America/Bogota',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date()); }
export function shiftDate(date, days) { const d=new Date(date+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+days);return d.toISOString().slice(0,10); }
export function dateLabel(date, short=false) {return new Intl.DateTimeFormat('es-CO',{timeZone:'UTC',...(short?{day:'numeric',month:'short'}:{weekday:'long',day:'numeric',month:'long'})}).format(new Date(date+'T12:00:00Z'));}
export function validateActivity(data) {
  if(!data.horse_id) throw new Error('Selecciona un caballo.');
  if(!/^\d{4}-\d{2}-\d{2}$/.test(data.date??'') || Number.isNaN(Date.parse(data.date+'T12:00:00Z')) || new Date(data.date+'T12:00:00Z').toISOString().slice(0,10)!==data.date) throw new Error('Selecciona una fecha válida.');
  const activity=normalizeActivity(data.activity);
  if(!ACTIVITIES.includes(activity))throw new Error('Selecciona una actividad válida.');
  if(!data.person_id && activity!=='Caminar de tiro')throw new Error(activity==='Clase'?'Selecciona el alumno de la clase.':'Selecciona un responsable.');
  if(data.time && !/^([01]\d|2[0-3]):[0-5]\d$/.test(data.time))throw new Error('La hora debe tener formato HH:MM.');
  return {...data,activity,time:data.time||null,trainer_id:data.trainer_id||null,notes:String(data.notes??'').trim()};
}
export function validateExecution(data) {
  if(!['done','not_done'].includes(data.outcome))throw new Error('Indica si se realizó.');
  if(data.outcome==='not_done') {if(!String(data.notes??'').trim())throw new Error('Indica por qué no se realizó.');return {...data,activity:null,person_id:null,trainer_id:null,duration:null,rating:null};}
  const activity=normalizeActivity(data.activity);
  if(!ACTIVITIES.includes(activity)||!data.person_id)throw new Error('Selecciona actividad y responsable ejecutados.');
  const duration=data.duration===''||data.duration==null?null:Number(data.duration);
  const rating=data.rating===''||data.rating==null?null:Number(data.rating);
  if(duration!==null&&(!Number.isInteger(duration)||duration<1||duration>1440))throw new Error('La duración debe ser de 1 a 1440 minutos.');
  if(rating!==null&&(!Number.isInteger(rating)||rating<1||rating>5))throw new Error('La calificación debe ser de 1 a 5.');
  return {...data,activity,duration,rating,trainer_id:data.trainer_id||null};
}
export function isChanged(plan, execution) {return execution?.outcome==='done'&&(plan.activity!==execution.activity||plan.person_id!==execution.person_id||(plan.trainer_id??null)!==(execution.trainer_id??null));}
export function historyRows(data) {
  const plans=new Map(data.activities.map(a=>[a.id,a]));
  return [...data.executions.map(e=>{const p=plans.get(e.activity_id);return p?{...p,...e,id:e.id,plan:p,source:'CORE Equestrian',date:e.executed_date??p.date}:null;}).filter(Boolean),...data.history.map(h=>({...h,source:'Histórico WhatsApp',readonly:true}))].sort((a,b)=>b.date.localeCompare(a.date));
}
export function periodStats(data,from,to) {
  const plans=data.activities.filter(p=>p.date>=from&&p.date<=to),ids=new Set(plans.map(p=>p.id));
  const executions=data.executions.filter(e=>ids.has(e.activity_id));
  const done=executions.filter(e=>e.outcome==='done');
  const modified=done.filter(e=>isChanged(plans.find(p=>p.id===e.activity_id),e)).length;
  const real=historyRows(data).filter(e=>e.date>=from&&e.date<=to&&e.outcome==='done');
  return {plans:plans.length,done:done.length,notDone:executions.filter(e=>e.outcome==='not_done').length,pending:plans.length-executions.length,modified,percent:plans.length?Math.round(done.length/plans.length*100):null,real};
}
export function validateImport(rows,expected=1605) {
  if(!Array.isArray(rows)||rows.length!==expected)throw new Error(`Se esperan ${expected} registros; recibidos ${rows?.length??0}.`);
  const keys=new Set();
  return rows.map((r,i)=>{
    if(!r.source_key||keys.has(r.source_key))throw new Error(`Fila ${i+1}: identificador de origen vacío o duplicado.`);keys.add(r.source_key);
    if(!r.horse_id||!r.date||!r.raw_text)throw new Error(`Fila ${i+1}: faltan caballo, fecha o texto original.`);
    const activity=normalizeActivity(r.activity);if(!ACTIVITIES.includes(activity))throw new Error(`Fila ${i+1}: actividad no reconocida.`);
    if(!['done','not_done','unknown'].includes(r.outcome??'unknown'))throw new Error(`Fila ${i+1}: estado no válido.`);
    if(Number.isNaN(Date.parse(r.date+'T12:00:00Z'))||new Date(r.date+'T12:00:00Z').toISOString().slice(0,10)!==r.date)throw new Error(`Fila ${i+1}: fecha no válida.`);
    return {...r,activity,outcome:r.outcome??'unknown',inferred:!!r.inferred};
  });
}
