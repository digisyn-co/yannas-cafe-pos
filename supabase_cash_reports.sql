-- ============================================================================
-- Yanna's Cafe — Cash In/Out log + Item Cost tracking (Reports tab)
-- Run this in Supabase → SQL Editor (project dgjtpxdbztnokfbmfjbw).
-- Safe to run more than once (idempotent).
--
-- Adds two tables used by the new Reports tab features:
--   • cash_movements — manual cash-drawer log ("Cash In" / "Cash Out"),
--     e.g. cash taken out to buy supplies, or cash added back into the drawer.
--     Reports uses this to show Net Profit = Revenue − Cash Out.
--   • menu_costs — cost price per menu item (item_id matches the numeric
--     `id` in the MENU array in index.html), editable from Reports → ✎ Item
--     Costs, without touching code. Reports uses this to estimate Gross
--     Profit = Revenue − Cost of Goods Sold on items that have a cost on file.
-- ============================================================================

-- 1. CASH_MOVEMENTS — manual cash in/out log.
create table if not exists public.cash_movements (
    id uuid primary key default gen_random_uuid(),
    type text not null check (type in ('in','out')),
    amount numeric not null check (amount > 0),
    reason text,
    cashier_name text,
    cashier_email text,
    created_at timestamptz not null default now()
  );

create index if not exists idx_cash_movements_created_at on public.cash_movements(created_at);

alter table public.cash_movements enable row level security;
drop policy if exists cash_movements_staff_all on public.cash_movements;
create policy cash_movements_staff_all on public.cash_movements
  for all to authenticated using (true) with check (true);

-- 2. MENU_COSTS — cost price per menu item (id matches MENU[].id in index.html).
create table if not exists public.menu_costs (
    item_id integer primary key,
    cost numeric not null default 0 check (cost >= 0),
    updated_at timestamptz not null default now(),
    updated_by text
  );

alter table public.menu_costs enable row level security;
drop policy if exists menu_costs_staff_all on public.menu_costs;
create policy menu_costs_staff_all on public.menu_costs
  for all to authenticated using (true) with check (true);

-- 3. Seed menu_costs with the estimated per-item costs already in the Owner &
--    Manager Guide (Section 6, "Menu Costing & Profit Margins" — figures are
--    the guide's own estimates, using the midpoint where a range was given).
--    These are meant to be corrected over time via Reports → ✎ Item Costs as
--    real supplier prices are confirmed — this just avoids starting from zero.
--    Items not listed here (add-ons, kids menu, fresh juices) have no cost
--    estimate in the guide, so they're left unset; Gross Profit will simply
--    exclude their revenue until a cost is entered in-app.
insert into public.menu_costs (item_id, cost) values
  (1, 34.5),   -- Traditional Black Coffee
  (5, 40.5),   -- Vietnamese Milk Coffee
  (2, 53.5),   -- Salted Cream Coffee
  (3, 59.5),   -- Coconut Coffee
  (4, 46.5),   -- Egg Coffee
  (6, 31.5),   -- Matcha Latte
  (7, 40.5),   -- Salt Matcha
  (8, 53.5),   -- Egg Custard Matcha
  (9, 22),     -- Fruit Tea (all flavors)
  (14, 78),    -- Chicken BBQ Sandwich
  (13, 100),   -- BBQ Pork Sandwich
  (15, 128),   -- Beef BBQ Sandwich
  (37, 61),    -- Chicken Broken Rice
  (36, 79),    -- Pork Broken Rice
  (38, 91)     -- Beef Broken Rice
on conflict (item_id) do nothing;
