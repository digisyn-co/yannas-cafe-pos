-- ============================================================================
-- Yanna's Cafe — Phase 2 cleanup + apply (run as ONE paste in the SQL Editor)
-- Safe: deletes only the duplicate TEST drive-thru rows; keeps every real sale
-- in `orders` (duplicate copies are just renamed so they become unique).
-- ============================================================================

-- A) Remove the duplicate TEST drive-thru orders (#DT-0001/0002/0003).
delete from public.drive_thru_orders
where order_number in ('#DT-0001', '#DT-0002', '#DT-0003');

-- B) Make any duplicate numbers in `orders` unique WITHOUT losing rows.
--    The first row of each number keeps it; extra copies get a "-dup2/-dup3" suffix.
with d as (
  select id, order_number,
         row_number() over (partition by order_number order by created_at, id) as rn
  from public.orders
)
update public.orders o
set order_number = o.order_number || '-dup' || d.rn
from d
where o.id = d.id and d.rn > 1;

-- C) Enforce unique order numbers from now on.
create unique index if not exists orders_order_number_key
  on public.orders (order_number);
create unique index if not exists dto_order_number_key
  on public.drive_thru_orders (order_number);

-- D) Database-assigned drive-thru numbers (gapless), starting above any existing.
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
-- After this runs: place a customer order; its #DT number should be unique and
-- sequential, and a second simultaneous order gets a different number.
-- ============================================================================
