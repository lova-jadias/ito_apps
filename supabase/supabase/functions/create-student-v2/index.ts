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
    console.log('🔵 [1/6] Initialisation Supabase Admin')
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    console.log('🔵 [2/6] Récupération utilisateur authentifié')
    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token)

    if (userError || !user) {
      console.error('❌ Erreur auth:', userError)
      throw new Error('Non authentifié')
    }
    console.log('✅ User ID:', user.id)

    console.log('🔵 [3/6] Parsing body')
    const body = await req.json()
    const { student_data, temp_password, activate_gojika } = body
    console.log('📦 Student Data:', {
      nom: student_data.nom,
      prenom: student_data.prenom,
      email: student_data.email_contact
    })

    console.log('🔵 [4/6] Validation RPC prepare_student_data')
    const { data: validatedData, error: validateError } = await supabaseAdmin
      .rpc('prepare_student_data', {
        student_data,
        activate_gojika,
        requesting_user_id: user.id
      })

    if (validateError) {
      console.error('❌ Erreur validation:', validateError)
      throw new Error(`Validation: ${validateError.message}`)
    }
    console.log('✅ Données validées:', validatedData)

    const nom_complet = `${student_data.prenom || ''} ${student_data.nom || 'Étudiant'}`.trim()
    console.log('✅ Nom complet construit:', nom_complet)

    console.log('🔵 [5/6] Création utilisateur auth avec nom_complet')
    const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: student_data.email_contact,
      password: temp_password,
      email_confirm: true,
      user_metadata: {
        role: 'etudiant',
        site: validatedData.site,
        nom_complet: nom_complet
      }
    })

    if (authError) {
      console.error('❌ Erreur auth.admin.createUser:', authError)
      throw new Error(`Création compte: ${authError.message}`)
    }
    console.log('✅ Auth user créé:', authUser.user.id)

    console.log('🔵 [6/6] Finalisation étudiant')
    const { data: finalData, error: finalError } = await supabaseAdmin
      .rpc('finalize_student_creation', {
        auth_user_id: authUser.user.id,
        student_data,
        site_code: validatedData.site,
        activate_gojika
      })

    if (finalError) {
      console.error('❌ Erreur finalisation:', finalError)
      console.log('🔄 Rollback: suppression user auth')
      await supabaseAdmin.auth.admin.deleteUser(authUser.user.id)
      throw new Error(`Finalisation: ${finalError.message}`)
    }
    console.log('✅ Étudiant créé:', finalData)

    return new Response(
      JSON.stringify({
        ...finalData,
        temp_password,
        message: '✅ Compte GOJIKA créé avec succès'
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('💥 ERREUR GLOBALE:', error)
    return new Response(
      JSON.stringify({
        error: error.message,
        details: 'Voir les logs Supabase pour plus de détails'
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})