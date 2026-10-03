import {demoData} from './demo.js';
import {validateActivity,validateExecution,validateImport} from './domain.js';
export class Store {
 constructor(config){this.config=config;this.demo=!config.supabaseUrl||!config.supabaseKey;this.session=null;this.org=null;this.data=null;this.refreshing=null;}
 async auth(path,body,method=body?'POST':'GET'){const r=await fetch(this.config.supabaseUrl+'/auth/v1/'+path,{method,headers:{apikey:this.config.supabaseKey,'Content-Type':'application/json',...(this.session?{Authorization:'Bearer '+this.session.access_token}:{})},...(body?{body:JSON.stringify(body)}:{})});const j=await r.json().catch(()=>({}));if(!r.ok)throw new Error(j.msg||j.error_description||'No se pudo iniciar sesión.');return j;}
 async acceptInvitation(fragment){if(this.demo)return false;const p=new URLSearchParams(fragment.replace(/^#/,''));if(p.has('error'))throw new Error('El enlace de acceso venció o no es válido. Solicita una nueva invitación.');if(!p.has('access_token'))return false;if(!p.get('refresh_token'))throw new Error('Enlace de acceso incompleto.');this.session={access_token:p.get('access_token'),refresh_token:p.get('refresh_token'),expires_at:Math.floor(Date.now()/1000)+Number(p.get('expires_in')||3600)};try{this.session.user=await this.auth('user');this.saveSession(this.session);if(['invite','recovery'].includes(p.get('type')))sessionStorage.setItem('core-needs-password','true');return true;}catch(error){this.session=null;sessionStorage.removeItem('core-auth');throw error;}}
 needsPassword(){return !this.demo&&sessionStorage.getItem('core-needs-password')==='true';}
 async setPassword(password){if(password.length<12)throw new Error('Usa al menos 12 caracteres.');await this.auth('user',{password},'PUT');sessionStorage.removeItem('core-needs-password');await this.load();}
 saveSession(s){this.session=s;sessionStorage.setItem('core-auth',JSON.stringify(s));}
 async restore(){if(this.demo){this.data=demoData();return true;}try{this.session=JSON.parse(sessionStorage.getItem('core-auth')||'null');if(!this.session)return false;await this.refresh();await this.auth('user');if(!this.needsPassword())await this.load();return true;}catch{this.session=null;sessionStorage.removeItem('core-auth');return false;}}
 async login(email,password){this.saveSession(await this.auth('token?grant_type=password',{email,password}));await this.load();}
 async logout(){if(!this.demo&&this.session){try{await this.auth('logout',{});}finally{this.session=null;this.data=null;sessionStorage.removeItem('core-auth');sessionStorage.removeItem('core-needs-password');}}}
 async refresh(){if(this.refreshing)return this.refreshing;this.refreshing=this.auth('token?grant_type=refresh_token',{refresh_token:this.session.refresh_token}).then(s=>this.saveSession(s)).finally(()=>this.refreshing=null);return this.refreshing;}
 async request(path,{method='GET',body,prefer,retry=true}={}) {
  if(this.session?.expires_at&&this.session.expires_at*1000<Date.now()+60000)await this.refresh();
  const r=await fetch(this.config.supabaseUrl+'/rest/v1/'+path,{method,headers:{apikey:this.config.supabaseKey,Authorization:'Bearer '+this.session.access_token,'Content-Type':'application/json',...(prefer?{Prefer:prefer}:{})},...(body!==undefined?{body:JSON.stringify(body)}:{})});
  if(r.status===401&&retry){await this.refresh();return this.request(path,{method,body,prefer,retry:false});}
  const text=await r.text();let data;try{data=text?JSON.parse(text):null;}catch{throw new Error('La respuesta del servicio no es válida.');}
  if(!r.ok)throw new Error(data?.message||'No fue posible guardar. Intenta de nuevo.');return data;
 }
 async all(table,filter=''){let rows=[],offset=0;while(true){const page=await this.request(`${table}?select=*&${filter}${filter?'&':''}order=id&limit=500&offset=${offset}`);rows.push(...page);if(page.length<500)return rows;offset+=500;}}
 async load(org){
  if(this.demo)return this.data;
  const memberships=await this.all('memberships','user_id=eq.'+encodeURIComponent(this.session.user.id));
  const organizations=await this.all('organizations');
  const member=memberships.find(m=>m.organization_id===(org||this.org))||memberships[0];
  if(!member)throw new Error('Tu cuenta aún no está vinculada a una organización. Solicita acceso a su administradora.');
  this.org=member.organization_id;const filter='organization_id=eq.'+encodeURIComponent(this.org);
  const [people,horses,activities,executions,history,health]=await Promise.all([this.all('people',filter),this.all('horses',filter),this.all('activities',filter),this.all('executions',filter),this.readHistory(),this.all('horse_health',filter)]);
  this.data={memberships,membership:member,organizations,people,horses,activities,executions,history,health};return this.data;
 }
 async readHistory(){let rows=[],offset=0;while(true){const page=await this.request(`rpc/read_history?order=id&limit=500&offset=${offset}`,{method:'POST',body:{p_org:this.org}});rows.push(...page);if(page.length<500)return rows;offset+=500;}}
 requireAdmin(){if(this.data.membership.role!=='admin')throw new Error('Solo las administradoras pueden realizar este cambio.');}
 async create(data,id){this.requireAdmin();data=validateActivity(data);if(data.activity==='Caminar de tiro'){data.person_id=this.data.people.find(p=>p.name==='Palafrenero')?.id;if(!data.person_id)throw new Error('Falta configurar el responsable Palafrenero.');data.trainer_id=null;}
  if(id&&this.data.executions.some(e=>e.activity_id===id))throw new Error('La actividad ya ejecutada conserva su programación.');
  if(this.demo){if(id){const plan=this.data.activities.find(a=>a.id===id);this.data.revisions??=[];this.data.revisions.push({before:{...plan},after:{...data}});Object.assign(plan,data);}else this.data.activities.push({...data,id:crypto.randomUUID()});return;}
  await this.request('activities'+(id?'?id=eq.'+encodeURIComponent(id):''),{method:id?'PATCH':'POST',body:{...data,...(!id?{organization_id:this.org,created_by:this.session.user.id}:{})},prefer:'return=representation'}).then(rows=>{if(id&&!rows?.length)throw new Error('No se pudo actualizar la programación.');});await this.load();
 }
 async execute(plan,data){this.requireAdmin();data=validateExecution(data);if(this.data.executions.some(e=>e.activity_id===plan.id))throw new Error('Esta actividad ya tiene una ejecución registrada.');
  if(this.demo){this.data.executions.push({...data,id:crypto.randomUUID(),activity_id:plan.id,executed_date:data.executed_date||plan.date});return;}
  await this.request('executions',{method:'POST',body:{...data,organization_id:this.org,activity_id:plan.id,created_by:this.session.user.id},prefer:'return=minimal'});await this.load();
 }
 async saveHorse(data,id){this.requireAdmin();if(!data.name?.trim())throw new Error('Escribe el nombre del caballo.');
  if(this.demo){if(id)Object.assign(this.data.horses.find(h=>h.id===id),data);else this.data.horses.push({...data,id:crypto.randomUUID()});return;}
  await this.request('horses'+(id?'?id=eq.'+encodeURIComponent(id):''),{method:id?'PATCH':'POST',body:{...data,...(!id?{organization_id:this.org}:{})},prefer:'return=minimal'});await this.load();
 }
 async saveHealth(data){this.requireAdmin();if(this.demo){this.data.health.push({...data,id:crypto.randomUUID()});return;}await this.request('horse_health',{method:'POST',body:{...data,organization_id:this.org,created_by:this.session.user.id},prefer:'return=minimal'});await this.load();}
 async importHistory(rows){this.requireAdmin();if(this.demo)throw new Error('La importación real estará disponible al conectar Supabase.');const clean=validateImport(rows);await this.request('rpc/import_history',{method:'POST',body:{p_org:this.org,p_rows:clean}});await this.load();}
}
