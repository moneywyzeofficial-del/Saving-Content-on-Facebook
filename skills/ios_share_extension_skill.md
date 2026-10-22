---
name: iOS Share Extension Integration
description: Configura a extensão de compartilhamento no iOS para receber dados do Facebook e enviá‑los ao Flutter via MethodChannel.
---

## Objetivo
Permitir que a app apareça como **share target** no iOS (Share Sheet) e entregue os dados compartilhados (texto, imagem, vídeo, URL) ao código Dart.

## Passos
1. **Criar o target Share Extension**
   - No Xcode, abra `ios/Runner.xcworkspace`.
   - *File → New → Target → Share Extension*.
   - Nome: `FacebookSaveExtension`.
   - Desmarque *Include UI* (usaremos a UI padrão). O Xcode cria `ShareViewController.swift`.

2. **Implementar `ShareViewController.swift`** (exemplo pronto em `ios/ShareExtension/ShareViewController.swift`).
   - Captura `NSExtensionItem` e extrai `public.text`, `public.url`, `public.image`, `public.movie`.
   - Constrói um `Dictionary<String, Any>` chamado `data`.
   - Inicializa um `FlutterEngine` (isolado) e registra plugins:
     ```swift
     flutterEngine = FlutterEngine(name: "share_engine")
     flutterEngine?.run()
     GeneratedPluginRegistrant.register(with: flutterEngine!)
     ```
   - Usa `FlutterMethodChannel(name: "com.example.facebook_save/share", binaryMessenger: flutterEngine!.binaryMessenger)` para chamar `onShare` com `data`.
   - Finaliza a extensão com `self.extensionContext?.completeRequest(...)`.

3. **Configurações no `Info.plist` da extensão**
   - Adicione `NSExtensionActivationSupportsImageWithMaxCount`, `NSExtensionActivationSupportsMovieWithMaxCount`, etc., para aceitar imagens e vídeos.
   - Insira o `FacebookAppID` e o esquema `fb<APP_ID>` (mesmo do `Runner`).
   - Defina permissões de foto, câmera, microfone conforme necessário.

4. **Flutter side (MethodChannel)** – já está configurado em `lib/main.dart`:
   ```dart
   static const platform = MethodChannel('com.example.facebook_save/share');
   platform.setMethodCallHandler(...);
   ```
   O mesmo canal funciona tanto para Android quanto iOS.

## Testes
- Rode a app no dispositivo iOS (`flutter run`).
- No Facebook, escolha *Compartilhar* → *More* → selecione **Facebook Save Content** (extensão aparece).
- Verifique se o `SnackBar` aparece e se o conteúdo foi salvo no Firestore.

## Dicas
- Use `println` no Swift para depurar (`print("debug")`).
- Lembre‑se de habilitar *App Groups* se precisar compartilhar arquivos entre o app e a extensão.
- A extensão tem tempo limitado (≈30 s); faça upload rápido ao Firebase.

---
