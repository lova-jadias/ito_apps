-- Fichier: supabase/migrations/XXXXXXXX_0011_fix_missing_helpers_and_rls.sql

-- =================================================================
-- PARTIE 1: CRÉER LES FONCTIONS HELPER MANQUANTES
-- (Basé sur votre documentation, avec l'ajout de SECURITY DEFINER pour éviter les récursions RLS)
-- =================================================================

-- Obtient les IDs des étudiants liés à un parent [cite: 2061]
CREATE OR REPLACE FUNCTION public.get_my_children_ids()
RETURNS SETOF BIGINT
AS $$
  SELECT etudiant_id FROM public.parents_etudiants_link WHERE parent_user_id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Obtient l'ID étudiant de l'utilisateur actuel (s'il est étudiant) [cite: 2062]
CREATE OR REPLACE FUNCTION public.get_my_student_id()
RETURNS BIGINT
AS $$
  SELECT id FROM public.etudiants WHERE gojika_account_linked = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- =================================================================
-- PARTIE 2: RÉ-APPLIQUER LA LOGIQUE DE LA MIGRATION 0009
-- (Maintenant que les fonctions existent, cela va fonctionner)
-- =================================================================

-- 1. Bloquer l'INSERT direct sur 'etudiants'
DROP POLICY IF EXISTS "Accueil peut inscrire des étudiants" ON public.etudiants;
CREATE POLICY "Bloquer INSERT direct, utiliser RPC"
  ON public.etudiants FOR INSERT
  WITH CHECK (false);

-- 2. Mettre à jour la RLS de LECTURE pour les étudiants (GOJIKA)
DROP POLICY IF EXISTS "Un étudiant voit son propre profil" ON public.etudiants;
DROP POLICY IF EXISTS "Un étudiant voit son propre profil (si activé)" ON public.etudiants;
CREATE POLICY "Un étudiant voit son propre profil (si activé)"
  ON public.etudiants FOR SELECT USING (
    gojika_account_linked = auth.uid() AND
    gojika_account_active = true
  );

-- 3. Mettre à jour la RLS LECTURE des parents (GOJIKA)
DROP POLICY IF EXISTS "Un parent voit le profil de son enfant" ON public.etudiants;
DROP POLICY IF EXISTS "Un parent voit le profil de son enfant (si activé)" ON public.etudiants;
CREATE POLICY "Un parent voit le profil de son enfant (si activé)"
  ON public.etudiants FOR SELECT USING (
    id IN (SELECT get_my_children_ids()) AND
    gojika_account_active = true
  );

-- 4. Mettre à jour la RLS LECTURE des données liées (paiements)
DROP POLICY IF EXISTS "Un étudiant voit ses propres paiements" ON public.paiement_items;
DROP POLICY IF EXISTS "Un étudiant voit ses propres paiements (si activé)" ON public.paiement_items;
CREATE POLICY "Un étudiant voit ses propres paiements (si activé)"
  ON public.paiement_items FOR SELECT USING (
    id_etudiant = get_my_student_id() AND
    (SELECT gojika_account_active FROM public.etudiants WHERE id = id_etudiant) = true
  );

DROP POLICY IF EXISTS "Un parent voit les paiements de son enfant" ON public.paiement_items;
DROP POLICY IF EXISTS "Un parent voit les paiements de son enfant (si activé)" ON public.paiement_items;
CREATE POLICY "Un parent voit les paiements de son enfant (si activé)"
  ON public.paiement_items FOR SELECT USING (
    id_etudiant IN (SELECT get_my_children_ids()) AND
    (SELECT gojika_account_active FROM public.etudiants WHERE id = id_etudiant) = true
  );

-- 5. Mettre à jour la RLS UPDATE (Activation)
DROP POLICY IF EXISTS "Admin_Controleur peut modifier un etudiant" ON public.etudiants;
DROP POLICY IF EXISTS "Admin_Controleur_RP peut modifier un étudiant (statut, activation)" ON public.etudiants;
CREATE POLICY "Admin_Controleur_RP peut modifier un étudiant (statut, activation)"
  ON public.etudiants FOR UPDATE USING (
    get_my_role() IN ('admin', 'controleur', 'rp')
  ) WITH CHECK (get_my_role() IN ('admin', 'controleur', 'rp'));