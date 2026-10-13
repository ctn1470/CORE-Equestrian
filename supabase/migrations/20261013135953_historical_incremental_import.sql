-- Incremental historical imports preserve source identity and frozen corrections.
alter type public.activity_kind add value if not exists 'Caminar';
alter type public.activity_kind add value if not exists 'Clínica';
alter type public.activity_kind add value if not exists 'Odontología';
alter type public.activity_kind add value if not exists 'Fisio';
alter type public.activity_kind add value if not exists 'Concurso';
alter type public.activity_kind add value if not exists 'D/nto';
alter table public.historical_records alter column activity drop not null;
alter table public.historical_records add column record_kind text not null default 'plan' check(record_kind in ('plan','execution','revision'));
alter table public.historical_records add column source_system text not null default 'WhatsApp';
alter table public.historical_records add column revision_keys text[] not null default '{}';
alter table public.historical_records add constraint history_kind_outcome check((record_kind='execution' and outcome in ('done','not_done')) or (record_kind in ('plan','revision') and outcome='unknown'));
create or replace function core_private.import_history(p_org uuid,p_rows jsonb) returns integer language plpgsql security definer set search_path='' as $$
declare inserted integer;
begin
 if not core_private.is_org_admin(p_org) then raise exception 'Acceso no autorizado';end if;
 if jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'Se requiere un arreglo JSON';end if;
 if jsonb_array_length(p_rows) not between 1 and 5000 then raise exception 'Importa entre 1 y 5000 registros';end if;
 perform pg_advisory_xact_lock(hashtextextended('history-import:'||p_org::text,0));
 if (select count(distinct r->>'source_key') from jsonb_array_elements(p_rows) r)<>jsonb_array_length(p_rows) then raise exception 'Identificadores de origen vacíos o duplicados';end if;
 if exists(select 1 from jsonb_array_elements(p_rows) r where length(trim(coalesce(r->>'source_key','')))=0) then raise exception 'Identificador de origen obligatorio';end if;
 -- Una segunda importación debe ser idéntica. No sobrescribe el histórico.
 if exists(select 1 from jsonb_to_recordset(p_rows) as r(source_key text,date date,horse_id uuid,activity public.activity_kind,raw_text text,outcome text,inferred boolean,person_id uuid,trainer_id uuid,notes text,location text,time time,rating integer,duration integer,record_kind text,source_system text,revision_keys text[])
 join public.historical_records h on h.organization_id=p_org and h.source_key=r.source_key
 where h.raw_text is distinct from r.raw_text or h.date is distinct from r.date or h.horse_id is distinct from r.horse_id or h.activity is distinct from r.activity or h.outcome is distinct from coalesce(r.outcome,'unknown') or h.inferred is distinct from coalesce(r.inferred,false)
 or h.person_id is distinct from r.person_id or h.trainer_id is distinct from r.trainer_id or h.notes is distinct from coalesce(r.notes,'') or h.location is distinct from coalesce(r.location,'') or h.time is distinct from r.time or h.rating is distinct from r.rating or h.duration is distinct from r.duration or h.record_kind is distinct from coalesce(r.record_kind,case when coalesce(r.outcome,'unknown')='unknown' then 'plan' else 'execution' end) or h.source_system is distinct from coalesce(r.source_system,'WhatsApp') or h.revision_keys is distinct from coalesce(r.revision_keys,'{}'::text[]))
 then raise exception 'Hay identificadores existentes con datos distintos. Importación cancelada';end if;
 insert into public.historical_records(organization_id,source_key,date,time,horse_id,activity,person_id,trainer_id,notes,location,outcome,inferred,raw_text,rating,duration,imported_by,record_kind,source_system,revision_keys)
 select p_org,r.source_key,r.date,r.time,r.horse_id,r.activity,r.person_id,r.trainer_id,coalesce(r.notes,''),coalesce(r.location,''),coalesce(r.outcome,'unknown'),coalesce(r.inferred,false),r.raw_text,r.rating,r.duration,auth.uid(),coalesce(r.record_kind,case when coalesce(r.outcome,'unknown')='unknown' then 'plan' else 'execution' end),coalesce(r.source_system,'WhatsApp'),coalesce(r.revision_keys,'{}'::text[])
 from jsonb_to_recordset(p_rows) as r(source_key text,date date,time time,horse_id uuid,activity public.activity_kind,person_id uuid,trainer_id uuid,notes text,location text,outcome text,inferred boolean,raw_text text,rating integer,duration integer,record_kind text,source_system text,revision_keys text[])
 on conflict(organization_id,source_key) do nothing;
 get diagnostics inserted=row_count;return inserted;
end;$$;

create or replace function core_private.read_history(p_org uuid) returns setof public.historical_records language sql stable security definer set search_path='' as $$
 select h.id,h.organization_id,h.source_key,h.date,h.time,h.horse_id,h.activity,h.person_id,h.trainer_id,h.location,h.notes,h.rating,h.duration,h.outcome,h.inferred,
 case when core_private.is_org_admin(p_org) then h.raw_text else null end,h.imported_by,h.imported_at,h.record_kind,h.source_system,h.revision_keys
 from public.historical_records h where h.organization_id=p_org and core_private.can_read_history(p_org,h.horse_id);
$$;

-- Catalog creation and the import share one transaction. No user accounts are created.
create function core_private.import_named_history(p_org uuid,p_rows jsonb) returns integer language plpgsql security definer set search_path='' as $$
declare resolved jsonb;
begin
 if auth.uid() is null or not core_private.is_org_admin(p_org) then raise exception 'Acceso no autorizado';end if;
 if jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'Se requiere un arreglo JSON';end if;
 if jsonb_array_length(p_rows) not between 1 and 5000 then raise exception 'Importa entre 1 y 5000 registros';end if;
 if exists(select 1 from jsonb_array_elements(p_rows) r where length(trim(coalesce(r->>'horse_name','')))=0) then raise exception 'Caballo obligatorio';end if;
 perform pg_advisory_xact_lock(hashtextextended('history-import:'||p_org::text,0));
 insert into public.horses(organization_id,name) select distinct p_org,trim(r->>'horse_name') from jsonb_array_elements(p_rows) r on conflict(organization_id,name) do nothing;
 insert into public.people(organization_id,name)
 select distinct p_org,trim(value) from (
  select r->>'person_name' value from jsonb_array_elements(p_rows) r
  union select r->>'trainer_name' from jsonb_array_elements(p_rows) r
 ) names where length(trim(coalesce(value,'')))>0 on conflict(organization_id,name) do nothing;
 select jsonb_agg((r - 'horse_name' - 'person_name' - 'trainer_name') || jsonb_build_object('horse_id',h.id,'person_id',p.id,'trainer_id',t.id) order by ord)
 into resolved from jsonb_array_elements(p_rows) with ordinality src(r,ord)
 join public.horses h on h.organization_id=p_org and h.name=trim(r->>'horse_name')
 left join public.people p on p.organization_id=p_org and p.name=trim(r->>'person_name')
 left join public.people t on t.organization_id=p_org and t.name=trim(r->>'trainer_name');
 return core_private.import_history(p_org,resolved);
end;$$;
revoke all on function core_private.import_named_history(uuid,jsonb) from public,anon;
grant execute on function core_private.import_named_history(uuid,jsonb) to authenticated;
create function public.import_named_history(p_org uuid,p_rows jsonb) returns integer language sql security invoker set search_path='' as $$ select core_private.import_named_history(p_org,p_rows); $$;
revoke all on function public.import_named_history(uuid,jsonb) from public,anon;
grant execute on function public.import_named_history(uuid,jsonb) to authenticated;
