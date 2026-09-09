import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables. Check .env file.')
}

/**
 * Cliente de Supabase para uso en componentes Astro (server-side).
 * Se puede usar en frontmatter de .astro, API routes, y middleware.
 *
 * @example
 * ---
 * import { supabase } from '@/lib/supabase'
 * const { data: posts } = await supabase.from('posts').select('*')
 * ---
 */
export const supabase = createClient(supabaseUrl, supabaseAnonKey)

/**
 * Crea un cliente Supabase con un access token específico.
 * Útil para requests autenticados del servidor.
 *
 * @param accessToken - JWT del usuario
 * @returns Cliente Supabase autenticado
 */
export function createSupabaseWithAuth(accessToken: string) {
  return createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  })
}
