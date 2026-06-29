-- ============================================================================
-- Yanna's Cafe — Phase 2: gapless, unique order numbers
-- Run in Supabase → SQL Editor (project dgjtpxdbztnokfbmfjbw).
--
-- IMPORTANT: run STEP 1 first and look at the results. If either query returns
-- any rows, you have duplicate order numbers — STOP and tell your developer
-- before running STEP 2/3 (the unique indexes will fail on duplicates).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1 — Duplicate check. Both of these should return ZERO rows.
-- ----------------------------------------------------------------------------
select order_number, count(*) from public.orders
  group by order_number having count(*) > 1;

select order_number, count(*) from public.drive_thru_orders
  group by order_number having count(*) > 1;


-- ----------------------------------------------------------------------------
-- STEP 2 — Enforce unique order numbers (run only if STEP 1 returned no rows).
-- ----------------------------------------------------------------------------
create unique index if not exists orders_order_number_key
  on public.orders (order_number);

create unique index if not exists dto_order_number_key
  on public.drive_thru_orders (order_number);


-- ----------------------------------------------------------------------------
-- STEP 3 — Database-assigned drive-thru numbers (#DT-0001, #DT-0002, ...).
--   The sequence starts ABOVE the highest existing #DT number so it never
--   collides with orders already in the table.
-- ----------------------------------------------------------------------------
create sequence if not exists public.dt_seq;

select setval(
  'public.dt_seq',
  coalesce(
    (select max(nullif(regexp_replace(order_number, '\D', '', 'g'), '')::int)
       from public.drive_thru_orders),
    0
  ) + 1,
  false
);

alter table public.drive_thru_orders
  alter column order_number set default '#DT-' || lpad(nextval('public.dt_seq')::text, 4, '0');

-- ============================================================================
-- Done. The order app has already been updated to let the database assign the
-- number, so from now on every drive-thru order gets a unique, gapless #DT-####.
-- Test: place an order in the customer app and confirm the number it shows is
-- sequential and that a second simultaneous order gets a different number.
-- ============================================================================
