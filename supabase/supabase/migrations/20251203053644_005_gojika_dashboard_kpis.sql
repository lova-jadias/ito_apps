-- ================================================================
-- MIGRATION GOJIKA : Dashboard & KPIs
-- ================================================================

-- Fonction : KPIs Dashboard RP/Responsable
CREATE OR REPLACE FUNCTION public.get_dashboard_gojika(
  p_site public.site_enum DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_result jsonb;
  v_effectif_total INT;
  v_nb_rouge INT;
  v_nb_orange INT;
  v_nb_jaune INT;
  v_nb_vert INT;
  v_taux_presence NUMERIC;
  v_moyenne_generale NUMERIC;
BEGIN
  -- Filtrer par site si spécifié
  SELECT COUNT(*) INTO v_effectif_total
  FROM public.etudiants
  WHERE statut = 'Actif' AND (p_site IS NULL OR site = p_site);

  -- Répartition par niveau de risque (Utilisation de requêtes séparées pour contourner l'erreur de l'analyseur)

  SELECT COUNT(*) INTO v_nb_rouge FROM public.etudiants WHERE statut = 'Actif' AND (p_site IS NULL OR site = p_site) AND risk_score >= 70;
  SELECT COUNT(*) INTO v_nb_orange FROM public.etudiants WHERE statut = 'Actif' AND (p_site IS NULL OR site = p_site) AND risk_score >= 50 AND risk_score < 70;
  SELECT COUNT(*) INTO v_nb_jaune FROM public.etudiants WHERE statut = 'Actif' AND (p_site IS NULL OR site = p_site) AND risk_score >= 30 AND risk_score < 50;
  SELECT COUNT(*) INTO v_nb_vert FROM public.etudiants WHERE statut = 'Actif' AND (p_site IS NULL OR site = p_site) AND risk_score < 30;

  -- Taux de présence moyen (30 derniers jours)
  SELECT
    100 - (COUNT(a.id)::NUMERIC / NULLIF(COUNT(DISTINCT s.id) * v_effectif_total, 0) * 100)
  INTO v_taux_presence
  FROM public.seances s
  LEFT JOIN public.absences a ON s.id = a.seance_id AND a.justification_id IS NULL
  WHERE s.date_seance >= CURRENT_DATE - INTERVAL '30 days';

  -- Moyenne générale du site
  SELECT AVG(public.calculer_moyenne_etudiant(e.id, NULL, NULL))
  INTO v_moyenne_generale
  FROM public.etudiants e
  WHERE e.statut = 'Actif' AND (p_site IS NULL OR e.site = p_site);

  v_result := jsonb_build_object(
    'effectif_total', v_effectif_total,
    'risque', jsonb_build_object(
      'rouge', v_nb_rouge,
      'orange', v_nb_orange,
      'jaune', v_nb_jaune,
      'vert', v_nb_vert
    ),
    'taux_presence', COALESCE(v_taux_presence, 0),
    'moyenne_generale', COALESCE(v_moyenne_generale, 0)
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_dashboard_gojika(public.site_enum) TO authenticated;

-- Fonction : Statistiques de fréquentation journalière (30 derniers jours)
CREATE OR REPLACE FUNCTION public.get_frequentation_journaliere(
  p_site public.site_enum DEFAULT NULL
)
RETURNS TABLE(
  date_jour DATE,
  nb_presents INT,
  nb_absents INT,
  taux_presence NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.date_seance AS date_jour,
    (
      SELECT COUNT(DISTINCT e.id)::INT
      FROM public.etudiants e
      WHERE e.statut = 'Actif' AND (p_site IS NULL OR e.site = p_site)
        AND e.id NOT IN (
          SELECT a.etudiant_id FROM public.absences a WHERE a.seance_id = s.id
        )
    ) AS nb_presents,
    (
      SELECT COUNT(DISTINCT a.etudiant_id)::INT
      FROM public.absences a
      WHERE a.seance_id = s.id
    ) AS nb_absents,
    (
      SELECT
        (nb_presents::NUMERIC / NULLIF(nb_presents + nb_absents, 0) * 100)
    ) AS taux_presence
  FROM public.seances s
  WHERE s.date_seance >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY s.date_seance
  ORDER BY s.date_seance DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_frequentation_journaliere(public.site_enum) TO authenticated;

-- Fonction : Moyennes par groupe
CREATE OR REPLACE FUNCTION public.get_moyennes_groupes(
  p_site public.site_enum DEFAULT NULL
)
RETURNS TABLE(
  groupe TEXT,
  moyenne_groupe NUMERIC,
  nb_etudiants INT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.groupe,
    AVG(public.calculer_moyenne_etudiant(e.id, NULL, NULL)) AS moyenne_groupe,
    COUNT(e.id)::INT AS nb_etudiants
  FROM public.etudiants e
  WHERE e.statut = 'Actif' AND (p_site IS NULL OR e.site = p_site)
  GROUP BY e.groupe
  ORDER BY moyenne_groupe DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_moyennes_groupes(public.site_enum) TO authenticated;

-- Vue : Prochains événements (30 jours)
CREATE OR REPLACE VIEW public.vw_evenements_prochains AS
SELECT
  e.id,
  e.titre,
  e.description,
  e.date_debut,
  e.date_fin,
  e.type_evenement,
  e.groupe_cible,
  e.site
FROM public.evenements_academiques e
WHERE e.date_debut >= CURRENT_DATE AND e.date_debut <= CURRENT_DATE + INTERVAL '30 days'
ORDER BY e.date_debut;

GRANT SELECT ON public.vw_evenements_prochains TO authenticated;