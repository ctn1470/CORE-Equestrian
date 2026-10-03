import test from 'node:test';
import assert from 'node:assert/strict';
import {Store} from '../public/store.js';
test('Invitación verifica usuario y exige contraseña antes de cargar organización',async()=>{
 const originalFetch=globalThis.fetch,originalStorage=globalThis.sessionStorage;
 const memory=new Map();globalThis.sessionStorage={setItem:(k,v)=>memory.set(k,v),getItem:k=>memory.get(k)||null,removeItem:k=>memory.delete(k)};
 const calls=[];globalThis.fetch=async(url,options)=>{calls.push({url,options});return {ok:true,json:async()=>({id:'test-user',email:'example@example.invalid'})};};
 try{const store=new Store({supabaseUrl:'https://example.invalid',supabaseKey:'test-public'});assert.equal(await store.acceptInvitation('#access_token=fixture&refresh_token=fixture-refresh&type=invite&expires_in=3600'),true);assert.equal(store.session.user.id,'test-user');assert.equal(store.needsPassword(),true);await assert.rejects(store.setPassword('short'),/12/);store.load=async()=>{};await store.setPassword('fixture-password-only');assert.equal(calls.at(-1).options.method,'PUT');assert.equal(store.needsPassword(),false);assert.equal(JSON.parse(calls.at(-1).options.body).password,'fixture-password-only');assert.equal(memory.get('core-auth').includes('fixture-password-only'),false);}finally{globalThis.fetch=originalFetch;globalThis.sessionStorage=originalStorage;}
});
test('Enlace vencido no crea sesión',async()=>{const store=new Store({supabaseUrl:'https://example.invalid',supabaseKey:'test-public'});await assert.rejects(store.acceptInvitation('#error=access_denied'),/venció/);assert.equal(store.session,null);});
