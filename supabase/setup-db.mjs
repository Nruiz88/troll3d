import { readFileSync } from 'fs'
import pg from 'pg'

const DATABASE_URL = 'postgresql://postgres:PLyEZ6r9SxpglzBl@db.gumjccpxddwignjvtfey.supabase.co:5432/postgres'

async function main() {
  console.log('🔌 Conectando a Supabase PostgreSQL...')
  
  const client = new pg.Client({
    connectionString: DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  })

  await client.connect()
  console.log('✅ Conectado!\n')

  const sql = readFileSync(new URL('./schema.sql', import.meta.url), 'utf-8')
  
  console.log('📝 Ejecutando schema.sql...\n')
  
  try {
    await client.query(sql)
    console.log('✅ ¡Tablas creadas exitosamente!\n')
    
    // Verificar tablas creadas
    const { rows } = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `)
    
    console.log('📋 Tablas en la base de datos:')
    rows.forEach(r => console.log(`   - ${r.table_name}`))
    
  } catch (err) {
    console.error('❌ Error:', err.message)
  } finally {
    await client.end()
    console.log('\n🔌 Conexión cerrada.')
  }
}

main()
