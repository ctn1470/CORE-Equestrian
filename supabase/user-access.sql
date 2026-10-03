-- Ampliación de acceso por invitación para el proyecto CORE, sin datos de prueba.
begin;
create table core_private.user_invitations (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 email text not null check(email=lower(trim(email))), display_name text not null,
 role public.member_role not null, person_id uuid, horse_id uuid, history_allowed boolean not null default false, health_allowed boolean not null default false,
 invited_by uuid not null references auth.users(id), created_at timestamptz not null default now(), activated_at timestamptz,
 unique(organization_id,email), foreign key(organization_id,person_id) references public.people(organization_id,id),
 foreign key(organization_id,horse_id) references public.horses(organization_id,id), check(role<>'rider' or person_id is not null)
);
alter table core_private.user_invitations enable row level security;
create index invitations_email on core_private.user_invitations(email);
create index invitations_person on core_private.user_invitations(organization_id,person_id);
create index invitations_horse on core_private.user_invitations(organization_id,horse_id);
create index invitations_author on core_private.user_invitations(invited_by);
revoke all on core_private.user_invitations from public,anon,authenticated;

create function core_private.add_user_invitation(p_org uuid,p_email text,p_name text,p_role public.member_role,p_person uuid default null,p_horse uuid default null,p_history boolean default false,p_health boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare invite_id uuid; account uuid; normalized text:=lower(trim(p_email));
begin
 if auth.uid() is null or not core_private.is_org_admin(p_org) then raise exception 'Solo administradoras';end if;
 if normalized !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' or length(trim(p_name))=0 then raise exception 'Correo y nombre obligatorios';end if;
 if p_role='rider' and p_person is null then
  insert into public.people(organization_id,name) values(p_org,trim(p_name)) on conflict(organization_id,name) do update set name=excluded.name returning id into p_person;
 end if;
 if exists(select 1 from core_private.user_invitations where organization_id=p_org and email=normalized) then raise exception 'Este correo ya está invitado';end if;
 select id into account from auth.users where lower(email)=normalized;
 if account is not null and exists(select 1 from public.memberships where organization_id=p_org and user_id=account) then raise exception 'Este usuario ya tiene acceso';end if;
 insert into core_private.user_invitations(organization_id,email,display_name,role,person_id,horse_id,history_allowed,health_allowed,invited_by,activated_at)
 values(p_org,normalized,trim(p_name),p_role,p_person,p_horse,p_history,p_health,auth.uid(),case when account is not null then now() end) returning id into invite_id;
 if account is not null then
  insert into public.memberships(organization_id,user_id,role,person_id) values(p_org,account,p_role,p_person);
  if p_horse is not null then insert into public.horse_access(organization_id,user_id,horse_id,history_allowed,health_allowed) values(p_org,account,p_horse,p_history,p_health);end if;
 end if;
 return invite_id;
end;$$;

create function core_private.enroll_invited_user() returns trigger language plpgsql security definer set search_path='' as $$
declare invitation record; found_invite boolean:=false;
begin
 -- Solo correos autorizados por una administradora. Nunca confiar en user_metadata.
 for invitation in select * from core_private.user_invitations where email=lower(new.email) and activated_at is null for update loop
  found_invite:=true;
  insert into public.memberships(organization_id,user_id,role,person_id) values(invitation.organization_id,new.id,invitation.role,invitation.person_id);
  if invitation.horse_id is not null then insert into public.horse_access(organization_id,user_id,horse_id,history_allowed,health_allowed) values(invitation.organization_id,new.id,invitation.horse_id,invitation.history_allowed,invitation.health_allowed);end if;
  update core_private.user_invitations set activated_at=now() where id=invitation.id;
 end loop;
 if not found_invite then raise exception 'Correo no invitado a CORE Equestrian';end if;
 return new;
end;$$;
create trigger core_enroll_invitation after insert on auth.users for each row execute function core_private.enroll_invited_user();

create function core_private.list_org_users(p_org uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not core_private.is_org_admin(p_org) then raise exception 'Solo administradoras';end if;
 select coalesce(jsonb_agg(row_data order by row_data->>'email'),'[]'::jsonb) into result from (
  select jsonb_build_object('id',m.user_id,'email',u.email,'name',coalesce(p.name,i.display_name,''),'role',m.role,'person_id',m.person_id,'status',case when u.email_confirmed_at is null then 'pending' else 'active' end,'created_at',u.created_at,'last_sign_in_at',u.last_sign_in_at,'horses',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'name',h.name,'history_allowed',a.history_allowed,'health_allowed',a.health_allowed)) from public.horse_access a join public.horses h on h.id=a.horse_id where a.organization_id=p_org and a.user_id=m.user_id),'[]'::jsonb)) as row_data
  from public.memberships m join auth.users u on u.id=m.user_id left join public.people p on p.id=m.person_id left join core_private.user_invitations i on i.organization_id=m.organization_id and i.email=lower(u.email) where m.organization_id=p_org
  union all
  select jsonb_build_object('id',i.id,'email',i.email,'name',i.display_name,'role',i.role,'person_id',i.person_id,'status','invited','created_at',i.created_at,'last_sign_in_at',null,'horses','[]'::jsonb) from core_private.user_invitations i where i.organization_id=p_org and i.activated_at is null
 ) directory;
 return result;
end;$$;

create function public.add_user_invitation(p_org uuid,p_email text,p_name text,p_role public.member_role,p_person uuid default null,p_horse uuid default null,p_history boolean default false,p_health boolean default false) returns uuid language sql security invoker set search_path='' as $$select core_private.add_user_invitation(p_org,p_email,p_name,p_role,p_person,p_horse,p_history,p_health);$$;
create function public.list_org_users(p_org uuid) returns jsonb language sql stable security invoker set search_path='' as $$select core_private.list_org_users(p_org);$$;
revoke all on function core_private.enroll_invited_user() from public,anon,authenticated;
revoke all on function core_private.add_user_invitation(uuid,text,text,public.member_role,uuid,uuid,boolean,boolean),core_private.list_org_users(uuid),public.add_user_invitation(uuid,text,text,public.member_role,uuid,uuid,boolean,boolean),public.list_org_users(uuid) from public,anon;
grant execute on function core_private.add_user_invitation(uuid,text,text,public.member_role,uuid,uuid,boolean,boolean),core_private.list_org_users(uuid),public.add_user_invitation(uuid,text,text,public.member_role,uuid,uuid,boolean,boolean),public.list_org_users(uuid) to authenticated;
commit;
