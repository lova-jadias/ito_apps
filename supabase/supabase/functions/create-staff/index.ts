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

    const { email, password, nom_complet, role, site } = await req.json()

    // 1. Valider
    const { data: validatedData, error: validateError } = await supabaseAdmin
      .rpc('prepare_staff_data', {
        email,
        nom_complet,
        role,
        site,
        requesting_user_id: user.id // CORRECTION
      })

    if (validateError) {
      console.error('Validation error:', validateError)
      throw new Error(validateError.message)
    }

    // 2. Créer
    const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { role, site }
    })

    if (authError) {
      console.error('Auth error:', authError)
      throw new Error(`Erreur création compte: ${authError.message}`)
    }

    // 3. Finaliser
    const { data: finalData, error: finalError } = await supabaseAdmin
      .rpc('finalize_staff_creation', {
        auth_user_id: authUser.user.id,
        nom_complet,
        role_name: role,
        site_name: site
      })

    if (finalError) {
      console.error('Finalize error:', finalError)
      await supabaseAdmin.auth.admin.deleteUser(authUser.user.id)
      throw new Error(finalError.message)
    }

    return new Response(
      JSON.stringify(finalData),
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