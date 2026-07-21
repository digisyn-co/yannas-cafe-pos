-- ============================================================================
-- Yanna's Vietnamese Cafe — July 22, 2026 menu & recipe update
-- 1) New inventory item: La Crema Yema Fudge (replaces raw egg yolks in custard)
-- 2) New inventory item: broken rice (for the Cơm Tấm plates)
-- Run ONCE in Supabase -> SQL Editor. Safe to re-run (idempotent).
--
-- NOTE: adjust `stock` and `max_stock` to your real par levels before running.
-- ============================================================================

-- 1) Yema fudge — used by the updated Custard Cream batch (1L cream : 600g fudge)
insert into public.inventory (id, name, cat, unit, stock, max_stock)
values ('yema_fudge', 'La Crema Yema Fudge', 'Dairy', 'g', 0, 5000)
on conflict (id) do nothing;

-- 2) Broken rice — 100g raw per Cơm Tấm plate
insert into public.inventory (id, name, cat, unit, stock, max_stock)
values ('broken_rice', 'Broken Rice (raw)', 'Dry Goods', 'g', 0, 20000)
on conflict (id) do nothing;

-- ============================================================================
-- OPTIONAL — the custard cream no longer uses raw egg yolks, condensed milk,
-- or white sugar. Those inventory items are still used by OTHER recipes
-- (fried rice, milk coffee, simple syrup), so they are intentionally NOT
-- removed here. Only your par levels for eggs/condensed may need lowering.
-- ============================================================================
