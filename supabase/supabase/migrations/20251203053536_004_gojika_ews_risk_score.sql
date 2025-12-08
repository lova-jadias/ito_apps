-- ================================================================
-- MIGRATION GOJIKA : Système d'alerte précoce (EWS)
-- ================================================================

-- Fonction : Calculer le score de risque d'un étudiant
CREATE OR REPLACE FUNCTION public.calculer_risk_score(p_etudiant_id BIGINT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_score INT := 0;
  v_nb_absences INT;
  v_moyenne NUMERIC;
  v_solde_ecolage NUMERIC;
BEGIN
  -- Critère 1 : Absences non justifiées (max 40 points)
  SELECT COUNT(*) INTO v_nb_absences
  FROM public.absences a
  WHERE a.etudiant_id = p_etudiant_id
    AND a.justification_id IS NULL
    AND a.date_absence >= CURRENT_DATE - INTERVAL '30 days';

  v_score := v_score + LEAST(v_nb_absences * 10, 40);

  -- Critère 2 : Baisse de la moyenne (max 30 points)
  v_moyenne := public.calculer_moyenne_etudiant(p_etudiant_id, NULL, NULL);

  IF v_moyenne < 5 THEN
    v_score := v_score + 30;
  ELSIF v_moyenne < 10 THEN
    v_score := v_score + 20;
  ELSIF v_moyenne < 12 THEN
    v_score := v_score + 10;
  END IF;

  -- Critère 3 : Retard de paiement (max 30 points)
  SELECT
    COALESCE(SUM(CASE WHEN pi.motif NOT LIKE 'ANNULÉ%' THEN pi.montant ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN r.montant_total > 0 AND pi.motif NOT LIKE 'ANNULÉ%' THEN pi.montant ELSE 0 END), 0)
  INTO v_solde_ecolage
  FROM public.etudiants e
  LEFT JOIN public.paiement_items pi ON e.id = pi.id_etudiant
  LEFT JOIN public.recus r ON pi.id_recu = r.id
  WHERE e.id = p_etudiant_id;

  IF v_solde_ecolage > 500000 THEN
    v_score := v_score + 30;
  ELSIF v_solde_ecolage > 200000 THEN
    v_score := v_score + 20;
  ELSIF v_solde_ecolage > 0 THEN
    v_score := v_score + 10;
  END IF;

  -- Retour du score (0-100)
  RETURN LEAST(v_score, 100);
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculer_risk_score(BIGINT) TO authenticated;

-- Fonction : Mettre à jour le risk_score de tous les étudiants
CREATE OR REPLACE FUNCTION public.mettre_a_jour_risk_scores()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.etudiants
  SET risk_score = public.calculer_risk_score(id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.mettre_a_jour_risk_scores() TO authenticated;

-- Fonction : Obtenir les étudiants à risque d'un site
CREATE OR REPLACE FUNCTION public.get_etudiants_risque(
  p_site public.site_enum,
  p_niveau_risque TEXT DEFAULT NULL -- 'rouge', 'orange', 'jaune'
)
RETURNS TABLE(
  id BIGINT,
  nom TEXT,
  prenom TEXT,
  groupe TEXT,
  risk_score INT,
  niveau_risque TEXT,
  nb_absences INT,
  moyenne NUMERIC,
  solde_ecolage NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.nom,
    e.prenom,
    e.groupe,
    e.risk_score,
    CASE
      WHEN e.risk_score >= 70 THEN 'rouge'
      WHEN e.risk_score >= 50 THEN 'orange'
      WHEN e.risk_score >= 30 THEN 'jaune'
      ELSE 'vert'
    END AS niveau_risque,
    (SELECT COUNT(*)::INT FROM public.absences a WHERE a.etudiant_id = e.id AND a.justification_id IS NULL) AS nb_absences,
    public.calculer_moyenne_etudiant(e.id, NULL, NULL) AS moyenne,
    e.solde_ecolage AS solde_ecolage
  FROM public.etudiants e
  WHERE e.site = p_site AND e.statut = 'Actif'
    AND (p_niveau_risque IS NULL OR
      (p_niveau_risque = 'rouge' AND e.risk_score >= 70) OR
      (p_niveau_risque = 'orange' AND e.risk_score >= 50 AND e.risk_score < 70) OR
      (p_niveau_risque = 'jaune' AND e.risk_score >= 30 AND e.risk_score < 50)
    )
  ORDER BY e.risk_score DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_etudiants_risque(public.site_enum, TEXT) TO authenticated;

-- Trigger : Mettre à jour le risk_score automatiquement
CREATE OR REPLACE FUNCTION public.trigger_update_risk_score()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Mise à jour du risk_score de l'étudiant concerné
  UPDATE public.etudiants
  SET risk_score = public.calculer_risk_score(NEW.etudiant_id)
  WHERE id = NEW.etudiant_id;

  RETURN NEW;
END;
$$;

-- Appliquer le trigger sur absences et notes
CREATE TRIGGER update_risk_on_absence
  AFTER INSERT OR UPDATE ON public.absences
  FOR EACH ROW EXECUTE FUNCTION public.trigger_update_risk_score();

CREATE TRIGGER update_risk_on_note
  AFTER INSERT OR UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION public.trigger_update_risk_score();

CREATE TRIGGER update_risk_on_paiement
  AFTER INSERT OR UPDATE ON public.paiement_items
  FOR EACH ROW EXECUTE FUNCTION public.trigger_update_risk_score();