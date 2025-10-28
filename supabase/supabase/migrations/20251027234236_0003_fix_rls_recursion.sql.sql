-- supabase/migrations/0003_fix_rls_recursion.sql

-- CORRECTION pour
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS public.role_enum
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER; -- <-- LA CORRECTION EST ICI

-- CORRECTION pour [cite: 1075]
CREATE OR REPLACE FUNCTION public.get_my_site()
RETURNS public.site_enum
AS $$
  SELECT site_rattache FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER; -- <-- LA CORRECTION EST ICI