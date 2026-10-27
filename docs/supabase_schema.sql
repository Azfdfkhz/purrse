-- PurssApp 1.2.0 — rancangan skema Supabase (BELUM dipasang di aplikasi).
-- Jalankan di SQL Editor Supabase setelah keputusan arsitektur auth dibuat.
-- Prinsip: ID dibuat klien (uuid) -> upsert idempoten; hapus = tombstone;
-- konflik: last-write-wins berdasarkan updated_at (server menolak yang lebih lama).

create table if not exists public.categories (
  id          uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  color       bigint not null,
  icon_code   integer not null,
  icon_font   text,
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table if not exists public.expenses (
  id             uuid primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  category_id    uuid not null,
  amount_rupiah  bigint not null check (amount_rupiah > 0),
  spent_on       date not null,                 -- tanggal KEJADIAN (tanpa zona waktu)
  description    text not null default '',
  drive_file_id  text,                          -- referensi file foto di Google Drive
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index if not exists expenses_user_updated_idx on public.expenses (user_id, updated_at);
create index if not exists expenses_user_spent_idx   on public.expenses (user_id, spent_on);

alter table public.expenses   enable row level security;
alter table public.categories enable row level security;

create policy "expenses_owner_all" on public.expenses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "categories_owner_all" on public.categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Last-write-wins: tolak update dari klien yang datanya lebih lama.
create or replace function public.reject_stale_update() returns trigger as $$
begin
  if new.updated_at < old.updated_at then
    return old;
  end if;
  return new;
end; $$ language plpgsql;

create trigger expenses_lww before update on public.expenses
  for each row execute function public.reject_stale_update();
