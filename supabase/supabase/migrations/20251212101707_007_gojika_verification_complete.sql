-- ================================================================
-- MIGRATION 007: Vérification et correction complète
-- supabase/migrations/YYYYMMDDHHMMSS_007_gojika_verification_complete.sql
-- ================================================================

-- 1. VÉRIFIER ET CORRIGER LES PROFILS NULL
DO $$
DECLARE
  fixed_count INT := 0;
BEGIN
  -- Mettre à jour tous les profils étudiants avec nom_complet NULL
  UPDATE public.profiles p
  SET nom_complet = TRIM(CONCAT(COALESCE(e.prenom, ''), ' ', COALESCE(e.nom, 'Étudiant')))
  FROM public.etudiants e
  WHERE p.id = e.gojika_account_linked
    AND p.role = 'etudiant'
    AND (p.nom_complet IS NULL OR p.nom_complet = '' OR p.nom_complet = 'Étudiant');

  GET DIAGNOSTICS fixed_count = ROW_COUNT;
  RAISE NOTICE '✅ % profils étudiants corrigés', fixed_count;
END $$;

-- 2. CRÉER UNE VUE POUR FACILITER LES REQUÊTES ÉTUDIANTS
CREATE OR REPLACE VIEW public.vw_etudiants_complets AS
SELECT
  e.*,
  p.nom_complet,
  p.email,
  p.avatar_url,
  p.role
FROM public.etudiants e
LEFT JOIN public.profiles p ON e.gojika_account_linked = p.id
WHERE e.gojika_account_active = true;

COMMENT ON VIEW public.vw_etudiants_complets IS 'Vue simplifiée étudiants avec profil (évite les erreurs de jointure)';

-- 3. FONCTION HELPER POUR RÉCUPÉRER UN ÉTUDIANT PAR USER_ID
CREATE OR REPLACE FUNCTION public.get_etudiant_by_user_id(p_user_id uuid)
RETURNS TABLE (
  id bigint,
  nom text,
  prenom text,
  site text,
  groupe text,
  email_contact text,
  gojika_account_active boolean,
  gojika_must_reset_password boolean,
  nom_complet text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.nom,
    e.prenom,
    e.site::text,
    e.groupe,
    e.email_contact,
    e.gojika_account_active,
    e.gojika_must_reset_password,
    p.nom_complet
  FROM public.etudiants e
  LEFT JOIN public.profiles p ON e.gojika_account_linked = p.id
  WHERE e.gojika_account_linked = p_user_id
    AND e.gojika_account_active = true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_etudiant_by_user_id(uuid) TO authenticated;

-- 4. VÉRIFICATION DES COMPTES ÉTUDIANTS EXISTANTS
DO $$
DECLARE
  total_etudiants INT;
  actives_etudiants INT;
  linked_etudiants INT;
  null_nom_complet INT;
BEGIN
  SELECT COUNT(*) INTO total_etudiants FROM public.etudiants;
  SELECT COUNT(*) INTO actives_etudiants FROM public.etudiants WHERE gojika_account_active = true;
  SELECT COUNT(*) INTO linked_etudiants FROM public.etudiants WHERE gojika_account_linked IS NOT NULL;

  SELECT COUNT(*) INTO null_nom_complet
  FROM public.profiles p
  JOIN public.etudiants e ON p.id = e.gojika_account_linked
  WHERE p.role = 'etudiant'
    AND (p.nom_complet IS NULL OR p.nom_complet = '');

  RAISE NOTICE '═══════════════════════════════════════════════════════';
  RAISE NOTICE '✅ RAPPORT DE VÉRIFICATION ÉTUDIANTS';
  RAISE NOTICE '   Total étudiants: %', total_etudiants;
  RAISE NOTICE '   Comptes actifs: %', actives_etudiants;
  RAISE NOTICE '   Comptes liés: %', linked_etudiants;
  RAISE NOTICE '   Profils nom_complet NULL: %', null_nom_complet;
  RAISE NOTICE '═══════════════════════════════════════════════════════';
END $$;

-- 5. AJOUTER UN INDEX POUR OPTIMISER LES REQUÊTES
CREATE INDEX IF NOT EXISTS idx_etudiants_gojika_account
ON public.etudiants(gojika_account_linked)
WHERE gojika_account_active = true;

COMMENT ON INDEX public.idx_etudiants_gojika_account IS 'Optimise les requêtes de connexion étudiant';

-- 6. POLITIQUE RLS POUR LA VUE (si nécessaire)
ALTER VIEW public.vw_etudiants_complets SET (security_invoker = true);

-- 7. TEST DE LA FONCTION HELPER
DO $$
DECLARE
  test_user_id uuid;
  test_result RECORD;
BEGIN
  -- Prendre le premier étudiant actif pour test
  SELECT gojika_account_linked INTO test_user_id
  FROM public.etudiants
  WHERE gojika_account_active = true
  LIMIT 1;

  IF test_user_id IS NOT NULL THEN
    SELECT * INTO test_result FROM public.get_etudiant_by_user_id(test_user_id);

    IF test_result IS NOT NULL THEN
      RAISE NOTICE '✅ Test fonction helper réussi: % %', test_result.prenom, test_result.nom;
    ELSE
      RAISE WARNING '⚠️ Test fonction helper: aucun résultat';
    END IF;
  END IF;
END $$;