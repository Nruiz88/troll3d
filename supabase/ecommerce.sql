-- ============================================
-- E-commerce Schema para Supabase
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- ============================================

-- ============================================
-- TABLA: product_categories (categorías de productos)
-- ============================================
CREATE TABLE IF NOT EXISTS product_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  image_url TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Product categories: public read" ON product_categories
  FOR SELECT USING (true);

-- ============================================
-- TABLA: products (productos)
-- ============================================
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  short_description TEXT,
  price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  compare_price DECIMAL(10,2) CHECK (compare_price >= 0),
  sku TEXT UNIQUE,
  stock INTEGER DEFAULT 0 CHECK (stock >= 0),
  images TEXT[] DEFAULT '{}',
  category_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'draft', 'archived')),
  featured BOOLEAN DEFAULT false,
  weight DECIMAL(10,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_slug ON products(slug);
CREATE INDEX IF NOT EXISTS idx_products_status ON products(status);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_featured ON products(featured);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Lectura pública de productos activos
CREATE POLICY "Products: public read active" ON products
  FOR SELECT USING (status = 'active');

-- Admin gestiona productos (usando service_role o authenticated con rol admin)
CREATE POLICY "Products: authenticated manage" ON products
  FOR ALL USING ((select auth.uid()) IS NOT NULL)
  WITH CHECK ((select auth.uid()) IS NOT NULL);

-- ============================================
-- TABLA: customers (clientes)
-- ============================================
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers: read own" ON customers
  FOR SELECT USING ((select auth.uid()) = id);

CREATE POLICY "Customers: update own" ON customers
  FOR UPDATE USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);

CREATE POLICY "Customers: insert own" ON customers
  FOR INSERT WITH CHECK ((select auth.uid()) = id);

-- ============================================
-- TABLA: customer_addresses (direcciones)
-- ============================================
CREATE TABLE IF NOT EXISTS customer_addresses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  label TEXT DEFAULT 'Principal',
  street_address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT,
  postal_code TEXT,
  country TEXT DEFAULT 'MX',
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE customer_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Addresses: read own" ON customer_addresses
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM customers WHERE customers.id = customer_addresses.customer_id AND (select auth.uid()) = customers.id)
  );

CREATE POLICY "Addresses: manage own" ON customer_addresses
  FOR ALL USING (
    EXISTS (SELECT 1 FROM customers WHERE customers.id = customer_addresses.customer_id AND (select auth.uid()) = customers.id)
  );

-- ============================================
-- TABLA: orders (pedidos)
-- ============================================
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  tax DECIMAL(10,2) NOT NULL DEFAULT 0,
  shipping DECIMAL(10,2) NOT NULL DEFAULT 0,
  total DECIMAL(10,2) NOT NULL DEFAULT 0,
  currency TEXT DEFAULT 'MXN',
  shipping_address_id UUID REFERENCES customer_addresses(id) ON DELETE SET NULL,
  billing_address_id UUID REFERENCES customer_addresses(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Clientes ven sus propios pedidos
CREATE POLICY "Orders: read own" ON orders
  FOR SELECT USING ((select auth.uid()) = customer_id);

-- Clientes crean sus propios pedidos
CREATE POLICY "Orders: insert own" ON orders
  FOR INSERT WITH CHECK ((select auth.uid()) = customer_id);

-- ============================================
-- TABLA: order_items (items del pedido)
-- ============================================
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Clientes ven items de sus propios pedidos
CREATE POLICY "Order items: read own" ON order_items
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM orders WHERE orders.id = order_items.order_id AND (select auth.uid()) = orders.customer_id)
  );

-- Clientes agregan items a sus propios pedidos
CREATE POLICY "Order items: insert own" ON order_items
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM orders WHERE orders.id = order_items.order_id AND (select auth.uid()) = orders.customer_id)
  );

-- ============================================
-- TABLA: cart_items (carrito de compras)
-- ============================================
CREATE TABLE IF NOT EXISTS cart_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(customer_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_cart_customer ON cart_items(customer_id);

ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;

-- Clientes ven su propio carrito
CREATE POLICY "Cart: read own" ON cart_items
  FOR SELECT USING ((select auth.uid()) = customer_id);

-- Clientes gestionan su propio carrito
CREATE POLICY "Cart: manage own" ON cart_items
  FOR ALL USING ((select auth.uid()) = customer_id)
  WITH CHECK ((select auth.uid()) = customer_id);

-- ============================================
-- TABLA: product_reviews (reseñas)
-- ============================================
CREATE TABLE IF NOT EXISTS product_reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title TEXT,
  comment TEXT,
  approved BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reviews_product ON product_reviews(product_id);

ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;

-- Reseñas aprobadas son públicas
CREATE POLICY "Reviews: public read approved" ON product_reviews
  FOR SELECT USING (approved = true);

-- Clientes crean sus propias reseñas
CREATE POLICY "Reviews: insert own" ON product_reviews
  FOR INSERT WITH CHECK ((select auth.uid()) = customer_id);

-- Clientes ven sus propias reseñas (incluso no aprobadas)
CREATE POLICY "Reviews: read own" ON product_reviews
  FOR SELECT USING ((select auth.uid()) = customer_id);

-- ============================================
-- FUNCIÓN: Crear customer al registrarse
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_customer()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.customers (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data ->> 'full_name'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: crear customer cuando un usuario se registra
CREATE TRIGGER on_auth_user_created_customer
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_customer();

-- ============================================
-- TRIGGERS: Auto-actualizar updated_at
-- ============================================
CREATE TRIGGER set_updated_at_products
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_customers
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_orders
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_cart_items
  BEFORE UPDATE ON cart_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- GRANTS: Exponer tablas a la Data API
-- ============================================
GRANT SELECT ON product_categories TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON products TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON customers TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON customer_addresses TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON orders TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_items TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON cart_items TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON product_reviews TO anon, authenticated;
