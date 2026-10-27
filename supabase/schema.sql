-- Run once in your Supabase project's SQL Editor (no paid features required).
create table if not exists public.greetings (
  id integer primary key check (id = 1),
  message text not null check (char_length(message) between 1 and 120)
);

alter table public.greetings enable row level security;

-- Visitors may read the hello-world greeting, but cannot change it.
revoke all on table public.greetings from anon, authenticated;
grant select on table public.greetings to anon, authenticated;

drop policy if exists "Public can read the greeting" on public.greetings;
create policy "Public can read the greeting"
  on public.greetings for select
  to anon, authenticated
  using (true);

insert into public.greetings (id, message)
values (1, 'Hello, world.')
on conflict (id) do nothing;
