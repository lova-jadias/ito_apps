import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token)

    if (userError || !user) {
      throw new Error('Non authentifié')
    }

    const { user_id } = await req.json()

    // 1. Valider
    const { data: validatedData, error: validateError } = await supabaseAdmin
      .rpc('prepare_user_deletion', {
        user_id,
        requesting_user_id: user.id // CORRECTION
      })

    if (validateError) {
      console.error('Validation error:', validateError)
      throw new Error(validateError.message)
    }

    // 2. Supprimer (le CASCADE supprimera le profil)
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user_id)

    if (deleteError) {
      console.error('Delete error:', deleteError)
      throw new Error(`Erreur suppression: ${deleteError.message}`)
    }

    return new Response(
      JSON.stringify({
        message: 'Utilisateur supprimé',
        email: validatedData.email
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})