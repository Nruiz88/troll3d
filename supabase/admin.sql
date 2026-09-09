-- ============================================
-- Admin Role Support para Supabase
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- ============================================

-- ============================================
-- AGREGAR CAMPO role A profiles
-- ============================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin', 'superadmin'));

-- ============================================
-- POLICÍAS ADMIN: Acceso total a todas las tablas
-- ============================================

-- Función helper para verificar si es admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = (select auth.uid())
      AND role IN ('admin', 'superadmin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Products: admin puede hacer todo
DROP POLICY IF EXISTS "Products: authenticated manage" ON products;
CREATE POLICY "Products: admin manage" ON products
  FOR ALL USING (is_admin())
  WITH CHECK (is_admin());

-- Product categories: admin puede hacer todo
CREATE POLICY "Product categories: admin manage" ON product_categories
  FOR ALL USING (is_admin())
  WITH CHECK (is_admin());

-- Orders: admin puede ver todos
CREATE POLICY "Orders: admin read all" ON orders
  FOR SELECT USING (is_admin());

CREATE POLICY "Orders: admin update" ON orders
  FOR UPDATE USING (is_admin())
  WITH CHECK (is_admin());

-- Order items: admin puede ver todos
CREATE POLICY "Order items: admin read all" ON order_items
  FOR SELECT USING (is_admin());

-- Customers: admin puede ver todos
CREATE POLICY "Customers: admin read all" ON customers
  FOR SELECT USING (is_admin());

-- Customer addresses: admin puede ver todos
CREATE POLICY "Addresses: admin read all" ON customer_addresses
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM customers
      WHERE customers.id = customer_addresses.customer_id
        AND is_admin()
    )
  );

-- Reviews: admin puede aprobar/rechazar
CREATE POLICY "Reviews: admin manage" ON product_reviews
  FOR ALL USING (is_admin())
  WITH CHECK (is_admin());

-- ============================================
-- HACER is_admin() accesible para anon/authenticated
-- ============================================
GRANT EXECUTE ON FUNCTION is_admin() TO anon, authenticated;

-- ============================================
-- PROMOTEAR USUARIO A ADMIN
-- Cambiar 'user@email.com' por el email del admin
-- ============================================
-- UPDATE profiles SET role = 'admin' WHERE id = (
--   SELECT id FROM auth.users WHERE email = 'user@email.com'
-- );
