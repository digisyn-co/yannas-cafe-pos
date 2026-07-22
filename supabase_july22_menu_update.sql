-- ============================================================================
-- Yanna's Vietnamese Coffee — POS inventory update (July 22, 2026)
--
-- WHY: two new ingredients are now used by the POS but don't exist in the
--      inventory table yet, so sales of them silently deduct nothing:
--        1. broken_rice  — 100 g per Cơm Tấm plate (menu items 36/37/38)
--        2. yema_fudge   — replaces raw egg yolks in the custard cream
--                          (23 g per Egg Coffee, 19 g per Egg Custard Matcha)
--
-- HOW TO RUN: Supabase dashboard → SQL Editor → New query → paste → Run.
-- Safe to run more than once (it skips rows that already exist).
--
-- ⚠ SET YOUR OPENING STOCK on the two marked lines below before running.
--   Both are in GRAMS. Leaving them at 0 is safe — orders still go through —
--   but the Inventory tab will show both items as "Out" until you top them up.
-- ============================================================================


-- ── 1. Broken rice ──────────────────────────────────────────────────────────
-- Inherits category / unit / par level from your existing "rice" row so it
-- lands in the same group in the Inventory tab. Falls back to sensible
-- defaults if you don't have a "rice" row.
insert into public.inventory (id, name, cat, unit, stock, max_stock)
select
  'broken_rice',
  'Broken Rice (raw)',
  coalesce((select cat  from public.inventory where id = 'rice'), 'Dry Goods'),
  'g',                                  -- always grams: the POS deducts 100 g per plate
  0,                                    -- ⚠ OPENING STOCK IN GRAMS (e.g. 10000 = 10 kg)
  coalesce((select max_stock from public.inventory where id = 'rice'), 20000)
where not exists (select 1 from public.inventory where id = 'broken_rice');


-- ── 2. La Crema Yema Fudge ──────────────────────────────────────────────────
-- Inherits from your existing "heavy_cream" row (same dairy/chiller group).
insert into public.inventory (id, name, cat, unit, stock, max_stock)
select
  'yema_fudge',
  'La Crema Yema Fudge',
  coalesce((select cat  from public.inventory where id = 'heavy_cream'), 'Dairy'),
  'g',                                  -- always grams: yema fudge is weighed, not poured
  0,                                    -- ⚠ OPENING STOCK IN GRAMS (e.g. 5000 = 5 kg)
  coalesce((select max_stock from public.inventory where id = 'heavy_cream'), 5000)
where not exists (select 1 from public.inventory where id = 'yema_fudge');


-- ── 3. Check it worked ──────────────────────────────────────────────────────
-- Should return exactly 2 rows.
select id, name, cat, unit, stock, max_stock
from public.inventory
where id in ('broken_rice', 'yema_fudge')
order by id;


-- ============================================================================
-- NOTES
--
-- • Units: the POS deducts using the raw numbers in its recipe table, which
--   are in grams, so both rows are created with unit 'g' and `stock` must be
--   a gram count. Note the Inventory tab's Edit dropdown only offers
--   pcs / kg / batch — if you open one of these rows and hit Save, it will
--   silently relabel the unit. That's cosmetic (the deduction maths ignores
--   the label), but don't let it fool you into re-entering stock in kg.
--
-- • Nothing was REMOVED. The custard no longer uses eggs, condensed milk or
--   sugar, but all three are still used by other recipes (fried rice, milk
--   coffee, simple syrup), so those rows stay. You may just want to lower
--   your egg and condensed-milk par levels now that the custard doesn't
--   draw on them.
-- ============================================================================
