-- Fichier: supabase/migrations/xxxx_rejistra_bloc_1_3_reports_admin.sql

-- #################################################
-- ### 1. TRIGGER D'AUDIT GÉNÉRIQUE (Source: 1083-1087)
-- #################################################
-- Ce trigger enregistrera toute modification (INSERT, UPDATE, DELETE)
-- sur les tables sensibles dans la table 'audit_log'.
CREATE OR REPLACE FUNCTION public.log_audit_changes()
RETURNS TRIGGER
AS $$
DECLARE
  actor_name TEXT;
  actor_site public.site_enum;
BEGIN
  -- Récupère le nom et le site de l'utilisateur qui effectue l'action
  SELECT nom_complet, site_rattache INTO actor_name, actor_site
  FROM public.profiles WHERE id = auth.uid();

  -- Insère une nouvelle ligne dans la table d'audit
  INSERT INTO public.audit_log (user_id, user_name, site, action, details)
  VALUES (
    auth.uid(),
    actor_name,
    actor_site,
    TG_OP, -- Variable système: 'INSERT', 'UPDATE', ou 'DELETE'
    jsonb_build_object('table', TG_TABLE_NAME, 'old_data', OLD, 'new_data', NEW)
  );

  -- Retourne la nouvelle ligne pour que l'opération continue
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Appliquer le trigger aux tables sensibles
CREATE TRIGGER audit_etudiants_changes
  AFTER INSERT OR UPDATE OR DELETE ON public.etudiants
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_changes();

CREATE TRIGGER audit_recus_changes
  AFTER INSERT OR UPDATE OR DELETE ON public.recus
  FOR EACH ROW EXECUTE FUNCTION public.log_audit_changes();

-- #################################################
-- ### 2. POLITIQUES RLS POUR ADMIN/RAPPORTS (Source: 1267-1269)
-- #################################################

-- --- Table 'etudiants' (UPDATE) ---
-- Permet à Admin/Contrôleur de modifier un étudiant (ex: son statut)
CREATE POLICY "Admin_Controleur peut modifier un etudiant"
  ON public.etudiants FOR UPDATE USING (
    get_my_role() IN ('admin', 'controleur')
  ) WITH CHECK (
    get_my_role() IN ('admin', 'controleur')
  );

-- --- Table 'config_options' (ADMIN) ---
-- Permet aux Admins/Contrôleurs de gérer les listes déroulantes
CREATE POLICY "Admin_Controleur peut gerer la config"
  ON public.config_options FOR ALL USING (
    get_my_role() IN ('admin', 'controleur')
  );

-- --- Table 'audit_log' (ADMIN) ---
-- Permet aux Admins/Contrôleurs de lire tout l'audit
CREATE POLICY "Admin_Controleur peut lire tout l'audit"
  ON public.audit_log FOR SELECT USING (
    get_my_role() IN ('admin', 'controleur')
  );

-- Permet au personnel de site de lire l'audit de son propre site
CREATE POLICY "Le personnel de site peut lire l'audit de son site"
  ON public.audit_log FOR SELECT USING (
    site = get_my_site()
  );