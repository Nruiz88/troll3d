-- ============================================
-- TABLA: marketing_settings
-- Configuración de elementos de conversión
-- ============================================
CREATE TABLE IF NOT EXISTS marketing_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  key VARCHAR(100) NOT NULL UNIQUE,
  value JSONB NOT NULL DEFAULT '{}',
  category VARCHAR(50) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: Solo admin puede gestionar
ALTER TABLE marketing_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view marketing settings"
  ON marketing_settings FOR SELECT
  USING (true);

CREATE POLICY "Admins can manage marketing settings"
  ON marketing_settings FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Índice para búsquedas por clave
CREATE INDEX idx_marketing_settings_key ON marketing_settings(key);
CREATE INDEX idx_marketing_settings_category ON marketing_settings(category);

-- ============================================
-- INSERTAR CONFIGURACIONES POR DEFECTO
-- ============================================

-- Countdown Timer
INSERT INTO marketing_settings (key, value, category, description) VALUES
('countdown_enabled', 'true', 'countdown', 'Habilitar countdown de ofertas'),
('countdown_end_date', '"2026-09-30T23:59:59"', 'countdown', 'Fecha de fin del countdown'),
('countdown_label', '"¡Oferta especial termina en!"', 'countdown', 'Texto del countdown')
ON CONFLICT (key) DO NOTHING;

-- Exit Intent Popup
INSERT INTO marketing_settings (key, value, category, description) VALUES
('popup_enabled', 'true', 'popup', 'Habilitar popup de exit intent'),
('popup_coupon_code', '"TROLL10"', 'popup', 'Código de descuento del popup'),
('popup_discount_value', '"10"', 'popup', 'Valor del descuento (porcentaje)'),
('popup_title', '"¡Espera, guerrero!"', 'popup', 'Título del popup'),
('popup_message', '"El troll tiene un regalo para ti: 10% de descuento en tu primera compra"', 'popup', 'Mensaje del popup')
ON CONFLICT (key) DO NOTHING;

-- Social Proof
INSERT INTO marketing_settings (key, value, category, description) VALUES
('social_proof_enabled', 'true', 'social-proof', 'Habilitar prueba social'),
('social_proof_show_visitors', 'true', 'social-proof', 'Mostrar visitantes en vivo'),
('social_proof_show_purchases', 'true', 'social-proof', 'Mostrar compras recientes'),
('social_proof_trust_text', '"4.9/5 en reseñas"', 'social-proof', 'Texto de confianza')
ON CONFLICT (key) DO NOTHING;

-- Sticky CTA
INSERT INTO marketing_settings (key, value, category, description) VALUES
('sticky_cta_enabled', 'true', 'sticky-cta', 'Habilitar CTA fijo en mobile'),
('sticky_cta_text', '"⚔️ Explorar la cueva"', 'sticky-cta', 'Texto del botón CTA'),
('sticky_cta_link', '"/shop"', 'sticky-cta', 'Enlace del botón CTA'),
('sticky_cta_threshold', '"300"', 'sticky-cta', 'Pixels de scroll para mostrar')
ON CONFLICT (key) DO NOTHING;

-- Redes Sociales
INSERT INTO marketing_settings (key, value, category, description) VALUES
('social_facebook', '"https://facebook.com/"', 'social-links', 'URL de Facebook'),
('social_instagram', '"https://instagram.com/"', 'social-links', 'URL de Instagram'),
('social_tiktok', '"https://tiktok.com/"', 'social-links', 'URL de TikTok'),
('social_whatsapp', '"https://wa.me/"', 'social-links', 'URL/número de WhatsApp (wa.me)')
ON CONFLICT (key) DO NOTHING;

-- ============================================
-- FUNCIÓN: Obtener configuración de marketing
-- ============================================
CREATE OR REPLACE FUNCTION get_marketing_settings(setting_category VARCHAR)
RETURNS TABLE (
  key VARCHAR,
  value JSONB
)
LANGUAGE sql
AS $$
  SELECT ms.key, ms.value
  FROM marketing_settings ms
  WHERE ms.category = setting_category;
$$;

-- ============================================
-- FUNCIÓN: Actualizar configuración de marketing
-- ============================================
CREATE OR REPLACE FUNCTION update_marketing_setting(
  setting_key VARCHAR,
  setting_value JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE marketing_settings
  SET value = setting_value,
      updated_at = NOW()
  WHERE key = setting_key;
  
  RETURN FOUND;
END;
$$;
