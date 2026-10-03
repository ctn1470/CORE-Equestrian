-- Ejecutar después de la migración y de invitar a Cristina / Mariana en Supabase Auth.
-- Sustituir los correos de ejemplo por los reales. No inventar cuentas o contraseñas.
begin;
do $$
declare org uuid;person uuid;account uuid;admin_email text;admin_name text;
begin
 if exists(select 1 from public.organizations where name='MA Dressage') then raise exception 'MA Dressage ya existe: no repetir bootstrap';end if;
 insert into public.organizations(name) values('MA Dressage') returning id into org;
 insert into public.people(organization_id,name) select org,unnest(array['Mariana','Cristina','Tata','Juan','Antonia','Alicia','Palafrenero']);
 for admin_name,admin_email in select * from (values('Cristina','REEMPLAZAR_CORREO_CRISTINA'),('Mariana','REEMPLAZAR_CORREO_MARIANA')) as admins(name,email) loop
  select id into account from auth.users where lower(email)=lower(admin_email);
  if account is null then raise exception 'Invitar primero a % en Auth y sustituir su correo',admin_name;end if;
  select id into person from public.people where organization_id=org and name=admin_name;
  insert into public.memberships(organization_id,user_id,role,person_id) values(org,account,'admin',person);
 end loop;
end;$$;
commit;
