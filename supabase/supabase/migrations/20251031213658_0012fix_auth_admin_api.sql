-- ================================================================
-- MIGRATION: Correction des fonctions d'authentification
-- Supprime les RPC incorrectes et les remplace par des appels sécurisés
-- ================================================================

-- 1. SUPPRIMER LES ANCIENNES FONCTIONS INCORRECTES
DROP FUNCTION IF EXISTS public.create_student_account(jsonb, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS public.create_staff_user(TEXT, TEXT, TEXT, public.role_enum, public.site_enum);
DROP FUNCTION IF EXISTS public.delete_staff_user(uuid);

-- ================================================================
-- 2. CRÉER UNE FONCTION RPC POUR VALIDER LES DONNÉES ÉTUDIANTS
-- Cette fonction PRÉPARE les données mais NE CRÉE PAS le compte auth
-- (La création sera faite par une Edge Function)
-- ================================================================
CREATE OR REPLACE FUNCTION public.prepare_student_data(
    student_data jsonb,
    activate_gojika BOOLEAN DEFAULT false
)
RETURNS jsonb
AS $$
DECLARE
    accueil_site public.site_enum;
    student_email TEXT;
BEGIN
    -- Vérifier que l'exécutant est bien 'Accueil'
    SELECT site_rattache INTO accueil_site
    FROM public.profiles
    WHERE id = auth.uid() AND role = 'accueil';

    IF accueil_site IS NULL THEN
        RAISE EXCEPTION 'Action non autorisée. Seul le rôle "Accueil" peut créer des étudiants.';
    END IF;

    -- Extraire l'email
    student_email := student_data->>'email_contact';

    -- Vérifier que l'email n'existe pas déjà
    IF EXISTS (SELECT 1 FROM public.etudiants WHERE email_contact = student_email) THEN
        RAISE EXCEPTION 'Un étudiant avec cet email existe déjà.';
    END IF;

    -- Retourner les données validées avec le site
    RETURN jsonb_build_object(
        'student_data', student_data,
        'site', accueil_site::text,
        'activate_gojika', activate_gojika,
        'user_id', auth.uid()::text
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 3. CRÉER UNE FONCTION POUR FINALISER LA CRÉATION ÉTUDIANT
-- Appelée par l'Edge Function après création du compte auth
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
BEGIN
    -- Insérer l'étudiant dans public.etudiants
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
        site_code::public.site_enum,
        auth_user_id,
        activate_gojika,
        true
    ) RETURNING id, id_etudiant_genere INTO new_student_id, generated_student_id;

    RETURN jsonb_build_object(
        'id', new_student_id,
        'id_etudiant_genere', generated_student_id,
        'email', student_data->>'email_contact'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 4. CRÉER UNE FONCTION POUR VALIDER LES DONNÉES STAFF
-- ================================================================
CREATE OR REPLACE FUNCTION public.prepare_staff_data(
    email TEXT,
    nom_complet TEXT,
    role public.role_enum,
    site public.site_enum
)
RETURNS jsonb
AS $$
BEGIN
    -- Vérifier que l'exécutant est bien 'admin'
    IF public.get_my_role() <> 'admin' THEN
        RAISE EXCEPTION 'Action non autorisée. Seul un Admin peut créer du personnel.';
    END IF;

    -- Vérifier que l'email n'existe pas déjà
    IF EXISTS (SELECT 1 FROM public.profiles WHERE profiles.email = prepare_staff_data.email) THEN
        RAISE EXCEPTION 'Un utilisateur avec cet email existe déjà.';
    END IF;

    RETURN jsonb_build_object(
        'email', email,
        'nom_complet', nom_complet,
        'role', role::text,
        'site', site::text
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 5. CRÉER UNE FONCTION POUR FINALISER LA CRÉATION STAFF
-- ================================================================
CREATE OR REPLACE FUNCTION public.finalize_staff_creation(
    auth_user_id uuid,
    nom_complet TEXT,
    role_name text,
    site_name text
)
RETURNS jsonb
AS $$
BEGIN
    -- Mettre à jour le profil (créé automatiquement par le trigger)
    UPDATE public.profiles
    SET nom_complet = finalize_staff_creation.nom_complet
    WHERE id = auth_user_id;

    RETURN jsonb_build_object(
        'id', auth_user_id,
        'nom_complet', nom_complet
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 6. FONCTION POUR PRÉPARER LA SUPPRESSION D'UN UTILISATEUR
-- ================================================================
CREATE OR REPLACE FUNCTION public.prepare_user_deletion(user_id uuid)
RETURNS jsonb
AS $$
DECLARE
    user_email TEXT;
    user_role TEXT;
BEGIN
    IF public.get_my_role() <> 'admin' THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

    -- Récupérer les infos de l'utilisateur
    SELECT email, role::text INTO user_email, user_role
    FROM public.profiles
    WHERE id = user_id;

    IF user_email IS NULL THEN
        RAISE EXCEPTION 'Utilisateur introuvable.';
    END IF;

    RETURN jsonb_build_object(
        'id', user_id,
        'email', user_email,
        'role', user_role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 7. PERMISSIONS
-- ================================================================
GRANT EXECUTE ON FUNCTION public.prepare_student_data(jsonb, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_student_creation(uuid, jsonb, text, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_staff_data(TEXT, TEXT, public.role_enum, public.site_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_staff_creation(uuid, TEXT, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_user_deletion(uuid) TO authenticated;