-- ================================================================
-- MIGRATION 0017: Améliorations finales Phase 1
-- - Correction recherche paiements
-- - Sites dynamiques
-- - Modification profils utilisateurs
-- ================================================================

-- 1. CORRECTION: RPC pour rechercher les paiements (corrige l'erreur PGRST100)
CREATE OR REPLACE FUNCTION public.search_payments(search_query text)
RETURNS TABLE(
    item_id bigint,
    etudiant_id bigint,
    etudiant_nom text,
    etudiant_prenom text,
    etudiant_id_genere text,
    motif text,
    mois_de text,
    montant numeric,
    n_recu_principal text,
    ref_transaction text,
    date_paiement timestamptz,
    mode_paiement text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Vérifier les permissions
    IF public.get_my_role() NOT IN ('admin', 'controleur') THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

    RETURN QUERY
    SELECT
        pi.id AS item_id,
        e.id AS etudiant_id,
        e.nom AS etudiant_nom,
        e.prenom AS etudiant_prenom,
        e.id_etudiant_genere AS etudiant_id_genere,
        pi.motif,
        pi.mois_de,
        pi.montant,
        r.n_recu_principal,
        r.ref_transaction,
        r.date_paiement,
        r.mode_paiement
    FROM public.paiement_items pi
    JOIN public.etudiants e ON pi.id_etudiant = e.id
    JOIN public.recus r ON pi.id_recu = r.id
    WHERE
        e.nom ILIKE '%' || search_query || '%'
        OR e.prenom ILIKE '%' || search_query || '%'
        OR e.id_etudiant_genere ILIKE '%' || search_query || '%'
        OR r.n_recu_principal ILIKE '%' || search_query || '%'
    ORDER BY r.date_paiement DESC
    LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_payments(text) TO authenticated;

-- 2. RPC pour modifier un paiement complet
CREATE OR REPLACE FUNCTION public.update_payment_full(
    p_item_id bigint,
    p_new_motif text,
    p_new_montant numeric,
    p_new_mois_de text,
    p_new_n_recu text,
    p_new_ref text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_recu_id bigint;
    v_old_montant numeric;
BEGIN
    IF public.get_my_role() NOT IN ('admin', 'controleur') THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

    -- Récupérer les anciennes valeurs
    SELECT id_recu, montant INTO v_recu_id, v_old_montant
    FROM public.paiement_items
    WHERE id = p_item_id;

    IF v_recu_id IS NULL THEN
        RAISE EXCEPTION 'Paiement introuvable.';
    END IF;

    -- Mettre à jour l'item de paiement
    UPDATE public.paiement_items
    SET
        motif = p_new_motif,
        montant = p_new_montant,
        mois_de = p_new_mois_de
    WHERE id = p_item_id;

    -- Mettre à jour le reçu parent
    UPDATE public.recus
    SET
        n_recu_principal = p_new_n_recu,
        ref_transaction = p_new_ref,
        montant_total = montant_total - v_old_montant + p_new_montant
    WHERE id = v_recu_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Paiement mis à jour avec succès'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_payment_full(bigint, text, numeric, text, text, text) TO authenticated;

-- 3. RPC pour modifier le profil d'un utilisateur (Admin)
CREATE OR REPLACE FUNCTION public.update_user_profile(
    p_user_id uuid,
    p_nom_complet text,
    p_role text,
    p_site text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF public.get_my_role() <> 'admin' THEN
        RAISE EXCEPTION 'Action non autorisée. Seul un Admin peut modifier les profils.';
    END IF;

    UPDATE public.profiles
    SET
        nom_complet = p_nom_complet,
        role = p_role::public.role_enum,
        site_rattache = p_site::public.site_enum
    WHERE id = p_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Profil mis à jour avec succès'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_profile(uuid, text, text, text) TO authenticated;

-- 4. SYSTÈME DE SITES DYNAMIQUES
-- Convertir site_enum en table pour permettre l'ajout dynamique

-- 4.1 Créer une table pour les sites
CREATE TABLE IF NOT EXISTS public.sites (
    code TEXT PRIMARY KEY,
    nom TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4.2 Insérer les sites existants
INSERT INTO public.sites (code, nom) VALUES
    ('T', 'Antananarivo'),
    ('TO', 'Toamasina'),
    ('BO', 'Boeny'),
    ('BI', 'Bongolava'),
    ('FULL', 'Tous les sites')
ON CONFLICT (code) DO NOTHING;

-- 4.3 RLS pour la table sites
ALTER TABLE public.sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Tout utilisateur authentifié peut lire les sites"
    ON public.sites FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Admin peut gérer les sites"
    ON public.sites FOR ALL
    USING (public.get_my_role() IN ('admin', 'controleur'));

-- 4.4 Fonction pour ajouter un nouveau site
CREATE OR REPLACE FUNCTION public.add_new_site(
    p_code text,
    p_nom text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code_upper text;
BEGIN
    IF public.get_my_role() NOT IN ('admin', 'controleur') THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

    v_code_upper := UPPER(TRIM(p_code));

    -- Vérifier que le code n'existe pas déjà
    IF EXISTS (SELECT 1 FROM public.sites WHERE code = v_code_upper) THEN
        RAISE EXCEPTION 'Ce code de site existe déjà.';
    END IF;

    -- Ajouter à la table sites
    INSERT INTO public.sites (code, nom) VALUES (v_code_upper, p_nom);

    -- Ajouter au type ENUM (ALTER TYPE)
    EXECUTE format('ALTER TYPE public.site_enum ADD VALUE IF NOT EXISTS %L', v_code_upper);

    -- Ajouter à config_options pour les listes déroulantes
    INSERT INTO public.config_options (categorie, valeur)
    VALUES ('Site', v_code_upper)
    ON CONFLICT (categorie, valeur) DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'code', v_code_upper,
        'nom', p_nom,
        'message', 'Site ajouté avec succès'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_new_site(text, text) TO authenticated;

-- 4.5 Fonction pour récupérer tous les sites actifs
CREATE OR REPLACE FUNCTION public.get_all_sites()
RETURNS TABLE(code text, nom text)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT s.code, s.nom
    FROM public.sites s
    WHERE s.is_active = true
    ORDER BY
        CASE WHEN s.code = 'FULL' THEN 0 ELSE 1 END,
        s.code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_sites() TO authenticated;

-- 5. Fonction pour rechercher les étudiants (pour modification)
CREATE OR REPLACE FUNCTION public.search_students_for_edit(search_query text)
RETURNS TABLE(
    id bigint,
    id_etudiant_genere text,
    nom text,
    prenom text,
    email_contact text,
    telephone text,
    site text,
    groupe text,
    statut text,
    photo_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF public.get_my_role() NOT IN ('admin', 'controleur') THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

    RETURN QUERY
    SELECT
        e.id,
        e.id_etudiant_genere,
        e.nom,
        e.prenom,
        e.email_contact,
        e.telephone,
        e.site::text,
        e.groupe,
        e.statut::text,
        e.photo_url
    FROM public.etudiants e
    WHERE
        e.nom ILIKE '%' || search_query || '%'
        OR e.prenom ILIKE '%' || search_query || '%'
        OR e.id_etudiant_genere ILIKE '%' || search_query || '%'
        OR e.email_contact ILIKE '%' || search_query || '%'
    ORDER BY e.nom
    LIMIT 20;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_students_for_edit(text) TO authenticated;

-- 6. Fonction pour modifier un étudiant
CREATE OR REPLACE FUNCTION public.update_student_info(
    p_student_id bigint,
    p_nom text,
    p_prenom text,
    p_email text,
    p_telephone text,
    p_groupe text,
    p_statut text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF public.get_my_role() NOT IN ('admin', 'controleur') THEN
        RAISE EXCEPTION 'Action non autorisée.';
    END IF;

    UPDATE public.etudiants
    SET
        nom = p_nom,
        prenom = p_prenom,
        email_contact = p_email,
        telephone = p_telephone,
        groupe = p_groupe,
        statut = p_statut::public.statut_etudiant_enum,
        statut_maj_le = NOW()
    WHERE id = p_student_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Informations étudiant mises à jour'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_student_info(bigint, text, text, text, text, text, text) TO authenticated;