---
name: Facebook Login & Permissions
description: Guia para configurar o SDK do Facebook no Flutter, obter App ID/Secret, solicitar permissões e implementar login com flutter_facebook_auth.
---

## Objetivo
Permitir que a app autentique o usuário via **Facebook Login** e, opcionalmente, obtenha permissões para acessar dados adicionais (ex.: `user_posts`).

## Passos
### 1️⃣ Criar o App no Facebook Developers
1. Acesse <https://developers.facebook.com/apps> e clique **Create App** → *Consumer*.
2. Defina **App Name** e **Contact Email**.
3. Anote **App ID** e **App Secret** (usados nas configurações Android/iOS).
4. Em *Settings → Basic* adicione a **Package Name** Android (`com.example.facebook_save_app`) e a **iOS Bundle ID** (`com.example.facebookSaveApp`).
5. Em *Facebook Login → Settings* habilite **Login with the JavaScript SDK** (necessário para o flutter SDK).
6. Defina **Valid OAuth Redirect URIs**:
   - Android: `fb<APP_ID>://authorize/`
   - iOS: `fb<APP_ID>://authorize/`

### 2️⃣ Configurar Android
- No `android/app/src/main/res/values/strings.xml` substitua `<string name="facebook_app_id">YOUR_FACEBOOK_APP_ID</string>` pelo seu App ID.
- Em `android/app/src/main/AndroidManifest.xml` dentro `<application>` adicione:
  ```xml
  <meta-data android:name="com.facebook.sdk.ApplicationId" android:value="@string/facebook_app_id"/>
  <activity android:name="com.facebook.FacebookActivity"
            android:configChanges="keyboard|keyboardHidden|screenLayout|screenSize|orientation"
            android:label="@string/app_name" />
  ```
- No `android/app/build.gradle` adicione o Maven do Facebook:
  ```gradle
  repositories { mavenCentral() }
  dependencies { implementation 'com.facebook.android:facebook-android-sdk:[8,9)' }
  ```
- Gere o **SHA‑1** do seu keystore (`./gradlew signingReport`) e adicione no *Facebook App* → *Settings → Android* → *Key Hashes*.

### 3️⃣ Configurar iOS
- No `ios/Runner/Info.plist` já existem as chaves `FacebookAppID`, `FacebookDisplayName` e o esquema `fbYOUR_FACEBOOK_APP_ID`. Substitua `YOUR_FACEBOOK_APP_ID`.
- No Xcode, em **Signing & Capabilities** → **Associated Domains**, adicione `applinks:YOUR_FACEBOOK_APP_ID.facebook.com` (opcional).
- Execute `pod install` após adicionar `flutter_facebook_auth` ao `pubspec.yaml`.

### 4️⃣ Dependência Flutter
Adicione ao `pubspec.yaml`:
```yaml
dependencies:
  flutter_facebook_auth: ^5.0.8
```
Execute `flutter pub get`.

### 5️⃣ Implementar login no código
```dart
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

Future<void> _login() async {
  final result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile', 'user_posts']);
  if (result.status == LoginStatus.success) {
    final token = result.accessToken!;
    // Guardar token ou usá‑lo para chamadas Graph API
    setState(() => _fbAccessToken = token);
  } else {
    // Tratar erros ou cancelamento
    print('Login falhou: ${result.status}');
  }
}
```

### 6️⃣ (Opcional) Usar Graph API
Com o `accessToken.token`, faça requisições HTTP a `https://graph.facebook.com/v20.0/me/posts?...` para obter posts do usuário, respeitando as permissões aprovadas.

## Dicas
- Teste login em **dispositivo real**, pois emuladores podem não ter o aplicativo Facebook instalado.
- Use `FacebookAuth.instance.getUserData()` para obter nome, email, foto de perfil.
- Sempre verifique `result.status` antes de usar o token.
- Revogue permissões na conta do Facebook (Settings → Apps) ao depurar.

---
