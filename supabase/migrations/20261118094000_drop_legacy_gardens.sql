-- The normalized plant collection model is now the only cloud garden model.
-- The old JSON gardens table was manually removed and is retired permanently.
drop table if exists public.gardens;
