# Configuration Google Sign-In

## Android

### 1. Créer un projet Google Cloud Console

1. Allez sur [Google Cloud Console](https://console.cloud.google.com)
2. Créez un nouveau projet ou utilisez un existant
3. Activez l'API Google Sign-In

### 2. Créer des credentials OAuth 2.0

1. Allez dans **Credentials** > **Create Credentials** > **OAuth client ID**
2. Type d'application: **Android**
3. Package name: `com.example.studylapse` (remplacez par votre package name)
4. SHA-1 fingerprint: Obtenez-le avec:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore
   ```
5. Créez le client ID

### 3. Ajouter la configuration dans Android

Ajoutez dans `android/app/build.gradle`:
```gradle
dependencies {
    implementation 'com.google.android.gms:play-services-auth:20.7.0'
}
```

Ajoutez dans `android/app/src/main/AndroidManifest.xml`:
```xml
<application ...>
    <meta-data
        android:name="com.google.android.gms.wallet.api.enabled"
        android:value="true" />
</application>
```

### 4. Configurer Supabase

1. Allez dans votre dashboard Supabase
2. **Authentication** > **Providers** > **Google**
3. Activez Google
4. Collez le Client ID et Client Secret
5. Ajoutez votre redirect URI: `https://[your-project-id].supabase.co/auth/v1/callback`

---

## iOS

### 1. Créer des credentials iOS

1. Dans Google Cloud Console, créez un OAuth client ID pour iOS
2. Bundle ID: `com.example.studylapse` (remplacez par votre bundle ID)
3. Copiez le Client ID

### 2. Configurer dans Xcode

1. Ouvrez `ios/Runner.xcworkspace` dans Xcode
2. Allez dans **Signing & Capabilities**
3. Ajoutez **Capability** > **Sign in with Apple** (optionnel)
4. Configurez votre Bundle ID

### 3. Mettre à jour Info.plist

Ajoutez dans `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

---

## Test

Une fois configuré, vous pouvez tester:
- Email/Password: Fonctionne sans configuration supplémentaire
- Google OAuth: Nécessite la configuration ci-dessus

Si Google OAuth échoue, l'app continuera de fonctionner avec email/password.
