-- ================================================================
-- CORRECTION FINALE PHASE 1
-- ================================================================

-- 1. FIX: get_bag_report avec numéro d'ordre et id_etudiant_genere
DROP FUNCTION IF EXISTS public.get_bag_report(text, text);

CREATE OR REPLACE FUNCTION public.get_bag_report(site_filter text, groupe_filter text)
RETURNS TABLE(
    row_num bigint,
    id_etudiant_genere text,
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
        ROW_NUMBER() OVER (ORDER BY e.nom) AS row_num,
        e.id_etudiant_genere,
        e.nom,
        e.prenom,
        e.statut::text,
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
    FROM
        public.etudiants e
    LEFT JOIN
        public.paiement_items pi ON e.id = pi.id_etudiant
    LEFT JOIN
        public.recus r ON pi.id_recu = r.id
    WHERE
        e.site = site_filter::public.site_enum AND e.groupe = groupe_filter
    GROUP BY
        e.id, e.id_etudiant_genere, e.nom, e.prenom, e.statut
    ORDER BY
        e.nom;
END;
$$;

-- 2. FIX: Audit Log - Rendre les détails plus lisibles
CREATE OR REPLACE FUNCTION public.format_audit_details(details jsonb)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    result text := '';
    table_name text;
    old_data jsonb;
    new_data jsonb;
BEGIN
    table_name := details->>'table';
    old_data := details->'old_data';
    new_data := details->'new_data';

    result := 'Table: ' || COALESCE(table_name, 'N/A');

    IF old_data IS NOT NULL AND new_data IS NOT NULL THEN
        result := result || ' | Modification';
    ELSIF new_data IS NOT NULL THEN
        result := result || ' | Création';
    ELSIF old_data IS NOT NULL THEN
        result := result || ' | Suppression';
    END IF;

    RETURN result;
END;
$$;

-- 3. CORRECTION: Trigger generate_etudiant_id pour démarrer à 1 chaque année
CREATE OR REPLACE FUNCTION public.generate_etudiant_id()
RETURNS TRIGGER
AS $$
DECLARE
  user_site public.site_enum;
  current_year text;
  next_seq int;
BEGIN
  IF NEW.site IS NULL THEN
    SELECT site_rattache INTO user_site
    FROM public.profiles WHERE id = auth.uid();
    NEW.site := user_site;
  END IF;

  current_year := TO_CHAR(NOW(), 'YY');

  -- Calculer le prochain numéro de séquence pour cette année et ce site
  SELECT COALESCE(MAX(
    CAST(SPLIT_PART(id_etudiant_genere, '-', 1) AS INTEGER)
  ), 0) + 1 INTO next_seq
  FROM public.etudiants
  WHERE SPLIT_PART(id_etudiant_genere, '-', 2) = current_year
    AND site = NEW.site;

  NEW.id_etudiant_genere := next_seq || '-' || current_year || '-' || NEW.site;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;