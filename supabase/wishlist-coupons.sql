-- ============================================
-- TABLA: wishlist (Favoritos)
-- Los clientes guardan productos deseados
-- ============================================
CREATE TABLE IF NOT EXISTS wishlist (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(customer_id, product_id)
);

-- RLS: Solo el propio cliente puede ver/modificar sus favoritos
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers view own wishlist"
  ON wishlist FOR SELECT
  USING (auth.uid() = customer_id);

CREATE POLICY "Customers add to wishlist"
  ON wishlist FOR INSERT
  WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Customers remove from wishlist"
  ON wishlist FOR DELETE
  USING (auth.uid() = customer_id);

-- Índices para búsquedas rápidas
CREATE INDEX idx_wishlist_customer ON wishlist(customer_id);
CREATE INDEX idx_wishlist_product ON wishlist(product_id);

-- ============================================
-- TABLA: coupons (Cupones de descuento)
-- Administrador crea cupones, clientes aplican en checkout
-- ============================================
CREATE TABLE IF NOT EXISTS coupons (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
  discount_value DECIMAL(10, 2) NOT NULL,
  min_purchase DECIMAL(10, 2) DEFAULT 0,
  max_uses INTEGER DEFAULT NULL,
  used_count INTEGER DEFAULT 0,
  valid_from TIMESTAMPTZ DEFAULT NOW(),
  valid_until TIMESTAMPTZ,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: Solo admin puede gestionar cupones
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active coupons"
  ON coupons FOR SELECT
  USING (active = true);

CREATE POLICY "Admins can manage coupons"
  ON coupons FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Índice para buscar por código
CREATE INDEX idx_coupons_code ON coupons(code);

-- ============================================
-- FUNCIÓN: Validar cupón
-- ============================================
CREATE OR REPLACE FUNCTION validate_coupon(coupon_code VARCHAR, cart_total DECIMAL)
RETURNS TABLE (
  valid BOOLEAN,
  discount_amount DECIMAL,
  message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  coupon_record RECORD;
  calculated_discount DECIMAL;
BEGIN
  -- Buscar cupón
  SELECT * INTO coupon_record
  FROM coupons
  WHERE UPPER(code) = UPPER(coupon_code)
    AND active = true;

  -- No encontrado
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0::DECIMAL, 'Cupón no encontrado'::TEXT;
    RETURN;
  END IF;

  -- Expirado
  IF coupon_record.valid_until IS NOT NULL AND coupon_record.valid_until < NOW() THEN
    RETURN QUERY SELECT false, 0::DECIMAL, 'Cupón expirado'::TEXT;
    RETURN;
  END IF;

  -- Compra mínima no alcanzada
  IF coupon_record.min_purchase > 0 AND cart_total < coupon_record.min_purchase THEN
    RETURN QUERY SELECT false, 0::DECIMAL,
      format('Compra mínima: $%s', coupon_record.min_purchase)::TEXT;
    RETURN;
  END IF;

  -- Límite de usos alcanzado
  IF coupon_record.max_uses IS NOT NULL AND coupon_record.used_count >= coupon_record.max_uses THEN
    RETURN QUERY SELECT false, 0::DECIMAL, 'Cupón agotado'::TEXT;
    RETURN;
  END IF;

  -- Calcular descuento
  IF coupon_record.discount_type = 'percentage' THEN
    calculated_discount := cart_total * (coupon_record.discount_value / 100);
  ELSE
    calculated_discount := LEAST(coupon_record.discount_value, cart_total);
  END IF;

  RETURN QUERY SELECT true, calculated_discount, 'Cupón aplicado'::TEXT;
END;
$$;

-- ============================================
-- FUNCIÓN: Aplicar cupón (incrementar contador)
-- ============================================
CREATE OR REPLACE FUNCTION apply_coupon(coupon_code VARCHAR)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE coupons
  SET used_count = used_count + 1,
      updated_at = NOW()
  WHERE UPPER(code) = UPPER(coupon_code)
    AND active = true;

  RETURN FOUND;
END;
$$;

-- ============================================
-- INSERTAR CUPONES DE EJEMPLO
-- ============================================
INSERT INTO coupons (code, description, discount_type, discount_value, min_purchase, max_uses, valid_until)
VALUES
  ('BIENVENIDO10', '10% de descuento para nuevos clientes', 'percentage', 10, 200, 100, NOW() + INTERVAL '3 months'),
  ('TROLL20', '20% de descuento en tu primera compra', 'percentage', 20, 500, 50, NOW() + INTERVAL '1 month'),
  ('AHORRO50', '$50 de descuento en compras mayores a $300', 'fixed', 50, 300, 200, NOW() + INTERVAL '2 months'),
  ('VERANO25', '25% off en toda la tienda', 'percentage', 25, 0, 500, NOW() + INTERVAL '1 month')
ON CONFLICT (code) DO NOTHING;
