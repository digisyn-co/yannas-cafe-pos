-- ============================================================================
-- Yanna's Cafe — Add missing discount columns to orders table
-- Run in Supabase → SQL Editor (paste whole, Run once). Safe to re-run.
--
-- WHY THIS IS NEEDED:
-- The POS front-end (index.html) has always sent discount_type, discount_amount,
-- discount_ids, and discount_pax when a PWD / Senior Citizen / Friendly discount
-- is applied to an order — but no migration ever created these columns on the
-- `orders` table. Every order placed WITH a discount fails to save with a
-- "column does not exist" error; orders with no discount save fine, which is
-- why the bug only shows up when a discount is applied.
-- ============================================================================

alter table public.orders add column if not exists discount_type   text;
alter table public.orders add column if not exists discount_amount numeric;
alter table public.orders add column if not exists discount_ids   jsonb;
alter table public.orders add column if not exists discount_pax   integer;

comment on column public.orders.discount_type   is 'PWD | SC | FRIENDLY | null — which discount, if any, was applied to this order';
comment on column public.orders.discount_amount is 'Peso amount deducted from the subtotal for the applied discount';
comment on column public.orders.discount_ids    is 'Array of {name, idNum} for each PWD/Senior ID holder on the order (or a single {name, idNum:"—"} entry for Friendly)';
comment on column public.orders.discount_pax    is 'Total number of customers in the order, used to compute the proportional PWD/Senior discount share';

-- After this runs, orders placed with a PWD, Senior Citizen, or Friendly
-- discount applied will save successfully instead of failing with a
-- "column discount_type does not exist" error.
