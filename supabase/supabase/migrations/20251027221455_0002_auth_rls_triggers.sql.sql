-- FONCTION HELPER: Obtient le rôle de l'utilisateur actuel
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS public.role_enum
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE;

-- FONCTION HELPER: Obtient le site de l'utilisateur actuel
CREATE OR REPLACE FUNCTION public.get_my_site()
RETURNS public.site_enum
AS $$
  SELECT site_rattache FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE;

-- TRIGGER: Synchroniser auth.users -> public.profiles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role, site_rattache)
  VALUES (
    NEW.id,
    NEW.email,
    -- 'role' et 'site_rattache' doivent être passés lors de l'inscription (via metadata)
    -- Le 'role' par défaut est 'etudiant' si non fourni (ex: auto-création)
    COALESCE(NEW.raw_user_meta_data->>'role', 'etudiant')::public.role_enum,
    COALESCE(NEW.raw_user_meta_data->>'site', 'T')::public.site_enum
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Activer RLS sur toutes les tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.etudiants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.paiement_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.absences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.justifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.publications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matieres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emplois_du_temps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parents_etudiants_link ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.config_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- POLITIQUES DE BASE (Bloc 0.3)

-- --- profiles ---
--
CREATE POLICY "Les utilisateurs peuvent voir/modifier leur propre profil"
  ON public.profiles FOR ALL USING (id = auth.uid()) WITH CHECK (id = auth.uid());

--
CREATE POLICY "Les Admins/Contrôleurs peuvent tout gérer"
  ON public.profiles FOR ALL USING (get_my_role() IN ('admin', 'controleur'));