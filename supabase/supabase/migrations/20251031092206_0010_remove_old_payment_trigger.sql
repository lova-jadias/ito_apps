-- Fichier: supabase/migrations/XXXXXXXX_0010_remove_old_payment_trigger.sql

-- 1. Supprimer le trigger 'on_first_payment_item'
-- Il est obsolète car la RPC 'create_student_account' gère la création.
DROP TRIGGER IF EXISTS on_first_payment_item ON public.paiement_items;

-- 2. Supprimer la fonction 'notify_gojika_account_creation' qu'il appelait
-- Elle n'est plus utilisée par la nouvelle logique RPC.
DROP FUNCTION IF EXISTS public.notify_gojika_account_creation();