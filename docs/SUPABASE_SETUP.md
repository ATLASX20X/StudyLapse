# Configuration Supabase pour StudyLapse

## 1. Créer un compte Supabase

1. Allez sur [https://supabase.com](https://supabase.com)
2. Créez un compte gratuit
3. Cliquez sur "New Project"
4. Nommez le projet `studylapse`
5. Choisissez une région proche de vous
6. Créez un mot de passe pour la base de données
7. Attendez que le projet soit créé (2-3 minutes)

## 2. Récupérer les credentials

1. Dans le dashboard Supabase, allez dans **Settings > API**
2. Copiez:
   - `Project URL` → coller dans `.env` comme `SUPABASE_URL`
   - `anon public` key → coller dans `.env` comme `SUPABASE_ANON_KEY`

## 3. Configurer le fichier .env

1. Copiez `.env.example` vers `.env`:
   ```bash
   cp .env.example .env
   ```

2. Éditez `.env` et remplacez les valeurs:
   ```env
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```

## 4. Exécuter le script SQL

1. Dans le dashboard Supabase, allez dans **SQL Editor**
2. Cliquez sur "New Query"
3. Copiez le contenu de `supabase_setup.sql`
4. Collez-le dans l'éditeur
5. Cliquez sur "Run" (ou Ctrl+Enter)
6. Attendez que toutes les tables soient créées

## 5. Exécuter le trigger d'inscription automatique

1. Dans le même **SQL Editor**
2. Cliquez sur "New Query"
3. Copiez le contenu de `supabase_trigger.sql`
4. Collez-le dans l'éditeur
5. Cliquez sur "Run" (ou Ctrl+Enter)
6. Cela crée automatiquement un profil utilisateur lors de l'inscription

## 6. Configurer le Storage

1. Allez dans **Storage** dans le dashboard
2. Cliquez sur "Create a new bucket"
3. Nommez le bucket: `videos`
4. Décochez "Public bucket" (pour l'instant)
5. Cliquez sur "Create bucket"

6. Allez dans **Storage > videos > Policies**
7. Créez une politique "Select" (Read):
   - Name: `Public read`
   - Allowed operations: `SELECT`
   - Target roles: `anon`, `authenticated`
   - USING expression: `true`

8. Créez une politique "Insert" (Write):
   - Name: `Authenticated upload`
   - Allowed operations: `INSERT`
   - Target roles: `authenticated`
   - WITH CHECK expression: `bucket_id = 'videos'`

## 7. Configurer Google OAuth (Optionnel)

1. Allez dans [Google Cloud Console](https://console.cloud.google.com)
2. Créez un nouveau projet ou utilisez un existant
3. Activez Google+ API
4. Créez des credentials OAuth 2.0:
   - Type: Web application
   - Authorized redirect URIs: `https://[your-project-id].supabase.co/auth/v1/callback`

5. Dans le dashboard Supabase:
   - Allez dans **Authentication > Providers**
   - Activez Google
   - Collez le Client ID et Client Secret
   - Sauvegardez

## 8. Vérifier l'installation

Lancez l'app:
```bash
flutter run
```

Si vous voyez l'erreur "Supabase credentials not found", vérifiez que:
- Le fichier `.env` existe à la racine du projet
- Les valeurs sont correctement copiées
- Le fichier `.env` est bien dans `assets` de `pubspec.yaml`

## Structure de la base de données

### Tables créées:
- `users`: Profils utilisateurs
- `posts`: Timelapses publiés
- `followers`: Relations de suivi
- `likes`: Likes sur les posts
- `comments`: Commentaires

### Storage:
- Bucket `videos`: Stockage des vidéos timelapses

### Limites:
- 1 Go de stockage par utilisateur (configurable dans `users.storage_limit_bytes`)
- Row Level Security activé pour protéger les données
