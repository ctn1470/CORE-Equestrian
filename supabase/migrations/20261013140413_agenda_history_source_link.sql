alter table public.activities add column historical_source_key text;
alter table public.activities add constraint activities_historical_source_unique unique(organization_id,historical_source_key);
alter table public.activities add constraint activities_historical_source_fk foreign key(organization_id,historical_source_key) references public.historical_records(organization_id,source_key);
