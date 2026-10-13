-- Reversible integration checks. No fixture survives the rollback.
begin;
create function pg_temp.assert_true(ok boolean,message text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'TEST FAILED: %',message;end if;end;$$;
select set_config('test.history_org',gen_random_uuid()::text,true);
select set_config('test.history_other_org',gen_random_uuid()::text,true);
select set_config('test.history_user',gen_random_uuid()::text,true);
insert into public.organizations(id,name) values(current_setting('test.history_org')::uuid,'TEST import history'),(current_setting('test.history_other_org')::uuid,'TEST other org');
insert into core_private.user_invitations(organization_id,email,display_name,role,invited_by)
select current_setting('test.history_org')::uuid,current_setting('test.history_user')||'@example.invalid','TEST import','admin',(select user_id from public.memberships where role='admin' limit 1);
insert into auth.users(id,email) values(current_setting('test.history_user')::uuid,current_setting('test.history_user')||'@example.invalid');
select set_config('request.jwt.claim.sub',current_setting('test.history_user'),true);
set local role authenticated;
do $$
declare org uuid:=current_setting('test.history_org')::uuid; rows jsonb:='[{"source_key":"test-first","date":"2026-10-13","horse_name":"TEST Noor","activity":null,"raw_text":"Source","record_kind":"plan","outcome":"unknown"}]'; n integer;
begin
 n:=public.import_named_history(org,rows);perform pg_temp.assert_true(n=1,'one new row');
 n:=public.import_named_history(org,rows);perform pg_temp.assert_true(n=0,'identical reimport is idempotent');
 perform pg_temp.assert_true((select activity is null from public.read_history(org) where source_key='test-first'),'unspecified activity preserved');
 begin
  perform public.import_named_history(org,jsonb_set(rows,'{0,raw_text}','"Changed"'));
  raise exception 'TEST FAILED: changed source accepted';
 exception when raise_exception then if sqlerrm not like '%Importación cancelada%' then raise;end if;end;
 begin
  perform public.import_named_history(current_setting('test.history_other_org')::uuid,rows);
  raise exception 'TEST FAILED: wrong org accepted';
 exception when raise_exception then if sqlerrm<>'Acceso no autorizado' then raise;end if;end;
 begin
  perform public.import_named_history(org,rows||jsonb_set(rows,'{0,horse_name}','"TEST Rollback horse"'));
  raise exception 'TEST FAILED: duplicate keys accepted';
 exception when raise_exception then if sqlerrm not like '%duplicados%' then raise;end if;end;
 perform pg_temp.assert_true(not exists(select 1 from public.horses where organization_id=org and name='TEST Rollback horse'),'failed batch rolls back catalogs');
end;$$;
reset role;
rollback;
