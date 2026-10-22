---
name: Firebase Configuration
description: Guia passo‑a‑passo para conectar o projeto Flutter à Firebase (Firestore, Storage) e habilitar o uso offline.
---

## Objetivo
Integrar o app Flutter ao Firebase, permitindo que os itens salvos sejam persistidos em **Cloud Firestore** (metadados) e **Firebase Storage** (mídia).

## Pré‑requisitos
- Conta Google
- Projeto Firebase criado (https://console.firebase.google.com)

## Passos
### 1️⃣ Criar o projeto Firebase
1. No console, clique **Add project** → siga o wizard.
2. Desativar Google Analytics (opcional).
3. Após a criação, selecione o projeto.

### 2️⃣ Registrar apps Android e iOS
#### Android
1. Clique no ícone Android → preencha `android.package` (ex.: `com.example.facebook_save_app`).
2. Opcional: SHA‑1 (necessário para Facebook Login). Use `./gradlew signingReport` para obter.
3. Baixe `google-services.json`.
4. Copie para `android/app/` do projeto.
5. No `android/build.gradle` adicione:
   ```gradle
   classpath 'com.google.gms:google-services:4.4.2'
   ```
   e no `android/app/build.gradle` ao final:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```
#### iOS
1. Clique no ícone iOS → bundle ID `com.example.facebookSaveApp`.
2. Baixe `GoogleService-Info.plist`.
3. Coloque em `ios/Runner/`.
4. No `ios/Podfile` assegure‑se de ter `platform :ios, '12.0'`.
5. Rode `pod install` dentro da pasta `ios`.

### 3️⃣ Habilitar os serviços
- **Firestore** → *Create database* → modo **Production** (ou **Test** para início).
- **Storage** → *Get started* → mantenha regras padrão ou ajuste para `allow read, write: if request.auth != null;`.
- **Authentication** → habilite **Facebook** (usaremos o SDK). Insira **App ID** e **App Secret** do Facebook.

### 4️⃣ Atualizar o código Flutter
1. No `main.dart` já existe `await Firebase.initializeApp();`.
2. Nos arquivos de escrita (`_handleSharedData`) usamos:
   - `FirebaseFirestore.instance.collection('saved_items')`.
   - `FirebaseStorage.instance.ref().child('media/...')`.
3. Para **offline persistence** (opcional) adicione após `initializeApp()`:
   ```dart
   await FirebaseFirestore.instance.enablePersistence();
   ```

### 5️⃣ Testes de integração
```bash
flutter clean
flutter pub get
flutter run -d android   # ou -d ios
```
- Use o share‑target no Facebook e verifique se o documento aparece no console do Firestore.
- Verifique o upload de mídia em Storage (pasta `media/`).

## Dicas avançadas
- **Regra de segurança**: no console, `rules_version = '2'; service cloud.firestore { match /databases/{database}/documents { match /saved_items/{docId} { allow read, write: if request.auth != null; } } }`
- **Exportação**: use `firebase cli` (`firebase firestore:export`) para backup.
- **Sincronização offline**: já vem automática com o SDK; apenas habilite a persistência.

---
