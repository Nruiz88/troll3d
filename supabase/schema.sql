-- ============================================
-- Supabase Schema para Proyecto Astro
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- ============================================

-- Habilitar extensiones útiles
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLA: profiles (perfiles de usuario)
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: Los usuarios pueden ver todos los perfiles pero solo editar el suyo
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles: public read" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Profiles: update own" ON profiles
  FOR UPDATE USING ((select auth.uid()) = id);

CREATE POLICY "Profiles: insert own" ON profiles
  FOR INSERT WITH CHECK ((select auth.uid()) = id);

-- ============================================
-- TABLA: categories (categorías de posts)
-- ============================================
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Categories: public read" ON categories
  FOR SELECT USING (true);

-- ============================================
-- TABLA: posts (artículos del blog)
-- ============================================
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  content TEXT,
  excerpt TEXT,
  cover_image TEXT,
  author_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para búsquedas frecuentes
CREATE INDEX IF NOT EXISTS idx_posts_slug ON posts(slug);
CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status);
CREATE INDEX IF NOT EXISTS idx_posts_published_at ON posts(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_author ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category_id);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Lectura pública de posts publicados
CREATE POLICY "Posts: public read published" ON posts
  FOR SELECT USING (status = 'published');

-- Autores gestionan sus propios posts
CREATE POLICY "Posts: author insert" ON posts
  FOR INSERT WITH CHECK ((select auth.uid()) = author_id);

CREATE POLICY "Posts: author update own" ON posts
  FOR UPDATE USING ((select auth.uid()) = author_id)
  WITH CHECK ((select auth.uid()) = author_id);

CREATE POLICY "Posts: author delete own" ON posts
  FOR DELETE USING ((select auth.uid()) = author_id);

-- ============================================
-- TABLA: tags (etiquetas)
-- ============================================
CREATE TABLE IF NOT EXISTS tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Tags: public read" ON tags
  FOR SELECT USING (true);

-- ============================================
-- TABLA: post_tags (relación posts <-> tags)
-- ============================================
CREATE TABLE IF NOT EXISTS post_tags (
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, tag_id)
);

ALTER TABLE post_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Post tags: public read" ON post_tags
  FOR SELECT USING (true);

CREATE POLICY "Post tags: author manage" ON post_tags
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM posts
      WHERE posts.id = post_tags.post_id
        AND posts.author_id = (select auth.uid())
    )
  );

-- ============================================
-- TABLA: comments (comentarios)
-- ============================================
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content TEXT NOT NULL,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  author_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id);

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Lectura pública de comentarios
CREATE POLICY "Comments: public read" ON comments
  FOR SELECT USING (true);

-- Usuarios autenticados pueden comentar
CREATE POLICY "Comments: auth insert" ON comments
  FOR INSERT WITH CHECK ((select auth.uid()) = author_id);

-- Autores editan sus comentarios
CREATE POLICY "Comments: author update own" ON comments
  FOR UPDATE USING ((select auth.uid()) = author_id)
  WITH CHECK ((select auth.uid()) = author_id);

-- Autores eliminan sus comentarios
CREATE POLICY "Comments: author delete own" ON comments
  FOR DELETE USING ((select auth.uid()) = author_id);

-- ============================================
-- FUNCIÓN: Auto-actualizar updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para auto-actualizar updated_at
CREATE TRIGGER set_updated_at_profiles
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_posts
  BEFORE UPDATE ON posts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_comments
  BEFORE UPDATE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- FUNCIÓN: Crear perfil al registrarse
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'username',
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.raw_user_meta_data ->> 'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: crear perfil cuando un usuario se registra
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================
-- GRANTS: Exponer tablas a la Data API
-- ============================================
GRANT SELECT, INSERT, UPDATE, DELETE ON profiles TO anon, authenticated;
GRANT SELECT ON categories TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON posts TO anon, authenticated;
GRANT SELECT ON tags TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON post_tags TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON comments TO anon, authenticated;
