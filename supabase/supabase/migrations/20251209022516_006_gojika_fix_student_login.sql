-- ================================================================
-- MIGRATION: Correction Login Étudiant - Phase 2
-- Corrige le problème de nom_complet NULL pour les étudiants
-- ================================================================

-- ================================================================
-- PARTIE 1: Correction du Trigger de Création de Profil
-- ================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
AS $$
DECLARE
  student_nom_complet TEXT;
BEGIN
  -- Pour les étudiants, récupérer nom_complet depuis metadata
  IF (NEW.raw_user_meta_data->>'role') = 'etudiant' THEN
    student_nom_complet := COALESCE(
      NEW.raw_user_meta_data->>'nom_complet',
      'Étudiant'
    );
  ELSE
    student_nom_complet := NULL;
  END IF;

  INSERT INTO public.profiles (id, email, role, site_rattache, nom_complet)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'etudiant')::public.role_enum,
    COALESCE(NEW.raw_user_meta_data->>'site', 'T')::public.site_enum,
    student_nom_complet
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- PARTIE 2: Correction de finalize_student_creation
-- ================================================================

CREATE OR REPLACE FUNCTION public.finalize_student_creation(
    auth_user_id uuid,
    student_data jsonb,
    site_code text,
    activate_gojika BOOLEAN
)
RETURNS jsonb
AS $$
DECLARE
    new_student_id bigint;
    generated_student_id TEXT;
    site_enum public.site_enum;
    full_name TEXT;
BEGIN
    site_enum := site_code::public.site_enum;

    full_name := TRIM(CONCAT(
        COALESCE(student_data->>'prenom', ''),
        ' ',
        COALESCE(student_data->>'nom', 'Étudiant')
    ));

    INSERT INTO public.etudiants (
        nom, prenom, date_naissance, email_contact, telephone,
        mention_module, niveau, groupe, departement,
        site,
        gojika_account_linked,
        gojika_account_active,
        gojika_must_reset_password
    )
    VALUES (
        student_data->>'nom',
        student_data->>'prenom',
        (student_data->>'date_naissance')::DATE,
        student_data->>'email_contact',
        student_data->>'telephone',
        student_data->>'mention_module',
        student_data->>'niveau',
        student_data->>'groupe',
        student_data->>'departement',
        site_enum,
        auth_user_id,
        activate_gojika,
        true
    ) RETURNING id, id_etudiant_genere INTO new_student_id, generated_student_id;

    UPDATE public.profiles
    SET nom_complet = full_name
    WHERE id = auth_user_id;

    RETURN jsonb_build_object(
        'id', new_student_id,
        'id_etudiant_genere', generated_student_id,
        'email', student_data->>'email_contact',
        'nom_complet', full_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.finalize_student_creation(uuid, jsonb, text, BOOLEAN) TO authenticated;

-- ================================================================
-- PARTIE 3: Backfill des Données Existantes
-- ================================================================

UPDATE public.profiles p
SET nom_complet = TRIM(CONCAT(COALESCE(e.prenom, ''), ' ', COALESCE(e.nom, 'Étudiant')))
FROM public.etudiants e
WHERE p.id = e.gojika_account_linked
  AND p.role = 'etudiant'
  AND (p.nom_complet IS NULL OR p.nom_complet = '' OR p.nom_complet = 'Étudiant');

-- ================================================================
-- PARTIE 4: RPC pour Vérifier le Reset Password
-- ================================================================

CREATE OR REPLACE FUNCTION public.check_password_reset_required(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  must_reset boolean;
BEGIN
  SELECT e.gojika_must_reset_password INTO must_reset
  FROM public.etudiants e
  WHERE e.gojika_account_linked = user_id
    AND e.gojika_account_active = true;

  RETURN COALESCE(must_reset, false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_password_reset_required(uuid) TO authenticated;

-- ================================================================
-- PARTIE 5: RPC pour Marquer le Password comme Changé
-- ================================================================

CREATE OR REPLACE FUNCTION public.mark_password_changed()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.etudiants
  SET gojika_must_reset_password = false
  WHERE gojika_account_linked = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_password_changed() TO authenticated;

-- ================================================================
-- PARTIE 6: Logs de Vérification
-- ================================================================

DO $$
DECLARE
  total_students INT;
  fixed_profiles INT;
  null_profiles INT;
BEGIN
  SELECT COUNT(*) INTO total_students FROM public.etudiants;

  SELECT COUNT(*) INTO fixed_profiles
  FROM public.profiles p
  JOIN public.etudiants e ON p.id = e.gojika_account_linked
  WHERE p.role = 'etudiant' AND p.nom_complet IS NOT NULL AND p.nom_complet != '';

  SELECT COUNT(*) INTO null_profiles
  FROM public.profiles p
  JOIN public.etudiants e ON p.id = e.gojika_account_linked
  WHERE p.role = 'etudiant' AND (p.nom_complet IS NULL OR p.nom_complet = '');

  RAISE NOTICE '═══════════════════════════════════════════';
  RAISE NOTICE '✅ Migration Terminée - Résumé:';
  RAISE NOTICE '   Total étudiants: %', total_students;
  RAISE NOTICE '   Profils corrigés: %', fixed_profiles;
  RAISE NOTICE '   Profils encore NULL: %', null_profiles;
  RAISE NOTICE '═══════════════════════════════════════════';
END $$;