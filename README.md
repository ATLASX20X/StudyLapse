# StudyLapse

Une application Flutter d'enregistrement de timelapses d'étude avec fonctionnalités sociales.

## Fonctionnalités

### Enregistrement Timelapse
- Capture vidéo timelapse de sessions d'étude
- Coefficient de vitesse calculé automatiquement
- Mode économie d'énergie (écran noir pendant l'enregistrement)
- Filigranes personnalisables (stacked, circle, clock, timer, progressbar)
- Export vidéo haute qualité

### Réseau Social
- Système d'amis avec demandes (expirent après 24h)
- Feed communauté (posts publics)
- Feed ami (posts des amis uniquement)
- Recherche par identifiant ou nom d'affichage
- Système de likes
- Commentaires
- Profils utilisateurs
- Visibilité des posts (public, amis, privé)

### Authentification
- Email/Password via Supabase Auth
- Sécurité Row Level Security (RLS)

## Installation

### Prérequis
- Flutter SDK (>= 3.0.0)
- Dart SDK (>= 3.0.0)
- Android Studio / Xcode / VS Code
- Un compte Supabase

### Étapes

1. **Cloner le dépôt**
```bash
git clone https://github.com/TON_USERNAME/studylapse.git
cd studylapse
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Configurer Supabase**
- Créer un projet sur [Supabase](https://supabase.com)
- Exécuter les scripts SQL dans `supabase/migrations/` dans l'ordre :
  1. `supabase_setup.sql`
  2. `supabase_add_name_field.sql`
  3. `supabase_friends_system.sql`
  4. `supabase_trigger.sql`
  5. `supabase_rls_fix.sql`

4. **Configurer les variables d'environnement**
```bash
cp .env.example .env
```
Éditer `.env` avec vos credentials Supabase :
```
SUPABASE_URL=votre_url_supabase
SUPABASE_ANON_KEY=votre_cle_anon
```

5. **Lancer l'application**
```bash
flutter run
```

## Structure du projet

```
studylapse/
├── lib/                      # Code source Flutter
│   ├── main.dart            # Point d'entrée
│   ├── models/              # Modèles de données
│   ├── screens/             # Écrans de l'application
│   ├── services/            # Services (API, business logic)
│   └── widgets/             # Widgets réutilisables
├── android/                 # Configuration Android
├── ios/                     # Configuration iOS
├── web/                     # Configuration Web
├── supabase/                # Scripts et configuration Supabase
│   └── migrations/          # Scripts SQL de migration
├── docs/                    # Documentation
├── .env.example             # Template variables d'environnement
├── .gitignore               # Fichiers ignorés par Git
├── pubspec.yaml             # Dépendances Flutter
└── README.md                # Ce fichier
```

## Technologies

- **Framework** : Flutter
- **Langage** : Dart
- **Backend** : Supabase (PostgreSQL, Auth, Storage)
- **Base de données** : PostgreSQL avec RLS
- **Packages principaux** :
  - `supabase_flutter` : Intégration Supabase
  - `camera` : Capture vidéo
  - `ffmpeg_kit_flutter_new_video` : Traitement vidéo
  - `wakelock_plus` : Maintenir l'écran allumé
  - `gal` : Gallerie système

## Scripts de base de données

Les scripts SQL pour configurer Supabase sont dans `supabase/migrations/`. Voir le [README des migrations](supabase/migrations/README.md) pour plus de détails.

## Sécurité

- Les variables d'environnement (`.env`) ne sont PAS dans Git
- RLS (Row Level Security) activé sur toutes les tables
- Les tokens Supabase sont gérés automatiquement

## Contribution

Les contributions sont les bienvenues ! Voici les étapes :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commiter (`git commit -m 'Add AmazingFeature'`)
4. Pusher (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## Licence

Ce projet est sous licence MIT.

## Auteur

[Ton Nom] - [@ton_pseudo](https://github.com/TON_USERNAME)

## Remerciements

- Flutter team pour le framework
- Supabase pour l'infrastructure backend
- La communauté open source
