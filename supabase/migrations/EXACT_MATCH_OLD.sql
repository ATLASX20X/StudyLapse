-- ============================================================
-- RÉPLICATION EXACTE DE L'ANCIEN COMPTE (basé sur l'export)
-- Exécutez CE SCRIPT UNIQUEMENT dans le SQL Editor du NOUVEAU compte
-- ============================================================

-- Nettoyage complet
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS public.mark_expired_requests() CASCADE;
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
DROP TRIGGER IF EXISTS update_posts_updated_at ON posts;
DROP TRIGGER IF EXISTS update_comments_updated_at ON comments;

DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS likes CASCADE;
DROP TABLE IF EXISTS friends CASCADE;
DROP TABLE IF EXISTS friend_requests CASCADE;
DROP TABLE IF EXISTS followers CASCADE;
DROP TABLE IF EXISTS posts CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tables exactes
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  username character varying(50) UNIQUE NOT NULL,
  email character varying(255) UNIQUE NOT NULL,
  avatar_url text,
  bio text,
  followers_count integer,
  following_count integer,
  posts_count integer,
  storage_used_bytes bigint,
  storage_limit_bytes bigint,
  created_at timestamp with time zone DEFAULT NOW(),
  updated_at timestamp with time zone DEFAULT NOW(),
  name text,
  friends_count integer
);

CREATE TABLE posts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  author_username character varying(50) NOT NULL,
  video_url text NOT NULL,
  thumbnail_url text,
  description text,
  subject character varying(100),
  duration_seconds integer NOT NULL,
  visibility character varying(20),
  likes_count integer,
  comments_count integer,
  created_at timestamp with time zone DEFAULT NOW(),
  updated_at timestamp with time zone DEFAULT NOW()
);

CREATE TABLE followers (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  follower_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT NOW()
);

CREATE TABLE friend_requests (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  from_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  from_username text NOT NULL,
  to_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_username text NOT NULL,
  created_at timestamp with time zone DEFAULT NOW(),
  expires_at timestamp with time zone NOT NULL,
  status text NOT NULL DEFAULT 'pending'
);

CREATE TABLE friends (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT NOW()
);

CREATE TABLE likes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT NOW()
);

CREATE TABLE comments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  author_username character varying(50) NOT NULL,
  text text NOT NULL,
  created_at timestamp with time zone DEFAULT NOW(),
  updated_at timestamp with time zone DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_posts_author_id ON posts(author_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_posts_visibility ON posts(visibility);
CREATE INDEX idx_posts_subject ON posts(subject);
CREATE INDEX idx_followers_user_id ON followers(user_id);
CREATE INDEX idx_followers_follower_id ON followers(follower_id);
CREATE INDEX idx_likes_post_id ON likes(post_id);
CREATE INDEX idx_likes_user_id ON likes(user_id);
CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_comments_author_id ON comments(author_id);
CREATE INDEX idx_friend_requests_to_user ON friend_requests(to_user_id, status);
CREATE INDEX idx_friend_requests_from_user ON friend_requests(from_user_id, status);
CREATE INDEX idx_friends_user ON friends(user_id);
CREATE INDEX idx_friends_friend ON friends(friend_id);

-- Fonctions exactes
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (auth_id, username, name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substring(NEW.id::text, 1, 8)),
    COALESCE(NEW.raw_user_meta_data->>'name', 'Étudiant'),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION mark_expired_requests()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE friend_requests
  SET status = 'expired'
  WHERE status = 'pending' AND expires_at < NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers exacts
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON posts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_comments_updated_at BEFORE UPDATE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- RLS activé
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE followers ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Politiques exactes (dans l'ordre de l'export)

-- friend_requests
CREATE POLICY "Friend requests can delete own" ON friend_requests
  FOR DELETE TO public USING ((to_user_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))) OR (from_user_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))));

CREATE POLICY "Users can see friend requests sent to them" ON friend_requests
  FOR SELECT TO public USING (to_user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Users can see friend requests they sent" ON friend_requests
  FOR SELECT TO public USING (from_user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Users can send friend requests" ON friend_requests
  FOR INSERT TO public WITH CHECK (from_user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Users can respond to friend requests" ON friend_requests
  FOR UPDATE TO public USING (to_user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Friend requests can view own" ON friend_requests
  FOR SELECT TO public USING ((from_user_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))) OR (to_user_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))));

CREATE POLICY "Friend requests can insert own" ON friend_requests
  FOR INSERT TO public WITH CHECK (from_user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Friend requests can update own" ON friend_requests
  FOR UPDATE TO public USING (from_user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

-- posts
CREATE POLICY "Anyone can view public posts" ON posts
  FOR SELECT TO public USING (((visibility)::text = 'public'::text));

CREATE POLICY "Users can view friends posts" ON posts
  FOR SELECT TO public USING (((visibility)::text = 'friends'::text) AND (author_id IN ( SELECT followers.user_id FROM followers WHERE (followers.follower_id = auth.uid()))));

CREATE POLICY "Users can view own posts" ON posts
  FOR SELECT TO public USING (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Users can insert own posts" ON posts
  FOR INSERT TO public WITH CHECK (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Users can update own posts" ON posts
  FOR UPDATE TO public USING (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Users can delete own posts" ON posts
  FOR DELETE TO public USING (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Posts can view public" ON posts
  FOR SELECT TO public USING (((visibility)::text = 'public'::text) OR (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))));

CREATE POLICY "Posts can insert own" ON posts
  FOR INSERT TO public WITH CHECK (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Posts can update own" ON posts
  FOR UPDATE TO public USING (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Posts can delete own" ON posts
  FOR DELETE TO public USING (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

-- followers
CREATE POLICY "Users can view followers" ON followers
  FOR SELECT TO public USING ((user_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))) OR (follower_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))));

CREATE POLICY "Users can insert followers" ON followers
  FOR INSERT TO public WITH CHECK (follower_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Users can delete own follows" ON followers
  FOR DELETE TO public USING (follower_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

-- friends
CREATE POLICY "Users can see their friends" ON friends
  FOR SELECT TO public USING (user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Users can create friendships" ON friends
  FOR INSERT TO public WITH CHECK (user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Users can remove friends" ON friends
  FOR DELETE TO public USING (user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Friends can view own" ON friends
  FOR SELECT TO public USING ((user_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))) OR (friend_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))));

CREATE POLICY "Friends can delete own" ON friends
  FOR DELETE TO public USING ((user_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))) OR (friend_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))));

CREATE POLICY "Friends can insert own" ON friends
  FOR INSERT TO public WITH CHECK ((user_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))) OR (friend_id IN ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid()))));

-- users
CREATE POLICY "Users can view all profiles" ON users
  FOR SELECT TO public USING (true);

CREATE POLICY "Users can view own profile" ON users
  FOR SELECT TO public USING (auth.uid() = auth_id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE TO public USING (auth.uid() = auth_id);

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT TO public WITH CHECK (auth.uid() = auth_id);

-- likes
CREATE POLICY "Likes can view all" ON likes
  FOR SELECT TO public USING (true);

CREATE POLICY "Likes can insert own" ON likes
  FOR INSERT TO public WITH CHECK (user_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Likes can delete own" ON likes
  FOR DELETE TO public USING (user_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

-- comments
CREATE POLICY "Comments can view all" ON comments
  FOR SELECT TO public USING (true);

CREATE POLICY "Comments can insert own" ON comments
  FOR INSERT TO public WITH CHECK (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Comments can update own" ON comments
  FOR UPDATE TO public USING (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));

CREATE POLICY "Comments can delete own" ON comments
  FOR DELETE TO public USING (author_id = ( SELECT users.id FROM users WHERE (users.auth_id = auth.uid())));
