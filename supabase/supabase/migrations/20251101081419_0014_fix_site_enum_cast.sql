-- ================================================================
-- CORRECTION FINALE: Conversion explicite TEXT → ENUM
-- ================================================================

-- Remplacer finalize_student_creation
DROP FUNCTION IF EXISTS public.finalize_student_creation(uuid, jsonb, text, BOOLEAN);

CREATE OR REPLACE FUNCTION public.finalize_student_creation(
    auth_user_id uuid,
    student_data jsonb,
    site_code text,
    activate_gojika BOOLEAN
)
RETURNS jsonb
AS $$
DECLARE
    new_student_id bigint;
    generated_student_id TEXT;
    site_enum public.site_enum;
BEGIN
    -- ✅ CONVERSION EXPLICITE TEXT → ENUM
    site_enum := site_code::public.site_enum;

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
        site_enum, -- ✅ UTILISER LA VARIABLE CONVERTIE
        auth_user_id,
        activate_gojika,
        true
    ) RETURNING id, id_etudiant_genere INTO new_student_id, generated_student_id;

    RETURN jsonb_build_object(
        'id', new_student_id,
        'id_etudiant_genere', generated_student_id,
        'email', student_data->>'email_contact'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.finalize_student_creation(uuid, jsonb, text, BOOLEAN) TO authenticated;