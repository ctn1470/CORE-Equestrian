import {cp,mkdir,writeFile} from 'node:fs/promises';
const url=process.env.SUPABASE_URL||'',key=process.env.SUPABASE_PUBLISHABLE_KEY||'';
if((url&&!key)||(!url&&key))throw new Error('Configura ambos valores públicos de Supabase.');
if(key.startsWith('sb_secret_'))throw new Error('No publiques una clave secreta.');
if(key.includes('.')){try{const payload=JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString());if(payload.role!=='anon')throw new Error('Solo se permite una clave anon pública.');}catch(e){throw new Error('Clave pública JWT no válida: '+e.message);}}
if(url&&!/^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/.test(url))throw new Error('URL de Supabase no válida.');
await mkdir('dist',{recursive:true});await cp('public','dist',{recursive:true});
await writeFile('dist/config.js','window.CORE_CONFIG = '+JSON.stringify({supabaseUrl:url.replace(/\/$/,''),supabaseKey:key})+';\n');
console.log(url?'Aplicación preparada para Supabase.':'Aplicación de demostración preparada. Falta conectar Supabase.');
