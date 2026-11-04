# Setup Réseau Social - Supabase

## ✅ Étape 1 terminée : Setup Supabase

### Ce qui a été créé:

1. **Configuration Supabase**
   - `lib/services/supabase_service.dart` : Service singleton pour accéder à Supabase
   - `.env.example` : Template pour les credentials
   - `SUPABASE_SETUP.md` : Guide détaillé de configuration

2. **Structure de la base de données**
   - `supabase_setup.sql` : Script SQL complet pour créer toutes les tables
   - Tables: users, posts, followers, likes, comments
   - Indexes pour la performance
   - Row Level Security (RLS) activé
   - Triggers pour updated_at automatique

3. **Modèles Dart**
   - `lib/models/user.dart` : Modèle utilisateur (renommé en `AppUser` pour éviter conflit avec Supabase)
   - `lib/models/post.dart` : Modèle post avec enum visibility
   - `lib/models/follow.dart` : Modèle follow
   - `lib/models/like.dart` : Modèle like
   - `lib/models/comment.dart` : Modèle commentaire

4. **Service Authentification**
   - `lib/services/auth_service.dart` : Service pour auth (email/password + Google OAuth placeholder)

5. **Intégration dans main.dart**
   - Initialisation de Supabase au démarrage
   - Gestion d'erreur si credentials manquants

---

## 📋 Prochaines étapes

### Étape 2 : Configurer Supabase (Manuel - à faire par vous)

1. Créer un compte sur [supabase.com](https://supabase.com)
2. Créer un nouveau projet
3. Copier les credentials dans `.env`
4. Exécuter le script SQL dans le dashboard
5. Configurer le Storage bucket "videos"
6. (Optionnel) Configurer Google OAuth

**Voir `SUPABASE_SETUP.md` pour les instructions détaillées**

---

### Étape 3 : Écrans d'authentification

À créer:
- `lib/screens/login_screen.dart` : Login email/password
- `lib/screens/register_screen.dart` : Inscription
- `lib/screens/profile_setup_screen.dart` : Avatar + bio après inscription

---

### Étape 4 : Service Upload Video

À créer:
- `lib/services/storage_service.dart` : Upload vers Supabase Storage
- Vérification limite 1Go par utilisateur
- Génération de thumbnail
- Progress d'upload

---

### Étape 5 : Service Database Posts

À créer:
- `lib/services/post_service.dart` : CRUD posts
- `lib/services/feed_service.dart` : Récupérer feed avec pagination
- Intégration avec export screen

---

### Étape 6 : Feed Scrollable

À créer:
- `lib/screens/home_feed_screen.dart` : Page d'accueil avec feed
- `lib/widgets/post_card.dart` : Widget pour afficher un post
- Pagination infinie
- Pull-to-refresh

---

### Étape 7 : Profil Utilisateur

À créer:
- `lib/screens/profile_screen.dart` : Page de profil
- Grille des posts
- Stats followers/following/posts
- Bouton follow/unfollow

---

### Étape 8 : Système de Followers

À créer:
- `lib/services/follow_service.dart` : Follow/Unfollow
- `lib/screens/followers_screen.dart` : Liste followers
- `lib/screens/following_screen.dart` : Liste following

---

### Étape 9 : Module de Recherche

À créer:
- `lib/services/search_service.dart` : Recherche users/posts/subjects
- `lib/screens/search_screen.dart` : Écran de recherche
- Tabs + résultats

---

### Étape 10 : Likes & Commentaires

À créer:
- `lib/services/like_service.dart` : Like/Unlike
- `lib/services/comment_service.dart` : CRUD commentaires
- `lib/screens/comments_screen.dart` : Commentaires d'un post

---

### Étape 11 : Statistiques

À créer:
- `lib/services/stats_service.dart` : Agréger stats
- `lib/screens/stats_screen.dart` : Dashboard stats
- Graphiques (package `fl_chart`)

---

## 🚀 Pour continuer

Une fois que vous avez configuré Supabase (étape 2), dites-moi et je passerai à l'étape 3 (écrans d'authentification) !

---

## 📝 Notes importantes

- Le code actuel peut fonctionner sans Supabase (grâce au try/catch dans main.dart)
- Les credentials sont dans `.env` (non versionné)
- Google OAuth est en placeholder - nécessite configuration Google Cloud Console
- La limite de 1Go est stockée dans `users.storage_limit_bytes`
- RLS (Row Level Security) protège les données au niveau base de données
