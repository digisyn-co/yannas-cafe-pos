-- ============================================================================
-- Yanna's Cafe — Server-side manager PIN for voids
-- Run in Supabase → SQL Editor (paste whole, Run once). Safe to re-run.
--
-- This moves the void password OUT of the app's code. The PIN is stored hashed,
-- and the POS verifies it through a database function — the password is never
-- shipped to the browser.
-- ============================================================================

create extension if not exists pgcrypto;

-- Settings table (locked down: no direct access; only the function below reads it).
create table if not exists public.app_settings (
  key   text primary key,
  value text
);
alter table public.app_settings enable row level security;
-- (No policies on purpose → anon/authenticated cannot read or write it directly.)

-- Seed the manager PIN (hashed). Keeps the current value so nothing breaks.
insert into public.app_settings (key, value)
  values ('manager_pin', crypt('walapassword', gen_salt('bf')))
  on conflict (key) do nothing;

-- Verification function. Runs with elevated rights so it can read the hash,
-- but only ever returns true/false — never the PIN itself.
create or replace function public.verify_manager_pin(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare stored text;
begin
  select value into stored from public.app_settings where key = 'manager_pin';
  if stored is null then return false; end if;
  return crypt(p_pin, stored) = stored;
end;
$$;

revoke all on function public.verify_manager_pin(text) from public, anon;
grant execute on function public.verify_manager_pin(text) to authenticated;

-- ----------------------------------------------------------------------------
-- TO CHANGE THE MANAGER PIN later, run this (replace NEW_PIN_HERE):
--   update public.app_settings
--     set value = crypt('NEW_PIN_HERE', gen_salt('bf'))
--     where key = 'manager_pin';
-- ----------------------------------------------------------------------------

-- After this runs, the POS verifies voids through verify_manager_pin() and the
-- password no longer needs to live in the app code.
