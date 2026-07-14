-- ============================================================================
-- Yanna's Cafe — Timeclock (standalone /timeclock page, PIN per employee)
-- Run in Supabase → SQL Editor (project dgjtpxdbztnokfbmfjbw) AFTER
-- supabase_shifts.sql. Paste whole, Run once. Idempotent — safe to re-run.
--
-- WHY THIS EXISTS:
-- The timeclock is a shared wall tablet. Staff are NOT logged in there (no
-- Supabase Auth session → role "anon"). The shifts/employees tables are locked
-- to "authenticated", so a barista's punch can't touch them directly. Instead
-- the punch goes through security-definer functions below: the employee's PIN
-- is the credential, and the functions only ever act on the row that PIN
-- unlocks. The PIN is stored hashed and never leaves the database.
-- ============================================================================

create extension if not exists pgcrypto;

-- Add a hashed PIN to the roster. Nullable → staff without a PIN simply can't
-- use the timeclock until the owner sets one.
alter table public.employees add column if not exists pin_hash text;

-- ----------------------------------------------------------------------------
-- Owner sets / changes an employee's PIN. Called from the (authenticated) POS
-- Shifts tab only. Keeps hashing on the server.
-- ----------------------------------------------------------------------------
create or replace function public.set_employee_pin(p_employee_id uuid, p_pin text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.employees
     set pin_hash = crypt(p_pin, gen_salt('bf'))
   where id = p_employee_id;
end; $$;

revoke all on function public.set_employee_pin(uuid, text) from public, anon;
grant execute on function public.set_employee_pin(uuid, text) to authenticated;

-- ----------------------------------------------------------------------------
-- Timeclock punch. Runs for anon (the wall tablet). Verifies the PIN, finds the
-- matching ACTIVE employee, then toggles their clock:
--   • no open shift  → clocks IN,  returns action 'in'
--   • open shift     → clocks OUT, returns action 'out'
-- Returns the employee's name + action + timestamp so the page can greet them.
-- Never returns the PIN or other employees' data. A wrong PIN returns ok=false.
-- ----------------------------------------------------------------------------
create or replace function public.timeclock_punch(p_pin text)
returns table(ok boolean, action text, employee_name text, at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  emp   public.employees%rowtype;
  open_id uuid;
  now_ts timestamptz := now();
begin
  -- find the active employee whose PIN matches
  select * into emp from public.employees e
   where e.active and e.pin_hash is not null and crypt(p_pin, e.pin_hash) = e.pin_hash
   limit 1;

  if emp.id is null then
    return query select false, null::text, null::text, null::timestamptz;
    return;
  end if;

  select s.id into open_id from public.shifts s
   where s.employee_id = emp.id and s.clock_in is not null and s.clock_out is null
   limit 1;

  if open_id is null then
    insert into public.shifts (employee_id, clock_in) values (emp.id, now_ts);
    return query select true, 'in'::text, emp.name, now_ts;
  else
    update public.shifts set clock_out = now_ts where id = open_id;
    return query select true, 'out'::text, emp.name, now_ts;
  end if;
end; $$;

revoke all on function public.timeclock_punch(text) from public;
grant execute on function public.timeclock_punch(text) to anon, authenticated;

-- ============================================================================
-- After this runs: set a PIN for each employee from the POS Shifts tab
-- (Add Employee now has a PIN field, and existing staff get a "Set PIN" button),
-- then open /timeclock on the wall tablet and punch in.
-- ============================================================================
