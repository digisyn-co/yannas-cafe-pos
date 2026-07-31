-- ============================================================================
-- Yanna's Vietnamese Coffee — POS inventory update: Chick n Chips (₱185)
--
-- WHY: the new "Chick n Chips" menu item (POS id 40) deducts frozen fries,
--      and so does the existing "Fries" side (id 39, which until now had no
--      recipe at all and deducted nothing). Neither works until the
--      `frozen_fries` ingredient exists in the inventory table.
--
--      Per serving the POS now deducts:
--        Chick n Chips (40) — chicken 150 g, frozen_fries 120 g, cooking_oil 20 g
--        Fries         (39) — frozen_fries 120 g, cooking_oil 15 g
--
-- HOW TO RUN: Supabase dashboard → SQL Editor → New query → paste → Run.
-- Safe to run more than once (it skips the row if it already exists).
--
-- ⚠ SET YOUR OPENING STOCK on the marked line below before running.
--   It is in GRAMS. Leaving it at 0 is safe — orders still go through — but
--   the Inventory tab will show frozen fries as "Out" until you top it up.
-- ============================================================================


-- ── 1. Frozen fries ─────────────────────────────────────────────────────────
-- Inherits category / par level from your existing "chicken" row so it lands
-- in the same freezer group in the Inventory tab. Falls back to sensible
-- defaults if you don't have a "chicken" row.
insert into public.inventory (id, name, cat, unit, stock, max_stock)
select
  'frozen_fries',
  'Frozen Fries (raw)',
  coalesce((select cat from public.inventory where id = 'chicken'), 'Frozen'),
  'g',                                  -- always grams: the POS deducts 120 g per portion
  0,                                    -- ⚠ OPENING STOCK IN GRAMS (e.g. 10000 = 10 kg)
  coalesce((select max_stock from public.inventory where id = 'chicken'), 20000)
where not exists (select 1 from public.inventory where id = 'frozen_fries');


-- ── 2. Check it worked ──────────────────────────────────────────────────────
-- Should return exactly 1 row.
select id, name, cat, unit, stock, max_stock
from public.inventory
where id = 'frozen_fries';


-- ============================================================================
-- NOTES
--
-- • Units: the POS deducts using the raw numbers in its RECIPE table, which
--   are in grams, so this row is created with unit 'g' and `stock` must be a
--   gram count. The Inventory tab's Edit dropdown only offers pcs / kg / batch
--   — if you open this row and hit Save, it will silently relabel the unit.
--   That's cosmetic (the deduction maths ignores the label), but don't let it
--   fool you into re-entering stock in kg.
--
-- • Chicken: Chick n Chips draws 150 g from the same `chicken` row already used
--   by the Chicken BBQ Sandwich (110 g), Chicken Broken Rice (150 g) and
--   Chicken Bites & Rice (100 g). You may want to raise that row's par level
--   now that a fourth item pulls from it.
--
-- • Cost / profit: Chick n Chips is flagged `profit:true` in the POS, so it
--   appears in the Reports profit breakdown — but the margin only shows once
--   you enter its unit cost in the POS (Reports → item costs). Nothing in this
--   migration sets that.
--
-- • No rows are removed or changed. This script only adds `frozen_fries`.
-- ============================================================================
