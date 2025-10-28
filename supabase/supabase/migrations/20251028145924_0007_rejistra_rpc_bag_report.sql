-- Fichier: supabase/migrations/xxxx_rejistra_rpc_bag_report.sql
CREATE OR REPLACE FUNCTION public.get_bag_report(site_filter text, groupe_filter text)
RETURNS TABLE(
    id bigint,
    nom text,
    prenom text,
    statut text,
    "DI+FG" text,
    "T-Shirt" text,
    "Écolage mensuel (Mois 1)" text,
    "Écolage mensuel (Mois 2)" text,
    "Écolage mensuel (Mois 3)" text
    -- Ajoutez d'autres motifs/mois ici si nécessaire
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
        MAX(CASE WHEN pi.motif = 'DI+FG' THEN r.n_recu_principal END) AS "DI+FG",
        MAX(CASE WHEN pi.motif = 'T-Shirt' THEN r.n_recu_principal END) AS "T-Shirt",
        MAX(CASE WHEN pi.motif = 'Écolage mensuel' AND pi.mois_de = 'Mois 1' THEN r.n_recu_principal END) AS "Écolage mensuel (Mois 1)",
        MAX(CASE WHEN pi.motif = 'Écolage mensuel' AND pi.mois_de = 'Mois 2' THEN r.n_recu_principal END) AS "Écolage mensuel (Mois 2)",
        MAX(CASE WHEN pi.motif = 'Écolage mensuel' AND pi.mois_de = 'Mois 3' THEN r.n_recu_principal END) AS "Écolage mensuel (Mois 3)"
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