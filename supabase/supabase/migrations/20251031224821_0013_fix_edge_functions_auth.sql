-- ================================================================
-- CORRECTION: Simplifier les fonctions RPC pour les Edge Functions
-- Les Edge Functions passent l'user_id explicitement
-- ================================================================

-- 1. REMPLACER prepare_student_data
DROP FUNCTION IF EXISTS public.prepare_student_data(jsonb, BOOLEAN);

CREATE OR REPLACE FUNCTION public.prepare_student_data(
    student_data jsonb,
    activate_gojika BOOLEAN,
    requesting_user_id uuid -- AJOUT: passé par l'Edge Function
)
RETURNS jsonb
AS $$
DECLARE
    accueil_site public.site_enum;
    student_email TEXT;
BEGIN
    -- Vérifier que l'utilisateur est bien 'Accueil'
    SELECT site_rattache INTO accueil_site
    FROM public.profiles
    WHERE id = requesting_user_id AND role = 'accueil';

    IF accueil_site IS NULL THEN
        RAISE EXCEPTION 'Action non autorisée. Seul le rôle "Accueil" peut créer des étudiants.';
    END IF;

    student_email := student_data->>'email_contact';

    IF EXISTS (SELECT 1 FROM public.etudiants WHERE email_contact = student_email) THEN
        RAISE EXCEPTION 'Un étudiant avec cet email existe déjà.';
    END IF;

    RETURN jsonb_build_object(
        'student_data', student_data,
        'site', accueil_site::text,
        'activate_gojika', activate_gojika,
        'user_id', requesting_user_id::text
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. REMPLACER prepare_staff_data
DROP FUNCTION IF EXISTS public.prepare_staff_data(TEXT, TEXT, public.role_enum, public.site_enum);

CREATE OR REPLACE FUNCTION public.prepare_staff_data(
    email TEXT,
    nom_complet TEXT,
    role public.role_enum,
    site public.site_enum,
    requesting_user_id uuid -- AJOUT
)
RETURNS jsonb
AS $$
DECLARE
    requester_role public.role_enum;
BEGIN
    -- Vérifier que l'utilisateur est bien 'admin'
    SELECT profiles.role INTO requester_role
    FROM public.profiles
    WHERE id = requesting_user_id;

    IF requester_role <> 'admin' THEN
        RAISE EXCEPTION 'Action non autorisée. Seul un Admin peut créer du personnel.';
    END IF;

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

-- 3. REMPLACER prepare_user_deletion
DROP FUNCTION IF EXISTS public.prepare_user_deletion(uuid);

CREATE OR REPLACE FUNCTION public.prepare_user_deletion(
    user_id uuid,
    requesting_user_id uuid -- AJOUT
)
RETURNS jsonb
AS $$
DECLARE
    user_email TEXT;
    user_role TEXT;
    requester_role public.role_enum;
BEGIN
    -- Vérifier que l'utilisateur est bien 'admin'
    SELECT profiles.role INTO requester_role
    FROM public.profiles
    WHERE id = requesting_user_id;

    IF requester_role <> 'admin' THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

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

-- 4. METTRE À JOUR LES PERMISSIONS
GRANT EXECUTE ON FUNCTION public.prepare_student_data(jsonb, BOOLEAN, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_staff_data(TEXT, TEXT, public.role_enum, public.site_enum, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_user_deletion(uuid, uuid) TO authenticated;