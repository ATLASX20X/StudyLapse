-- ============================================================
-- SUPABASE TRIGGER: AUTO-CREATE USER PROFILE ON SIGNUP
-- ============================================================
-- Exécutez ce script dans le SQL Editor de votre dashboard Supabase
-- après avoir exécuté supabase_setup.sql
-- ============================================================

-- Cette fonction crée automatiquement un profil dans la table users
-- quand un nouvel utilisateur s'inscrit via Supabase Auth
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

-- Trigger qui s'exécute après l'insertion dans auth.users
-- Si le trigger existe déjà, on le supprime d'abord
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Ajouter une politique INSERT pour permettre la création manuelle
-- (fallback si le trigger ne fonctionne pas)
DROP POLICY IF EXISTS "Users can insert own profile" ON users;

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = auth_id);

