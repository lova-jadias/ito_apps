-- Fichier: ..._rejistra_bloc_1_1_inscription_dashboard.sql

-- #################################################
-- ### 1. TRIGGER DE GÉNÉRATION D'ID ÉTUDIANT (Source: 1080-1082)
-- #################################################
-- Cette fonction s'assure que lorsqu'un 'Accueil' crée un étudiant,
-- le 'site' est automatiquement hérité de l'utilisateur 'Accueil',
-- et 'id_etudiant_genere' est créé (ex: "123-25-T").

CREATE OR REPLACE FUNCTION public.generate_etudiant_id()
RETURNS TRIGGER
AS $$
DECLARE
  user_site public.site_enum;
BEGIN
  -- Récupère le site de l'utilisateur 'Accueil' qui effectue l'opération
  SELECT site_rattache INTO user_site
  FROM public.profiles WHERE id = auth.uid();

  -- Remplit le site de l'étudiant basé sur l'utilisateur
  NEW.site := user_site;

  -- Génère l'ID : "ID_Sequence-Année-CodeSite"
  -- (Utilise NEW.id, qui est l'ID auto-incrémenté de la table)
  NEW.id_etudiant_genere := NEW.id || '-' || TO_CHAR(NOW(), 'YY') || '-' || NEW.site;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Applique le trigger AVANT l'insertion sur la table 'etudiants'
CREATE TRIGGER before_etudiant_insert
  BEFORE INSERT ON public.etudiants
  FOR EACH ROW EXECUTE FUNCTION public.generate_etudiant_id();

-- #################################################
-- ### 2. POLITIQUES RLS (LECTURE/ÉCRITURE) (Source: 1233-1236)
-- #################################################

-- --- Table 'etudiants' ---

-- POLITIQUE D'INSERTION (Source: 1104)
-- Seul le rôle 'accueil' peut inscrire un nouvel étudiant.
CREATE POLICY "Accueil peut inscrire des étudiants"
  ON public.etudiants FOR INSERT
  WITH CHECK (get_my_role() = 'accueil');

-- POLITIQUE DE SÉLECTION (Source: 1099, 1100)
-- Les Admins/Contrôleurs et Responsables(Full) voient tout.
CREATE POLICY "Admins/Contrôleurs/Responsables (Full) voient tout"
  ON public.etudiants FOR SELECT USING (
    get_my_role() IN ('admin', 'controleur') OR
    (get_my_role() = 'responsable' AND get_my_site() = 'FULL')
  );

-- Le personnel (Accueil, RP, Responsable) voit son site.
-- (RP est inclus ici pour GOJIKA plus tard)
CREATE POLICY "Le personnel (Accueil, RP, Responsable) voit son site"
  ON public.etudiants FOR SELECT USING (
    get_my_role() IN ('accueil', 'rp', 'responsable') AND site = get_my_site()
  );

-- --- Table 'config_options' (Pour les listes déroulantes) ---

-- POLITIQUE DE SÉLECTION (Source: 1118)
-- TOUT utilisateur authentifié (Accueil, Admin, etc.) peut LIRE la config.
CREATE POLICY "Tout utilisateur authentifié peut LIRE la config"
  ON public.config_options FOR SELECT
  USING (auth.role() = 'authenticated');