-- ============================================
-- SYSTEME D'AMIS (remplace le système followers)
-- ============================================

-- 1. Ajouter le champ friends_count à la table users
ALTER TABLE users ADD COLUMN IF NOT EXISTS friends_count INTEGER DEFAULT 0;

-- 2. Créer la table friend_requests
CREATE TABLE IF NOT EXISTS friend_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  from_username TEXT NOT NULL,
  to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_username TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
  UNIQUE(from_user_id, to_user_id, status)
);

-- 3. Créer la table friends
CREATE TABLE IF NOT EXISTS friends (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

-- 4. Indexes pour la performance
CREATE INDEX IF NOT EXISTS idx_friend_requests_to_user ON friend_requests(to_user_id, status);
CREATE INDEX IF NOT EXISTS idx_friend_requests_from_user ON friend_requests(from_user_id, status);
CREATE INDEX IF NOT EXISTS idx_friends_user ON friends(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_friend ON friends(friend_id);

-- 5. RLS Policies pour friend_requests
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;

-- Les utilisateurs peuvent voir les demandes qui leur sont envoyées
CREATE POLICY "Users can see friend requests sent to them"
  ON friend_requests FOR SELECT
  USING (to_user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Les utilisateurs peuvent voir les demandes qu'ils ont envoyées
CREATE POLICY "Users can see friend requests they sent"
  ON friend_requests FOR SELECT
  USING (from_user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Les utilisateurs peuvent envoyer des demandes d'amis
CREATE POLICY "Users can send friend requests"
  ON friend_requests FOR INSERT
  WITH CHECK (from_user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Les utilisateurs peuvent accepter/rejeter les demandes qui leur sont envoyées
CREATE POLICY "Users can respond to friend requests"
  ON friend_requests FOR UPDATE
  USING (to_user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- 6. RLS Policies pour friends
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;

-- Les utilisateurs peuvent voir leurs amis
CREATE POLICY "Users can see their friends"
  ON friends FOR SELECT
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Les utilisateurs peuvent créer des relations d'amitié (quand ils acceptent une demande)
CREATE POLICY "Users can create friendships"
  ON friends FOR INSERT
  WITH CHECK (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Les utilisateurs peuvent supprimer des amis
CREATE POLICY "Users can remove friends"
  ON friends FOR DELETE
  USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- 7. Trigger pour marquer les demandes expirées
CREATE OR REPLACE FUNCTION mark_expired_requests()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE friend_requests
  SET status = 'expired'
  WHERE status = 'pending' AND expires_at < NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour vérifier les expirations à chaque select sur friend_requests
-- (Optionnel - peut aussi être exécuté périodiquement)
