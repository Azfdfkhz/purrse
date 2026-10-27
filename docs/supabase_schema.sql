-- PurssApp 1.3.0 — skema Supabase (sinkronisasi + RLS + token FCM).
-- Jalankan SELURUHNYA di Supabase > SQL Editor. Aman dijalankan ulang.
--
-- Prinsip:
--  * ID dibuat klien (uuid) -> upsert idempoten.
--  * Hapus = tombstone (deleted_at), bukan DELETE.
--  * Konflik = last-write-wins per baris berdasarkan updated_at (jam klien).
--  * server_ts (jam server) dipakai klien sebagai kursor pull, sehingga
--    perangkat dengan jam salah tidak membuat perubahan terlewat.
--  * RLS: setiap baris hanya bisa dibaca/ditulis pemiliknya (auth.uid()).

-- ============================================================ tabel utama
create table if not exists public.categories (
  id          uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  color       bigint not null,
  icon_code   integer not null,
  icon_font   text,
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  server_ts   timestamptz not null default now()
);

create table if not exists public.expenses (
  id             uuid primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  category_id    uuid not null,
  amount_rupiah  bigint not null check (amount_rupiah >= 0),
  spent_on       date not null,                 -- tanggal KEJADIAN (tanpa zona waktu)
  description    text not null default '',
  drive_file_id  text,                          -- referensi foto di Google Drive
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  server_ts      timestamptz not null default now()
);

-- Untuk instalasi 1.2.x yang sudah punya tabel tanpa server_ts / dengan check lama:
alter table public.categories add column if not exists server_ts timestamptz not null default now();
alter table public.expenses   add column if not exists server_ts timestamptz not null default now();
alter table public.expenses   drop constraint if exists expenses_amount_rupiah_check;
alter table public.expenses   add  constraint expenses_amount_rupiah_check check (amount_rupiah >= 0);

create index if not exists expenses_user_ts_idx   on public.expenses   (user_id, server_ts);
create index if not exists categories_user_ts_idx on public.categories (user_id, server_ts);
create index if not exists expenses_user_spent_idx on public.expenses (user_id, spent_on);

-- ============================================================ LWW + server_ts
create or replace function public.sync_row_guard() returns trigger as $$
begin
  if tg_op = 'UPDATE' then
    -- Klien yang datanya lebih lama tidak boleh menimpa: abaikan update-nya.
    if new.updated_at < old.updated_at then
      return old;
    end if;
    -- Pemilik baris tidak boleh dipindahkan.
    new.user_id := old.user_id;
  end if;
  new.server_ts := now();
  return new;
end; $$ language plpgsql;

drop trigger if exists expenses_guard   on public.expenses;
drop trigger if exists expenses_lww     on public.expenses;
drop trigger if exists categories_guard on public.categories;
create trigger expenses_guard   before insert or update on public.expenses
  for each row execute function public.sync_row_guard();
create trigger categories_guard before insert or update on public.categories
  for each row execute function public.sync_row_guard();

-- ============================================================ RLS
alter table public.expenses   enable row level security;
alter table public.categories enable row level security;

drop policy if exists "expenses_owner_all"   on public.expenses;
drop policy if exists "categories_owner_all" on public.categories;
create policy "expenses_owner_all" on public.expenses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "categories_owner_all" on public.categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================ backup cloud (SupabaseService)
create table if not exists public.user_backups (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  email       text,
  backup_data jsonb,
  updated_at  timestamptz not null default now()
);
alter table public.user_backups enable row level security;
drop policy if exists "user_backups_owner_all" on public.user_backups;
create policy "user_backups_owner_all" on public.user_backups
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================ token FCM
create table if not exists public.device_tokens (
  token       text primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  platform    text not null,
  updated_at  timestamptz not null default now()
);
create index if not exists device_tokens_user_idx on public.device_tokens (user_id);
alter table public.device_tokens enable row level security;
drop policy if exists "device_tokens_owner_all" on public.device_tokens;
create policy "device_tokens_owner_all" on public.device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Satu perangkat bisa dipakai akun lain: token pindah ke pemilik terakhir.
-- SECURITY DEFINER agar bisa menimpa baris milik akun sebelumnya (yang tidak
-- terlihat oleh RLS), tetapi user_id selalu diisi dari auth.uid().
create or replace function public.register_device_token(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = auth.uid(), platform = excluded.platform, updated_at = now();
end; $$;
revoke all on function public.register_device_token(text, text) from public;
grant execute on function public.register_device_token(text, text) to authenticated;
