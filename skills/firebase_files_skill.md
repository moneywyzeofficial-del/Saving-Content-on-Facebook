---
name: Firebase Files Placement
description: Guia para copiar `google-services.json` (Android) e `GoogleService-Info.plist` (iOS) para os diretórios corretos do projeto Flutter.
---

## 1️⃣ Obter os arquivos do console Firebase
- **Android**: No Firebase Console → *Project Settings* → *Your apps* → Android → clique **Download `google-services.json`**.
- **iOS**: No mesmo painel → iOS → clique **Download `GoogleService-Info.plist`**.

## 2️⃣ Copiar para o projeto
### Android
```bash
# estando na raiz do projeto (facebook_save_app)
cp /caminho/para/google-services.json android/app/
```
- O arquivo deve ficar exatamente em `android/app/google-services.json`.
- O `build.gradle` já contém a aplicação do plugin `com.google.gms.google-services` (verifique se a linha `apply plugin: 'com.google.gms.google-services'` está presente no final de `android/app/build.gradle`).

### iOS
```bash
cp /caminho/para/GoogleService-Info.plist ios/Runner/
```
- O arquivo deve ficar em `ios/Runner/GoogleService-Info.plist`.
- Caso o Xcode não reconheça o arquivo, abra o projeto Xcode (`ios/Runner.xcworkspace`) e arraste o `.plist` para o *Runner* target (marcando **Copy items if needed**).

## 3️⃣ Verificar integração
- Execute `flutter clean && flutter pub get`.
- Rode `flutter run` (Android ou iOS). O log deve exibir algo como `Firebase.initializeApp` sem erros.
- No console do Firebase, veja se a app aparece em *Usage* → *Realtime* → *Firestore* após salvar alguns itens.

## 4️⃣ Dicas
- **Android**: Se usar *flavors*, copie o arquivo para cada pasta `app/src/<flavor>/`.
- **iOS**: Certifique‑se de que o *Bundle Identifier* no `Info.plist` corresponde ao registrado no Firebase.
- Não commit **google-services.json** ou **GoogleService-Info.plist** em repositórios públicos.

---
