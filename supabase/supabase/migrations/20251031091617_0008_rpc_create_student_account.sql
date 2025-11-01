-- Fichier: supabase/migrations/XXXXXXXX_0008_rpc_create_student_account.sql

-- 1. Mettre à jour la table etudiants
ALTER TABLE public.etudiants
ADD COLUMN gojika_account_active BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN gojika_must_reset_password BOOLEAN NOT NULL DEFAULT true;

-- 2. Ajouter les commentaires pour la documentation
COMMENT ON COLUMN public.etudiants.gojika_account_active IS
'Le compte GOJIKA est-il activé (par Admin/Accueil/RP) ?';
COMMENT ON COLUMN public.etudiants.gojika_must_reset_password IS
'L''étudiant doit-il changer son MDP à la prochaine connexion ?';

-- 3. Créer la Fonction RPC create_student_account
-- Cette fonction sera appelée par REJISTRA (rôle 'accueil')
CREATE OR REPLACE FUNCTION public.create_student_account(
    student_data jsonb, -- Données du formulaire (nom, prenom, email, etc.)
    temp_password TEXT, -- Mot de passe généré côté client
    activate_gojika BOOLEAN DEFAULT false -- Interrupteur d'activation
)
RETURNS jsonb -- Renvoie le nouvel étudiant et son ID généré
AS $$
DECLARE
    new_user_id uuid;
    new_student_id bigint;
    generated_student_id TEXT;
    accueil_site public.site_enum;
BEGIN
    -- 1. Vérifier que l'exécutant est bien 'Accueil'
    SELECT site_rattache INTO accueil_site
    FROM public.profiles
    WHERE id = auth.uid() AND role = 'accueil';

    IF accueil_site IS NULL THEN
        RAISE EXCEPTION 'Action non autorisée. Seul le rôle "Accueil" peut créer des étudiants.';
    END IF;

    -- 2. Créer l'utilisateur dans auth.users
    INSERT INTO auth.users (email, password, role, raw_user_meta_data)
    VALUES (
        student_data->>'email_contact',
        temp_password,
        'authenticated',
        jsonb_build_object(
            'role', 'etudiant',
            'site', accueil_site::text
        )
    ) RETURNING id INTO new_user_id;

    -- 3. Créer l'étudiant dans public.etudiants
    INSERT INTO public.etudiants (
        nom, prenom, date_naissance, email_contact, telephone,
        mention_module, niveau, groupe, departement,
        site, -- Forcé par le site de l'Accueil
        gojika_account_linked, -- Lier le compte Auth
        gojika_account_active, -- Statut d'activation depuis le formulaire
        gojika_must_reset_password -- Reste TRUE par défaut
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
        accueil_site,
        new_user_id,
        activate_gojika
    ) RETURNING id, id_etudiant_genere INTO new_student_id, generated_student_id;

    -- 4. Renvoyer les infos (sans le mot de passe)
    RETURN jsonb_build_object(
        'id', new_student_id,
        'id_etudiant_genere', generated_student_id,
        'email', student_data->>'email_contact'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Donner la permission à 'Accueil' (rôle 'authenticated') d'appeler cette fonction
GRANT EXECUTE
ON FUNCTION public.create_student_account(jsonb, TEXT, BOOLEAN)
TO authenticated;