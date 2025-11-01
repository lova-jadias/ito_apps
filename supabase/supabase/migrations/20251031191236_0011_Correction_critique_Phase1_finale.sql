-- =================================================================
-- FIX 1: Correction de la création d'étudiant (Migration 0008)
-- Recrée la fonction create_student_account pour s'assurer qu'elle est correcte.
-- =================================================================
CREATE OR REPLACE FUNCTION public.create_student_account(
    student_data jsonb,
    temp_password TEXT,
    activate_gojika BOOLEAN DEFAULT false
)
RETURNS jsonb
AS $$
DECLARE
    new_user_id uuid;
    new_student_id bigint;
    generated_student_id TEXT;
    accueil_site public.site_enum;
BEGIN
    SELECT site_rattache INTO accueil_site
    FROM public.profiles
    WHERE id = auth.uid() AND role = 'accueil';

    IF accueil_site IS NULL THEN
        RAISE EXCEPTION 'Action non autorisée. Seul le rôle "Accueil" peut créer des étudiants.';
    END IF;

    -- L'INSERT dans auth.users utilise la colonne 'password' qui est
    -- une colonne virtuelle gérée par Supabase pour hacher le mot de passe.
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
        accueil_site,
        new_user_id,
        activate_gojika,
        true -- gojika_must_reset_password
    ) RETURNING id, id_etudiant_genere INTO new_student_id, generated_student_id;

    RETURN jsonb_build_object(
        'id', new_student_id,
        'id_etudiant_genere', generated_student_id,
        'email', student_data->>'email_contact'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =================================================================
-- FIX 2: Ajout RPC pour GESTION UTILISATEURS (Admin)
-- Remplace l'appel `auth.admin.createUser` côté client (qui cause l'erreur 403)
-- =================================================================
CREATE OR REPLACE FUNCTION public.create_staff_user(
    email TEXT,
    password TEXT,
    nom_complet TEXT,
    role public.role_enum,
    site public.site_enum
)
RETURNS jsonb
AS $$
DECLARE
    new_user_id uuid;
BEGIN
    -- 1. Vérifier que l'exécutant est bien 'admin'
    IF public.get_my_role() <> 'admin' THEN
        RAISE EXCEPTION 'Action non autorisée. Seul un Admin peut créer du personnel.';
    END IF;

    -- 2. Créer l'utilisateur dans auth.users
    INSERT INTO auth.users (email, password, role, raw_user_meta_data)
    VALUES (
        email,
        password,
        'authenticated',
        jsonb_build_object(
            'role', role::text,
            'site', site::text
        )
    ) RETURNING id INTO new_user_id;

    -- 3. Le trigger 'on_auth_user_created' va créer le profil.
    -- Nous mettons à jour le nom_complet manuellement.
    UPDATE public.profiles
    SET nom_complet = create_staff_user.nom_complet
    WHERE id = new_user_id;

    RETURN jsonb_build_object('id', new_user_id, 'email', email);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour supprimer un utilisateur (Admin)
CREATE OR REPLACE FUNCTION public.delete_staff_user(user_id uuid)
RETURNS text
AS $$
BEGIN
    IF public.get_my_role() <> 'admin' THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

    -- Utilise l'API admin pour supprimer l'utilisateur de 'auth.users'
    -- Le 'ON DELETE CASCADE' sur la table 'profiles' s'occupera du profil.
    PERFORM auth.admin_delete_user(user_id);

    RETURN 'Utilisateur ' || user_id || ' supprimé.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Donner la permission d'exécuter ces fonctions
GRANT EXECUTE ON FUNCTION public.create_staff_user(TEXT, TEXT, TEXT, public.role_enum, public.site_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_staff_user(uuid) TO authenticated;

-- =================================================================
-- FIX 3: Mise à jour du Rapport BAG (Migration 0007)
-- Réorganise les colonnes selon votre demande.
-- =================================================================

--- CORRECTION AJOUTÉE ---
-- On supprime l'ancienne fonction avant de la recréer avec la nouvelle signature
DROP FUNCTION IF EXISTS public.get_bag_report(text, text);
--- FIN CORRECTION ---

CREATE OR REPLACE FUNCTION public.get_bag_report(site_filter text, groupe_filter text)
RETURNS TABLE(
    id bigint,
    nom text,
    prenom text,
    statut text,
    "DI+FG" text,
    "T-Shirt" text,
    "Instruments Médicaux" text,
    "Mois 1" text,
    "Mois 2" text,
    "Mois 3" text,
    "Mois 4" text,
    "Mois 5" text,
    "DE 1" text,
    "DRepê1" text,
    "Mois 6" text,
    "Mois 7" text,
    "Mois 8" text,
    "Mois 9" text,
    "Mois 10" text,
    "DE 2" text,
    "DRepê2" text,
    "DEnc" text,
    "DSout" text,
    "BS" text,
    "Certification de scolarité" text,
    "Attestation" text,
    "Droit de diplôme" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id,
        e.nom,
        e.prenom,
        e.statut::text,
        -- Pivot pour chaque motif/mois, récupère le n_recu_principal
        MAX(CASE WHEN pi.motif = 'DI+FG' THEN r.n_recu_principal END) AS "DI+FG",
        MAX(CASE WHEN pi.motif = 'T-Shirt' THEN r.n_recu_principal END) AS "T-Shirt",
        MAX(CASE WHEN pi.motif = 'Instruments Médicaux' THEN r.n_recu_principal END) AS "Instruments Médicaux",
        MAX(CASE WHEN pi.mois_de = 'Mois 1' THEN r.n_recu_principal END) AS "Mois 1",
        MAX(CASE WHEN pi.mois_de = 'Mois 2' THEN r.n_recu_principal END) AS "Mois 2",
        MAX(CASE WHEN pi.mois_de = 'Mois 3' THEN r.n_recu_principal END) AS "Mois 3",
        MAX(CASE WHEN pi.mois_de = 'Mois 4' THEN r.n_recu_principal END) AS "Mois 4",
        MAX(CASE WHEN pi.mois_de = 'Mois 5' THEN r.n_recu_principal END) AS "Mois 5",
        MAX(CASE WHEN pi.motif = 'DE 1' THEN r.n_recu_principal END) AS "DE 1",
        MAX(CASE WHEN pi.motif = 'DRepê1' THEN r.n_recu_principal END) AS "DRepê1",
        MAX(CASE WHEN pi.mois_de = 'Mois 6' THEN r.n_recu_principal END) AS "Mois 6",
        MAX(CASE WHEN pi.mois_de = 'Mois 7' THEN r.n_recu_principal END) AS "Mois 7",
        MAX(CASE WHEN pi.mois_de = 'Mois 8' THEN r.n_recu_principal END) AS "Mois 8",
        MAX(CASE WHEN pi.mois_de = 'Mois 9' THEN r.n_recu_principal END) AS "Mois 9",
        MAX(CASE WHEN pi.mois_de = 'Mois 10' THEN r.n_recu_principal END) AS "Mois 10",
        MAX(CASE WHEN pi.motif = 'DE 2' THEN r.n_recu_principal END) AS "DE 2",
        MAX(CASE WHEN pi.motif = 'DRepê2' THEN r.n_recu_principal END) AS "DRepê2",
        MAX(CASE WHEN pi.motif = 'DEnc' THEN r.n_recu_principal END) AS "DEnc",
        MAX(CASE WHEN pi.motif = 'DSout' THEN r.n_recu_principal END) AS "DSout",
        MAX(CASE WHEN pi.motif = 'BS' THEN r.n_recu_principal END) AS "BS",
        MAX(CASE WHEN pi.motif = 'Certification de scolarité' THEN r.n_recu_principal END) AS "Certification de scolarité",
        MAX(CASE WHEN pi.motif = 'Attestation' THEN r.n_recu_principal END) AS "Attestation",
        MAX(CASE WHEN pi.motif = 'Droit de diplôme' THEN r.n_recu_principal END) AS "Droit de diplôme"
        -- NOTE: Les nouveaux motifs de 'config_options' ne seront pas
        -- automatiquement ajoutés ici. Cette fonction devra être
        -- mise à jour si vous ajoutez de nouveaux motifs à pivoter.
    FROM
        public.etudiants e
    LEFT JOIN
        public.paiement_items pi ON e.id = pi.id_etudiant
    LEFT JOIN
        public.recus r ON pi.id_recu = r.id
    WHERE
        e.site = site_filter::public.site_enum AND e.groupe = groupe_filter
    GROUP BY
        e.id, e.nom, e.prenom, e.statut
    ORDER BY
        e.nom;
END;
$$;

-- =================================================================
-- FIX 4: RPC pour le Dashboard Dynamique
-- =================================================================

-- Fonction pour les KPIs
CREATE OR REPLACE FUNCTION public.get_dashboard_kpis(site_filter public.site_enum DEFAULT NULL)
RETURNS jsonb
AS $$
DECLARE
    etudiants_query text;
    recus_query text;
    brut int;
    abandons int;
    net int;
    ca_jour numeric;
    ca_global numeric;
BEGIN
    -- Construire les requêtes de base
    etudiants_query := 'SELECT * FROM public.etudiants';
    recus_query := 'SELECT * FROM public.recus';

    -- Appliquer le filtre de site si fourni (non 'FULL')
    IF site_filter IS NOT NULL AND site_filter <> 'FULL' THEN
        etudiants_query := etudiants_query || ' WHERE site = ''' || site_filter::text || '''';
        recus_query := recus_query || ' WHERE site = ''' || site_filter::text || '''';
    END IF;

    -- Calculer les KPIs
    EXECUTE 'SELECT COUNT(*) FROM (' || etudiants_query || ') AS e' INTO brut;
    EXECUTE 'SELECT COUNT(*) FROM (' || etudiants_query || ') AS e WHERE e.statut = ''Abandon''' INTO abandons;
    net := brut - abandons;

    -- Formatage des dates pour le CA
    DECLARE
        today_start text := to_char(NOW(), 'YYYY-MM-DD 00:00:00');
        today_end text := to_char(NOW(), 'YYYY-MM-DD 23:59:59');
    BEGIN
        EXECUTE 'SELECT COALESCE(SUM(r.montant_total), 0) FROM (' || recus_query || ') AS r WHERE r.date_paiement BETWEEN ''' || today_start || ''' AND ''' || today_end || '''' INTO ca_jour;
        EXECUTE 'SELECT COALESCE(SUM(r.montant_total), 0) FROM (' || recus_query || ') AS r' INTO ca_global;
    END;

    RETURN jsonb_build_object(
        'effectifBrut', brut,
        'abandons', abandons,
        'effectifNet', net,
        'caJournalier', ca_jour,
        'caGlobal', ca_global
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Fonction pour les graphiques
CREATE OR REPLACE FUNCTION public.get_dashboard_charts(site_filter public.site_enum DEFAULT NULL)
RETURNS jsonb
AS $$
DECLARE
    effectifs_par_groupe jsonb;
    ca_mensuel jsonb;
BEGIN
    -- 1. Effectifs par groupe (ou par site si filtre 'FULL')
    IF site_filter IS NULL OR site_filter = 'FULL' THEN
        -- Agréger par SITE
        SELECT jsonb_object_agg(COALESCE(site::text, 'N/A'), count)
        FROM (
            SELECT site, COUNT(*) as count
            FROM public.etudiants
            GROUP BY site
        ) AS sub
        INTO effectifs_par_groupe;
    ELSE
        -- Agréger par GROUPE pour le site filtré
        SELECT jsonb_object_agg(COALESCE(groupe, 'N/A'), count)
        FROM (
            SELECT groupe, COUNT(*) as count
            FROM public.etudiants
            WHERE site = site_filter
            GROUP BY groupe
        ) AS sub
        INTO effectifs_par_groupe;
    END IF;

    -- 2. CA Mensuel (sur 12 mois glissants)
    SELECT jsonb_object_agg(mois, total)
    FROM (
        SELECT
            to_char(date_trunc('month', date_paiement), 'YYYY-MM') AS mois,
            SUM(montant_total) AS total
        FROM public.recus
        WHERE
            (site_filter IS NULL OR site_filter = 'FULL' OR site = site_filter)
            AND date_paiement >= date_trunc('month', NOW() - interval '11 months')
        GROUP BY 1
        ORDER BY 1
    ) AS sub_ca
    INTO ca_mensuel;

    RETURN jsonb_build_object(
        'effectifs', effectifs_par_groupe,
        'caMensuel', ca_mensuel
    );
END;
$$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION public.get_dashboard_kpis(public.site_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dashboard_charts(public.site_enum) TO authenticated;


-- =================================================================
-- FIX 5: RPC pour Modifier/Annuler un Paiement (Nouvelle fonctionnalité)
-- =================================================================
CREATE OR REPLACE FUNCTION public.update_payment_details(
    p_item_id bigint,
    p_new_motif text,
    p_new_n_recu text,
    p_new_ref text
)
RETURNS void
AS $$
DECLARE
    v_recu_id bigint;
BEGIN
    IF public.get_my_role() NOT IN ('admin', 'controleur') THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

    -- 1. Trouver l'ID du reçu parent
    SELECT id_recu INTO v_recu_id
    FROM public.paiement_items
    WHERE id = p_item_id;

    -- 2. Mettre à jour le reçu parent
    UPDATE public.recus
    SET
        n_recu_principal = p_new_n_recu,
        ref_transaction = p_new_ref
    WHERE id = v_recu_id;

    -- 3. Mettre à jour l'item de paiement
    UPDATE public.paiement_items
    SET motif = p_new_motif
    WHERE id = p_item_id;

    -- 4. Audit
    -- (Le trigger d'audit sur 'recus' devrait déjà s'activer)

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.cancel_payment(p_item_id bigint, reason text)
RETURNS void
AS $$
DECLARE
    v_recu_id bigint;
    v_montant numeric;
BEGIN
    IF public.get_my_role() NOT IN ('admin', 'controleur') THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

    -- 1. Trouver le montant et l'ID du reçu
    SELECT id_recu, montant INTO v_recu_id, v_montant
    FROM public.paiement_items
    WHERE id = p_item_id;

    -- 2. Mettre à jour le montant de l'item à 0
    UPDATE public.paiement_items
    SET
        montant = 0,
        motif = 'ANNULÉ - ' || motif || ' (Raison: ' || reason || ')'
    WHERE id = p_item_id;

    -- 3. Mettre à jour le montant total du reçu
    UPDATE public.recus
    SET montant_total = montant_total - v_montant
    WHERE id = v_recu_id;

    -- 4. Audit
    -- (Le trigger d'audit s'activera)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.update_payment_details(bigint, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_payment(bigint, text) TO authenticated;

