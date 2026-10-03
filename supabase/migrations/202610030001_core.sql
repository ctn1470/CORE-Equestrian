-- Primera migración para un proyecto NUEVO de Supabase. No modifica el sitio piloto antiguo.
begin;
create type public.member_role as enum ('admin','rider','operations','owner');
create type public.activity_kind as enum ('Clase','Trabajo','Paseo','Cuerda','Caminador','Potrero','Caminar de tiro','Veterinario','Recuperación');
create table public.organizations (id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name))>0), created_at timestamptz not null default now());
create table public.people (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), name text not null check(length(trim(name))>0), unique(organization_id,id),unique(organization_id,name));
create table public.memberships (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),user_id uuid not null references auth.users(id),
 role public.member_role not null,person_id uuid,unique(organization_id,user_id),foreign key(organization_id,person_id) references public.people(organization_id,id),check(role<>'rider' or person_id is not null)
);
create table public.horses (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),name text not null check(length(trim(name))>0),
 status text not null default 'active' check(status in ('active','recovery','veterinary')),official_name text not null default '',birth_date date,
 owner text not null default '',owner_contact text not null default '',rider text not null default '',rider_contact text not null default '',passport text not null default '',
 level text not null default '',goal text not null default '',feeding text not null default '',supplements text not null default '',farrier text not null default '',veterinarian text not null default '',
 unique(organization_id,id),unique(organization_id,name),created_at timestamptz not null default now()
);
create table public.horse_access (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,user_id uuid not null,horse_id uuid not null,history_allowed boolean not null default false,health_allowed boolean not null default false,
 foreign key(organization_id,user_id) references public.memberships(organization_id,user_id),foreign key(organization_id,horse_id) references public.horses(organization_id,id),unique(organization_id,user_id,horse_id)
);
create table public.activities (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),horse_id uuid not null,date date not null,time time,
 activity public.activity_kind not null,person_id uuid not null,trainer_id uuid,location text not null default '',notes text not null default '',
 created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now(),unique(organization_id,id),
 foreign key(organization_id,horse_id) references public.horses(organization_id,id),foreign key(organization_id,person_id) references public.people(organization_id,id),foreign key(organization_id,trainer_id) references public.people(organization_id,id),
 check(trainer_id is null or activity='Clase')
);
create table public.executions (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,activity_id uuid not null unique,
 outcome text not null check(outcome in ('done','not_done')),activity public.activity_kind,person_id uuid,trainer_id uuid,duration integer check(duration between 1 and 1440),rating integer check(rating between 1 and 5),
 executed_date date not null,notes text not null default '',created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now(),
 foreign key(organization_id,activity_id) references public.activities(organization_id,id),foreign key(organization_id,person_id) references public.people(organization_id,id),foreign key(organization_id,trainer_id) references public.people(organization_id,id),
 check((outcome='done' and activity is not null and person_id is not null) or (outcome='not_done' and length(trim(notes))>0 and activity is null and person_id is null and trainer_id is null and duration is null and rating is null)),
 check(trainer_id is null or activity='Clase')
);
create table public.historical_records (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),source_key text not null,date date not null,time time,horse_id uuid not null,
 activity public.activity_kind not null,person_id uuid,trainer_id uuid,location text not null default '',notes text not null default '',rating integer check(rating between 1 and 5),duration integer check(duration between 1 and 1440),
 outcome text not null default 'unknown' check(outcome in ('done','not_done','unknown')),inferred boolean not null default false,raw_text text not null check(length(trim(raw_text))>0),
 imported_by uuid not null references auth.users(id),imported_at timestamptz not null default now(),unique(organization_id,source_key),
 foreign key(organization_id,horse_id) references public.horses(organization_id,id),foreign key(organization_id,person_id) references public.people(organization_id,id),foreign key(organization_id,trainer_id) references public.people(organization_id,id)
);
create table public.horse_health (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),horse_id uuid not null,date date not null,
 kind text not null check(kind in ('Veterinario','Tratamiento','Recuperación','Observación')),notes text not null check(length(trim(notes))>0),created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now(),
 foreign key(organization_id,horse_id) references public.horses(organization_id,id)
);
create index memberships_user on public.memberships(user_id,organization_id);
create index horse_access_user on public.horse_access(user_id,organization_id,horse_id);
create index activities_day on public.activities(organization_id,date,time);
create index activities_horse on public.activities(organization_id,horse_id,date);
create index historical_horse_date on public.historical_records(organization_id,horse_id,date);
create index executions_org on public.executions(organization_id,executed_date);
create index health_horse on public.horse_health(organization_id,horse_id,date);
create table public.activity_revisions (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,activity_id uuid not null,before_data jsonb not null,after_data jsonb not null,changed_by uuid not null references auth.users(id),changed_at timestamptz not null default now(),
 foreign key(organization_id,activity_id) references public.activities(organization_id,id)
);

create function public.is_org_admin(p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.memberships m where m.organization_id=p_org and m.user_id=auth.uid() and m.role='admin');
$$;
create function public.is_org_member(p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.memberships m where m.organization_id=p_org and m.user_id=auth.uid());
$$;
create function public.can_read_horse(p_org uuid,p_horse uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.memberships m where m.organization_id=p_org and m.user_id=auth.uid() and (m.role in ('admin','operations') or exists(select 1 from public.horse_access a where a.organization_id=p_org and a.horse_id=p_horse and a.user_id=auth.uid())));
$$;
create function public.can_read_activity(p_org uuid,p_horse uuid,p_person uuid,p_trainer uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.memberships m where m.organization_id=p_org and m.user_id=auth.uid() and (
 m.role in ('admin','operations') or (m.role='rider' and (m.person_id=p_person or m.person_id=p_trainer)) or (m.role='owner' and exists(select 1 from public.horse_access a where a.organization_id=p_org and a.horse_id=p_horse and a.user_id=auth.uid()))));
$$;
create function public.can_read_history(p_org uuid,p_horse uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.memberships m where m.organization_id=p_org and m.user_id=auth.uid() and (m.role='admin' or (m.role in ('rider','owner') and exists(select 1 from public.horse_access a where a.organization_id=p_org and a.horse_id=p_horse and a.user_id=auth.uid() and a.history_allowed))));
$$;
create function public.can_read_health(p_org uuid,p_horse uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.memberships m where m.organization_id=p_org and m.user_id=auth.uid() and (m.role='admin' or exists(select 1 from public.horse_access a where a.organization_id=p_org and a.horse_id=p_horse and a.user_id=auth.uid() and a.health_allowed)));
$$;
alter table public.organizations enable row level security;
alter table public.people enable row level security;
alter table public.memberships enable row level security;
alter table public.horses enable row level security;
alter table public.horse_access enable row level security;
alter table public.activities enable row level security;
alter table public.executions enable row level security;
alter table public.historical_records enable row level security;
alter table public.horse_health enable row level security;
alter table public.activity_revisions enable row level security;

create policy org_read on public.organizations for select to authenticated using(public.is_org_member(id));
create policy people_read on public.people for select to authenticated using(public.is_org_member(organization_id));
create policy member_read on public.memberships for select to authenticated using(user_id=auth.uid() or public.is_org_admin(organization_id));
create policy horse_read on public.horses for select to authenticated using(public.can_read_horse(organization_id,id));
create policy access_read on public.horse_access for select to authenticated using(user_id=auth.uid() or public.is_org_admin(organization_id));
create policy horse_insert on public.horses for insert to authenticated with check(public.is_org_admin(organization_id));
create policy horse_update on public.horses for update to authenticated using(public.is_org_admin(organization_id)) with check(public.is_org_admin(organization_id));
create policy activity_read on public.activities for select to authenticated using(public.can_read_activity(organization_id,horse_id,person_id,trainer_id));
create policy activity_insert on public.activities for insert to authenticated with check(public.is_org_admin(organization_id) and created_by=auth.uid());
create policy activity_update on public.activities for update to authenticated using(public.is_org_admin(organization_id)) with check(public.is_org_admin(organization_id));
create policy revision_read on public.activity_revisions for select to authenticated using(public.is_org_admin(organization_id));
create policy execution_read on public.executions for select to authenticated using(exists(select 1 from public.activities a where a.id=activity_id and a.organization_id=executions.organization_id and (public.is_org_admin(a.organization_id) or exists(select 1 from public.memberships m where m.user_id=auth.uid() and m.organization_id=a.organization_id and m.role='operations') or public.can_read_history(a.organization_id,a.horse_id))));
create policy execution_insert on public.executions for insert to authenticated with check(public.is_org_admin(organization_id) and created_by=auth.uid());
-- El texto original de WhatsApp puede mencionar otros caballos: acceso directo solo para administradoras.
create policy history_read on public.historical_records for select to authenticated using(public.is_org_admin(organization_id));
create policy health_read on public.horse_health for select to authenticated using(public.can_read_health(organization_id,horse_id));
create policy health_insert on public.horse_health for insert to authenticated with check(public.is_org_admin(organization_id) and created_by=auth.uid());

create function public.guard_walking() returns trigger language plpgsql set search_path='' as $$
begin
 if new.activity='Caminar de tiro' and not exists(select 1 from public.people p where p.id=new.person_id and p.organization_id=new.organization_id and p.name='Palafrenero') then raise exception 'Caminar de tiro requiere responsable Palafrenero';end if;
 return new;
end;$$;
create trigger validate_planned_walking before insert or update on public.activities for each row execute function public.guard_walking();
create trigger validate_executed_walking before insert or update on public.executions for each row execute function public.guard_walking();
create function public.immutable_record() returns trigger language plpgsql set search_path='' as $$begin raise exception 'Registro de solo lectura';end;$$;
create trigger history_immutable before update or delete on public.historical_records for each row execute function public.immutable_record();
create trigger execution_immutable before update or delete on public.executions for each row execute function public.immutable_record();
create function public.audit_plan() returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Bloqueo compartido con la creación de ejecución: evita carreras entre editar y ejecutar.
 perform pg_advisory_xact_lock(hashtextextended(old.id::text,0));
 if exists(select 1 from public.executions e where e.activity_id=old.id) then raise exception 'La actividad ya ejecutada conserva su programación';end if;
 insert into public.activity_revisions(organization_id,activity_id,before_data,after_data,changed_by) values(old.organization_id,old.id,to_jsonb(old),to_jsonb(new),auth.uid());
 return new;
end;$$;
create trigger activity_audit before update on public.activities for each row execute function public.audit_plan();
create function public.lock_execution_plan() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(new.activity_id::text,0));
 return new;
end;$$;
create trigger execution_lock before insert on public.executions for each row execute function public.lock_execution_plan();

create function public.read_history(p_org uuid) returns setof public.historical_records language sql stable security definer set search_path='' as $$
 select h.id,h.organization_id,h.source_key,h.date,h.time,h.horse_id,h.activity,h.person_id,h.trainer_id,h.location,h.notes,h.rating,h.duration,h.outcome,h.inferred,
 case when public.is_org_admin(p_org) then h.raw_text else null end as raw_text,h.imported_by,h.imported_at
 from public.historical_records h where h.organization_id=p_org and public.can_read_history(p_org,h.horse_id);
$$;

create function public.import_history(p_org uuid,p_rows jsonb) returns integer language plpgsql security definer set search_path='' as $$
declare inserted integer;
begin
 if not public.is_org_admin(p_org) then raise exception 'Acceso no autorizado';end if;
 if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)<>1605 then raise exception 'Se requieren exactamente 1605 registros';end if;
 if (select count(distinct r->>'source_key') from jsonb_array_elements(p_rows) r)<>1605 then raise exception 'Identificadores de origen vacíos o duplicados';end if;
 if exists(select 1 from jsonb_array_elements(p_rows) r where length(trim(coalesce(r->>'source_key','')))=0) then raise exception 'Identificador de origen obligatorio';end if;
 -- Una segunda importación debe ser idéntica. No sobrescribe el histórico.
 if exists(select 1 from jsonb_to_recordset(p_rows) as r(source_key text,date date,horse_id uuid,activity public.activity_kind,raw_text text,outcome text,inferred boolean,person_id uuid,trainer_id uuid,notes text,location text,time time,rating integer,duration integer)
 join public.historical_records h on h.organization_id=p_org and h.source_key=r.source_key
 where h.raw_text is distinct from r.raw_text or h.date is distinct from r.date or h.horse_id is distinct from r.horse_id or h.activity is distinct from r.activity or h.outcome is distinct from coalesce(r.outcome,'unknown') or h.inferred is distinct from coalesce(r.inferred,false)
 or h.person_id is distinct from r.person_id or h.trainer_id is distinct from r.trainer_id or h.notes is distinct from coalesce(r.notes,'') or h.location is distinct from coalesce(r.location,'') or h.time is distinct from r.time or h.rating is distinct from r.rating or h.duration is distinct from r.duration)
 then raise exception 'Hay identificadores existentes con datos distintos. Importación cancelada';end if;
 insert into public.historical_records(organization_id,source_key,date,time,horse_id,activity,person_id,trainer_id,notes,location,outcome,inferred,raw_text,rating,duration,imported_by)
 select p_org,r.source_key,r.date,r.time,r.horse_id,r.activity,r.person_id,r.trainer_id,coalesce(r.notes,''),coalesce(r.location,''),coalesce(r.outcome,'unknown'),coalesce(r.inferred,false),r.raw_text,r.rating,r.duration,auth.uid()
 from jsonb_to_recordset(p_rows) as r(source_key text,date date,time time,horse_id uuid,activity public.activity_kind,person_id uuid,trainer_id uuid,notes text,location text,outcome text,inferred boolean,raw_text text,rating integer,duration integer)
 on conflict(organization_id,source_key) do nothing;
 get diagnostics inserted=row_count;return inserted;
end;$$;

revoke all on public.organizations,public.people,public.memberships,public.horses,public.horse_access,public.activities,public.executions,public.historical_records,public.horse_health,public.activity_revisions from anon,authenticated;
grant select on public.organizations,public.people,public.memberships,public.horses,public.horse_access,public.activities,public.executions,public.historical_records,public.horse_health,public.activity_revisions to authenticated;
grant insert on public.horses,public.activities,public.executions,public.horse_health to authenticated;
grant update(horse_id,date,time,activity,person_id,trainer_id,location,notes) on public.activities to authenticated;
grant update(name,status,official_name,birth_date,owner,owner_contact,rider,rider_contact,passport,level,goal,feeding,supplements,farrier,veterinarian) on public.horses to authenticated;
revoke all on function public.is_org_admin(uuid),public.is_org_member(uuid),public.can_read_horse(uuid,uuid),public.can_read_activity(uuid,uuid,uuid,uuid),public.can_read_history(uuid,uuid),public.can_read_health(uuid,uuid),public.import_history(uuid,jsonb),public.read_history(uuid),public.guard_walking(),public.immutable_record() from public,anon;
revoke all on function public.audit_plan(),public.lock_execution_plan() from public,anon,authenticated;
grant execute on function public.is_org_admin(uuid),public.is_org_member(uuid),public.can_read_horse(uuid,uuid),public.can_read_activity(uuid,uuid,uuid,uuid),public.can_read_history(uuid,uuid),public.can_read_health(uuid,uuid),public.import_history(uuid,jsonb),public.read_history(uuid) to authenticated;
commit;
