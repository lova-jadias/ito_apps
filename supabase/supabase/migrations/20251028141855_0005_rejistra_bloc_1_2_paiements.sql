-- Fichier: supabase/migrations/xxxx_rejistra_bloc_1_2_paiements.sql

-- #################################################
-- ### 1. TRIGGER POUR CRÉATION COMPTE GOJIKA (Source: 1251)
-- #################################################
-- Ce trigger notifiera une Edge Function (à créer en Phase 2)
-- chaque fois qu'un paiement pour un Droit d'Inscription ('DI+FG') est inséré.
CREATE OR REPLACE FUNCTION public.notify_gojika_account_creation()
RETURNS TRIGGER
AS $$
BEGIN
  -- Notifie une Edge Function pour gérer la création de compte et l'envoi d'email
  PERFORM pg_notify(
    'gojika_creation_queue',
    json_build_object(
      'etudiant_id', NEW.id_etudiant,
      'motif', NEW.motif
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Applique le trigger APRÈS l'insertion sur la table 'paiement_items'
-- SEULEMENT si le motif est 'DI+FG'
CREATE TRIGGER on_first_payment_item
  AFTER INSERT ON public.paiement_items
  FOR EACH ROW
  WHEN (NEW.motif = 'DI+FG')
  EXECUTE FUNCTION public.notify_gojika_account_creation();

-- #################################################
-- ### 2. POLITIQUES RLS (LECTURE/ÉCRITURE) (Source: 1249-1250)
-- #################################################

-- --- Table 'recus' ---
CREATE POLICY "Le personnel financier voit les paiements de son site"
  ON public.recus FOR SELECT USING (
    get_my_role() IN ('admin', 'controleur') OR
    (get_my_role() IN ('responsable', 'accueil') AND (site = get_my_site() OR get_my_site() = 'FULL'))
  );

CREATE POLICY "Accueil peut créer des reçus"
  ON public.recus FOR INSERT
  WITH CHECK (get_my_role() = 'accueil');

-- --- Table 'paiement_items' ---
CREATE POLICY "Le personnel financier voit les lignes de paiement de son site"
  ON public.paiement_items FOR SELECT USING (
    get_my_role() IN ('admin', 'controleur') OR
    (
      get_my_role() IN ('responsable', 'accueil') AND
      id_etudiant IN (
        SELECT id FROM public.etudiants WHERE site = get_my_site()
      )
    ) OR
    (get_my_role() IN ('responsable', 'accueil') AND get_my_site() = 'FULL')
  );

CREATE POLICY "Accueil peut créer des lignes de paiement"
    ON public.paiement_items FOR INSERT
    WITH CHECK (get_my_role() = 'accueil');