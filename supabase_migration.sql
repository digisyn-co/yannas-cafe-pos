-- ============================================================================
-- Yanna's Vietnamese Cafe — POS schema migration
-- Adds: database-assigned sequential order numbers + cash/change/cashier fields
-- Run ONCE in Supabase -> SQL Editor. Safe to re-run (idempotent).
-- The POS works with or without this migration; after running it, order numbers
-- become unique & gapless across all devices and the extra fields get saved.
-- ============================================================================

-- 1) Extended columns on the orders table -----------------------------------
alter table public.orders add column if not exists cash_tendered numeric;
alter table public.orders add column if not exists change_given  numeric;
alter table public.orders add column if not exists cashier_email text;
alter table public.orders add column if not exists cashier_name  text;

-- 2) Database-assigned sequential order numbers ------------------------------
-- A single sequence is the source of truth, so two devices can never collide.
create sequence if not exists public.order_seq;

-- Start the sequence just above the highest order number already in the table
-- (so existing receipts like #0007 are never reused).
select setval(
  'public.order_seq',
  coalesce(
    (select max(nullif(regexp_replace(order_number, '\D', '', 'g'), '')::bigint)
       from public.orders),
    0
  ) + 1,
  false   -- false = next nextval() returns this value (not value+1)
);

-- Make the DB fill order_number automatically on insert, formatted like #0001.
alter table public.orders
  alter column order_number
  set default '#' || lpad(nextval('public.order_seq')::text, 4, '0');

-- 3) (Optional, recommended) enforce uniqueness ------------------------------
-- This guarantees duplicates can never be saved. It will FAIL if your table
-- already contains duplicate order_number values created before this migration.
-- If it errors, first clean duplicates, then re-run just this statement:
--   select order_number, count(*) from public.orders
--   group by order_number having count(*) > 1;
create unique index if not exists orders_order_number_key
  on public.orders(order_number);

-- Done. New orders inserted without an order_number will be auto-numbered,
-- and cash_tendered / change_given / cashier_email / cashier_name are saved.
