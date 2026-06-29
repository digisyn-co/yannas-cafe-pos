-- ============================================================================
-- Yanna's Cafe — Supabase security & data-integrity setup
-- Run this in Supabase → SQL Editor (project dgjtpxdbztnokfbmfjbw).
-- Safe to run more than once (idempotent). Read the NOTES before Phase 2.
--
-- WHO IS WHO:
--   • Staff (POS) log in with Supabase Auth  -> role "authenticated"
--   • Customers (order app) are not logged in -> role "anon"
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PHASE 1 — Safe to run now. Locks down the database and fixes the
--           "orders won't save" issue if it was caused by RLS being on with
--           no write policy.
-- ----------------------------------------------------------------------------

-- 1a. ORDERS: only logged-in staff can read or write.
alter table public.orders enable row level security;
drop policy if exists orders_staff_all on public.orders;
create policy orders_staff_all on public.orders
  for all to authenticated using (true) with check (true);

-- 1b. INVENTORY: only logged-in staff.
alter table public.inventory enable row level security;
drop policy if exists inventory_staff_all on public.inventory;
create policy inventory_staff_all on public.inventory
  for all to authenticated using (true) with check (true);

-- 1c. DRIVE_THRU_ORDERS (customer online orders):
--     • customers (anon) may CREATE an order and READ it for live tracking
--     • only staff (authenticated) may UPDATE (accept / ready / picked-up) or DELETE
alter table public.drive_thru_orders enable row level security;

drop policy if exists dto_anon_insert on public.drive_thru_orders;
create policy dto_anon_insert on public.drive_thru_orders
  for insert to anon with check (true);

drop policy if exists dto_anon_select on public.drive_thru_orders;
create policy dto_anon_select on public.drive_thru_orders
  for select to anon using (true);
-- NOTE (PII): the SELECT policy above lets anyone with the public anon key read
-- drive-thru rows (customer name/phone). It is required for the customer's live
-- order tracking + realtime to work without login. To fully hide other customers'
-- data, add a random per-order token column and filter on it — ask your developer
-- to do this as a follow-up. Staff data (orders/inventory) is already locked down.

drop policy if exists dto_staff_all on public.drive_thru_orders;
create policy dto_staff_all on public.drive_thru_orders
  for all to authenticated using (true) with check (true);

-- 1d. Atomic stock decrement (prevents two tablets from losing each other's
--     deductions). Optional to use now — the POS can be switched to call
--     sb.rpc('decrement_stock', { p_id, p_amt }) in a follow-up.
create or replace function public.decrement_stock(p_id text, p_amt numeric)
returns void language sql security definer as $$
  update public.inventory set stock = greatest(0, stock - p_amt) where id = p_id;
$$;

-- 1e. Make sure the POS order-number migration has been applied (DB-assigned,
--     gapless, collision-free order numbers). If you have not run it yet, also
--     run the separate file supabase_migration.sql now.


-- ----------------------------------------------------------------------------
-- PHASE 2 — Order-number integrity. Read the notes; the unique indexes will
--           FAIL if the table already contains duplicate order numbers.
-- ----------------------------------------------------------------------------

-- 2a. Find existing duplicates first (run these SELECTs; both should return 0 rows
--     before you create the unique indexes below):
--   select order_number, count(*) from public.orders            group by 1 having count(*) > 1;
--   select order_number, count(*) from public.drive_thru_orders group by 1 having count(*) > 1;

-- 2b. Enforce unique order numbers (run only after 2a returns no duplicates):
-- create unique index if not exists orders_order_number_key
--   on public.orders (order_number);
-- create unique index if not exists dto_order_number_key
--   on public.drive_thru_orders (order_number);

-- 2c. Give drive-thru orders DB-assigned numbers (gapless, no client collisions).
--     After running this, the order app should stop sending its own order_number
--     so the database fills it in — ask your developer to make that one-line change,
--     then this default takes over.
-- create sequence if not exists public.dt_seq;
-- alter table public.drive_thru_orders
--   alter column order_number set default '#DT-' || lpad(nextval('public.dt_seq')::text, 4, '0');

-- ============================================================================
-- After Phase 1: test by placing an order in the POS. If it saves and appears
-- in Orders/Inventory/Reports, the RLS issue is resolved.
-- ============================================================================
