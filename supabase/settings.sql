/**
 * Settings table for system configuration
 * Stores key-value pairs for app settings like MercadoPago credentials
 */

-- Tabla de configuración
CREATE TABLE IF NOT EXISTS settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value JSONB,
  category TEXT DEFAULT 'general',
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para búsquedas por key
CREATE INDEX IF NOT EXISTS idx_settings_key ON settings(key);
CREATE INDEX IF NOT EXISTS idx_settings_category ON settings(category);

-- RLS policies
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Solo admin puede leer configuraciones
CREATE POLICY "Admin can read settings" ON settings
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Solo admin puede actualizar configuraciones
CREATE POLICY "Admin can update settings" ON settings
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Solo admin puede insertar configuraciones
CREATE POLICY "Admin can insert settings" ON settings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Función para obtener setting por key (para uso en server-side)
CREATE OR REPLACE FUNCTION get_setting(setting_key TEXT)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT value INTO result FROM settings WHERE key = setting_key;
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para guardar/actualizar setting
CREATE OR REPLACE FUNCTION upsert_setting(
  setting_key TEXT,
  setting_value JSONB,
  setting_category TEXT DEFAULT 'general',
  setting_description TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO settings (key, value, category, description)
  VALUES (setting_key, setting_value, setting_category, setting_description)
  ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value,
      category = EXCLUDED.category,
      description = EXCLUDED.description,
      updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Configuraciones iniciales de MercadoPago
INSERT INTO settings (key, value, category, description) VALUES
  ('mercadopago_access_token', '""'::jsonb, 'payments', 'Access Token de MercadoPago'),
  ('mercadopago_public_key', '""'::jsonb, 'payments', 'Public Key de MercadoPago'),
  ('mercadopago_webhook_url', '""'::jsonb, 'payments', 'URL del webhook de MercadoPago'),
  ('mercadopago_test_mode', 'true'::jsonb, 'payments', 'Modo de prueba activado'),
  ('store_name', '"La cueva del Troll"'::jsonb, 'general', 'Nombre de la tienda'),
  ('store_email', '""'::jsonb, 'general', 'Email de la tienda'),
  ('store_phone', '""'::jsonb, 'general', 'Teléfono de la tienda'),
  ('shipping_free_min', '500'::jsonb, 'shipping', 'Monto mínimo para envío gratis'),
  ('shipping_cost', '99'::jsonb, 'shipping', 'Costo de envío default')
ON CONFLICT (key) DO NOTHING;

-- Grants
GRANT ALL ON settings TO authenticated;
GRANT EXECUTE ON FUNCTION get_setting TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_setting TO authenticated;
