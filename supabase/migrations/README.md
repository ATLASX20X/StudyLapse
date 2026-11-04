# Supabase Migrations

Ce dossier contient les scripts SQL pour configurer et maintenir la base de données Supabase de StudyLapse.

## 📋 Scripts disponibles

### 1. supabase_setup.sql
- **Description** : Script initial de setup de la base de données
- **Contenu** : Création des tables users, posts, comments, likes, friends, friend_requests
- **Quand l'utiliser** : Première installation du projet sur une nouvelle base Supabase

### 2. supabase_add_name_field.sql
- **Description** : Ajout du champ `name` (nom d'affichage) à la table users
- **Contenu** : ALTER TABLE pour ajouter la colonne name
- **Quand l'utiliser** : Mise à jour de la base existante

### 3. supabase_friends_system.sql
- **Description** : Configuration du système d'amis (friend_requests, friends)
- **Contenu** : Tables friend_requests et friends avec triggers
- **Quand l'utiliser** : Ajout de la fonctionnalité amis

### 4. supabase_rls_fix.sql
- **Description** : Corrections des politiques RLS (Row Level Security)
- **Contenu** : Suppression et recréation des politiques pour likes, comments, friends
- **Quand l'utiliser** : Correction de bugs d'accès aux données

### 5. supabase_trigger.sql
- **Description** : Triggers automatiques pour la création de profils
- **Contenu** : Trigger qui crée automatiquement un user quand un utilisateur s'inscrit
- **Quand l'utiliser** : Automatisation de la création de profils

## 🚀 Comment utiliser ces scripts

### Dans Supabase SQL Editor :
1. Va sur https://supabase.com/dashboard
2. Sélectionne ton projet
3. Clique sur "SQL Editor" dans la barre latérale
4. Ouvre un nouveau script
5. Copie-colle le contenu du fichier SQL
6. Clique sur "Run"

### Ordre d'exécution recommandé :
```
1. supabase_setup.sql (d'abord)
2. supabase_add_name_field.sql
3. supabase_friends_system.sql
4. supabase_trigger.sql
5. supabase_rls_fix.sql (peut être exécuté plusieurs fois pour corriger)
```

## ⚠️ Notes importantes

- Certains scripts contiennent des instructions DROP (suppression) - soyez prudent
- Exécutez toujours les scripts sur une base de test avant la production
- Faites un backup de votre base avant d'exécuter des modifications majeures
- Les scripts RLS peuvent être réexécutés sans danger

## 📝 Nouveaux scripts

Quand vous ajoutez une nouvelle fonctionnalité qui nécessite des changements de base de données :
1. Créez un nouveau fichier SQL dans ce dossier
2. Nommez-le avec un descriptif clair (ex: `supabase_add_notifications_table.sql`)
3. Ajoutez une description dans ce README
4. Commitez avec Git
