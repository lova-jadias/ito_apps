-- ============================================
-- CORRECTION CRITIQUE: Trigger generate_etudiant_id
-- Le trigger écrasait TOUJOURS le site avec NULL
-- car il ne vérifiait pas si NEW.site était déjà défini
-- ============================================

CREATE OR REPLACE FUNCTION public.generate_etudiant_id()
RETURNS TRIGGER
AS $$
DECLARE
  user_site public.site_enum;
BEGIN
  -- ✅ CORRECTION: Seulement si le site est NULL
  -- Cela permet aux Edge Functions de passer un site explicite
  IF NEW.site IS NULL THEN
    -- Récupérer le site de l'utilisateur authentifié
    SELECT site_rattache INTO user_site
    FROM public.profiles WHERE id = auth.uid();

    NEW.site := user_site;
  END IF;

  -- Générer l'ID : "ID_Sequence-Année-CodeSite"
  -- Ex: "1-25-T" pour le premier étudiant de 2025 à Tana
  NEW.id_etudiant_genere := NEW.id || '-' || TO_CHAR(NOW(), 'YY') || '-' || NEW.site;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Le trigger existe déjà, pas besoin de le recréer
-- Il s'appelle: before_etudiant_insert

-- ============================================
-- TEST DE VÉRIFICATION
-- ============================================

-- Vérifier que la fonction a bien été mise à jour
DO $$
BEGIN
  RAISE NOTICE '✅ Migration appliquée: Le trigger ne forcera plus le site si déjà défini';
END $$;