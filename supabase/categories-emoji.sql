-- ============================================
-- Emoji e imagen para categorías (run en Supabase SQL Editor)
-- ============================================

-- Columna emoji: se muestra en la home cuando la categoría no tiene imagen
ALTER TABLE product_categories ADD COLUMN IF NOT EXISTS emoji TEXT;

-- image_url ya existe en ecommerce.sql; índice para ordenar
CREATE INDEX IF NOT EXISTS idx_product_categories_sort ON product_categories (sort_order);
