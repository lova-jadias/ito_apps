-- supabase/migrations/XXXXXXXXX_0018_fix_admin_search_and_edit.sql

-- ================================================================
-- MIGRATION 0018: Correction recherche et édition avancée
-- - Recherche unifiée (étudiants + paiements)
-- - Modification complète des informations
-- ================================================================

-- supabase/migrations/XXXXXXXXX_0018_fix_admin_search_and_edit.sql

-- ================================================================
-- MIGRATION 0018: Correction recherche et édition avancée
-- ================================================================

-- ✅ SUPPRIMER LES ANCIENNES VERSIONS DES FONCTIONS
DROP FUNCTION IF EXISTS public.search_payments(text);
DROP FUNCTION IF EXISTS public.update_payment_full(bigint, text, numeric, text, text, text);
DROP FUNCTION IF EXISTS public.search_students_for_edit(text);
DROP FUNCTION IF EXISTS public.update_student_info(bigint, text, text, text, text, date, text, text, text, text, text);

-- 1. FONCTION: Recherche unifiée étudiants + paiements
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

-- 2. FONCTION: Modifier un paiement complet
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

-- 3. FONCTION: Rechercher des étudiants pour modification
CREATE OR REPLACE FUNCTION public.search_students_for_edit(search_query text)
RETURNS TABLE(
    id bigint,
    id_etudiant_genere text,
    nom text,
    prenom text,
    email_contact text,
    telephone text,
    date_naissance date,
    site text,
    mention_module text,
    niveau text,
    groupe text,
    departement text,
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
        e.date_naissance,
        e.site::text,
        e.mention_module,
        e.niveau,
        e.groupe,
        e.departement,
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

-- 4. FONCTION: Modifier les informations d'un étudiant
CREATE OR REPLACE FUNCTION public.update_student_info(
    p_student_id bigint,
    p_nom text,
    p_prenom text,
    p_email text,
    p_telephone text,
    p_date_naissance date,
    p_mention_module text,
    p_niveau text,
    p_groupe text,
    p_departement text,
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
        date_naissance = p_date_naissance,
        mention_module = p_mention_module,
        niveau = p_niveau,
        groupe = p_groupe,
        departement = p_departement,
        statut = p_statut::public.statut_etudiant_enum,
        statut_maj_le = NOW()
    WHERE id = p_student_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Informations étudiant mises à jour'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_student_info(bigint, text, text, text, text, date, text, text, text, text, text) TO authenticated;