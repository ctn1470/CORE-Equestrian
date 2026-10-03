-- Ejecutar con un rol administrativo en el proyecto NUEVO / entorno de prueba.
-- Todas las filas de prueba se revierten al final. Cualquier fallo cancela la transacción.
begin;
create function pg_temp.assert_true(ok boolean,message text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'TEST FAILED: %',message;end if;end;$$;
create function pg_temp.expect_denied(query text) returns void language plpgsql as $$
begin
 begin execute query;exception when insufficient_privilege or foreign_key_violation or check_violation then return;end;
 raise exception 'TEST FAILED: operación permitida: %',query;
end;$$;
insert into auth.users(id,email) values
 ('40000000-0000-0000-0000-000000000001','core-test-admin-a@example.invalid'),
 ('40000000-0000-0000-0000-000000000002','core-test-admin-b@example.invalid'),
 ('40000000-0000-0000-0000-000000000003','core-test-rider@example.invalid'),
 ('40000000-0000-0000-0000-000000000004','core-test-owner@example.invalid'),
 ('40000000-0000-0000-0000-000000000005','core-test-operations@example.invalid');
insert into public.organizations(id,name) values('00000000-0000-0000-0000-000000000001','TEST A'),('00000000-0000-0000-0000-000000000002','TEST B');
insert into public.people(id,organization_id,name) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','TEST Rider'),
 ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','TEST Trainer'),
 ('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000002','TEST B Person');
insert into public.memberships(organization_id,user_id,role,person_id) values
 ('00000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','admin',null),
 ('00000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','admin',null),
 ('00000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','rider','10000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000004','owner',null),
 ('00000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000005','operations',null);
insert into public.horses(id,organization_id,name) values
 ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','TEST A HORSE 1'),
 ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','TEST A HORSE 2'),
 ('20000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000002','TEST B HORSE');
insert into public.horse_access(organization_id,user_id,horse_id,history_allowed) values
 ('00000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001',true),
 ('00000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001',true);
insert into public.activities(id,organization_id,horse_id,date,activity,person_id,created_by) values
 ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','2026-10-03','Clase','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','2026-10-03','Trabajo','10000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000003','2026-10-03','Trabajo','10000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000002');
insert into public.historical_records(organization_id,source_key,date,horse_id,activity,raw_text,imported_by) values
 ('00000000-0000-0000-0000-000000000001','fixture-a','2026-05-01','20000000-0000-0000-0000-000000000001','Clase','Texto completo con otros caballos','40000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002','fixture-b','2026-05-01','20000000-0000-0000-0000-000000000003','Trabajo','Texto B','40000000-0000-0000-0000-000000000002');

set local role authenticated;
set local request.jwt.claim.sub='40000000-0000-0000-0000-000000000001';
select pg_temp.assert_true((select count(*)=1 from public.organizations),'admin A no puede leer org B');
select pg_temp.assert_true((select count(*)=2 from public.horses),'admin A ve solo caballos A');
select pg_temp.assert_true((select count(*)=2 from public.activities),'admin A ve solo agenda A');
select pg_temp.expect_denied($q$insert into public.activities(organization_id,horse_id,date,activity,person_id) values('00000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000003','2026-10-03','Trabajo','10000000-0000-0000-0000-000000000003')$q$);
select pg_temp.expect_denied($q$insert into public.activities(organization_id,horse_id,date,activity,person_id) values('00000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000003','2026-10-03','Trabajo','10000000-0000-0000-0000-000000000001')$q$);
insert into public.executions(organization_id,activity_id,outcome,activity,person_id,executed_date) values('00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','done','Cuerda','10000000-0000-0000-0000-000000000002','2026-10-03');
select pg_temp.assert_true((select activity='Clase' from public.activities where id='30000000-0000-0000-0000-000000000001'),'ejecución no sobrescribe el plan');
select pg_temp.expect_denied($q$update public.historical_records set raw_text='reescrito'$q$);

set local request.jwt.claim.sub='40000000-0000-0000-0000-000000000003';
select pg_temp.assert_true((select count(*)=1 from public.horses),'rider solo caballo asignado');
select pg_temp.assert_true((select count(*)=1 from public.activities),'rider solo su agenda');
select pg_temp.expect_denied($q$insert into public.activities(organization_id,horse_id,date,activity,person_id) values('00000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','2026-10-03','Clase','10000000-0000-0000-0000-000000000001')$q$);

set local request.jwt.claim.sub='40000000-0000-0000-0000-000000000004';
select pg_temp.assert_true((select count(*)=1 from public.horses),'owner solo caballo autorizado');
select pg_temp.assert_true((select count(*)=0 from public.historical_records),'owner no accede directamente al texto original');
select pg_temp.assert_true((select count(*)=1 and bool_and(raw_text is null) from public.read_history('00000000-0000-0000-0000-000000000001')),'owner recibe histórico permitido sin texto original');
select pg_temp.assert_true((select count(*)=0 from public.read_history('00000000-0000-0000-0000-000000000002')),'RPC no filtra histórico de otra organización');
select pg_temp.assert_true((select count(*)=0 from public.horse_health),'salud no autorizada no visible');

set local request.jwt.claim.sub='40000000-0000-0000-0000-000000000005';
select pg_temp.assert_true((select count(*)=2 from public.activities),'operación consulta agenda completa de su org');
select pg_temp.expect_denied($q$insert into public.executions(organization_id,activity_id,outcome,notes,executed_date) values('00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002','not_done','TEST','2026-10-03')$q$);

reset role;
set local role anon;
select pg_temp.expect_denied('select * from public.horses');
reset role;
rollback;
