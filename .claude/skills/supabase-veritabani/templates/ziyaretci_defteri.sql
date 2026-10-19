create table public.mesajlar (
  id bigint generated always as identity primary key,
  isim text not null check (char_length(isim) between 1 and 60),
  mesaj text not null check (char_length(mesaj) between 1 and 500),
  created_at timestamptz not null default now()
);

alter table public.mesajlar enable row level security;

create policy "herkes okuyabilir"
  on public.mesajlar for select
  to anon, authenticated
  using (true);

create policy "herkes ekleyebilir"
  on public.mesajlar for insert
  to anon, authenticated
  with check (true);
