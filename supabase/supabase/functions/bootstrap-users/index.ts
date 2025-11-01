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

    const results = []

    // 1. CRÉER ADMIN
    console.log('🔵 Création Admin...')
    const { data: adminUser, error: adminError } = await supabaseAdmin.auth.admin.createUser({
      email: 'admin@ito.mg',
      password: 'AdminITO2025!',
      email_confirm: true,
      user_metadata: {
        role: 'admin',
        site: 'FULL'
      }
    })

    if (adminError) {
      console.error('❌ Erreur Admin:', adminError)
      throw new Error(`Admin: ${adminError.message}`)
    }

    // Mettre à jour le profil
    await supabaseAdmin
      .from('profiles')
      .update({
        nom_complet: 'Administrateur Principal',
        role: 'admin',
        site_rattache: 'FULL'
      })
      .eq('id', adminUser.user.id)

    console.log('✅ Admin créé:', adminUser.user.email)
    results.push({
      role: 'admin',
      email: 'admin@ito.mg',
      password: 'AdminITO2025!',
      status: 'success'
    })

    // 2. CRÉER ACCUEIL
    console.log('🔵 Création Accueil...')
    const { data: accueilUser, error: accueilError } = await supabaseAdmin.auth.admin.createUser({
      email: 'accueil.tana@ito.mg',
      password: 'Accueil123!',
      email_confirm: true,
      user_metadata: {
        role: 'accueil',
        site: 'T'
      }
    })

    if (accueilError) {
      console.error('❌ Erreur Accueil:', accueilError)
      throw new Error(`Accueil: ${accueilError.message}`)
    }

    // Mettre à jour le profil
    await supabaseAdmin
      .from('profiles')
      .update({
        nom_complet: 'Secrétaire Accueil Antananarivo',
        role: 'accueil',
        site_rattache: 'T'
      })
      .eq('id', accueilUser.user.id)

    console.log('✅ Accueil créé:', accueilUser.user.email)
    results.push({
      role: 'accueil',
      email: 'accueil.tana@ito.mg',
      password: 'Accueil123!',
      status: 'success'
    })

    return new Response(
      JSON.stringify({
        message: '✅ Bootstrap complet',
        users: results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('💥 ERREUR:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})