-- ============================================================
-- FIX RLS POUR LA TABLE USERS
-- Exécutez ce script dans le SQL Editor de Supabase
-- ============================================================

-- 1. Désactiver temporairement RLS sur users
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 2. Réactiver RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 3. Supprimer toutes les anciennes politiques sur users
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;

-- 4. Créer les politiques CORRECTES avec auth_id
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = auth_id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = auth_id);

-- 5. AJOUTER la politique INSERT manquante (fallback si trigger échoue)
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = auth_id);

-- 6. Recréer le trigger pour la création automatique
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (auth_id, username, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substring(NEW.id::text, 1, 8)),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Recréer le trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
