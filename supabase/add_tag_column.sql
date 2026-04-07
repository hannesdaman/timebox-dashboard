alter table public.sessions
add column if not exists tag text;

update public.sessions
set tag = 'Studying'
where tag is null or btrim(tag) = '';

alter table public.sessions
alter column tag set default 'Studying';

create index if not exists sessions_tag_idx
on public.sessions (tag);
