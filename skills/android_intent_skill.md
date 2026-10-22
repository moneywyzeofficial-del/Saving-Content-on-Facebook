---
name: Android Share Intent Integration
description: Configura o AndroidManifest e MainActivity para receber intents de compartilhamento do Facebook e enviá‑los ao Flutter via MethodChannel.
---

## Objetivo
Permitir que a aplicação apareça como **share target** no Android e entregue os dados compartilhados (texto, imagem, vídeo, URL) ao código Dart.

## Passos
1. **AndroidManifest.xml**
   ```xml
   <intent-filter>
       <action android:name="android.intent.action.SEND" />
       <category android:name="android.intent.category.DEFAULT" />
       <data android:mimeType="*/*" />
   </intent-filter>
   ```
   Coloque dentro da `<activity>` que hospeda o Flutter (`MainActivity`).

2. **MainActivity.kt**
   ```kotlin
   class MainActivity: FlutterActivity() {
       private val CHANNEL = "com.example.facebook_save/share"
       private var methodChannel: MethodChannel? = null

       override fun onCreate(savedInstanceState: Bundle?) {
           super.onCreate(savedInstanceState)
           methodChannel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, CHANNEL)
           handleIntent(intent)
       }

       override fun onNewIntent(intent: Intent) {
           super.onNewIntent(intent)
           handleIntent(intent)
       }

       private fun handleIntent(intent: Intent) {
           if (Intent.ACTION_SEND == intent.action) {
               val data = mutableMapOf<String, Any>()
               intent.getStringExtra(Intent.EXTRA_TEXT)?.let { data["text"] = it }
               intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)?.let { uri ->
                   val mime = contentResolver.getType(uri) ?: "application/octet-stream"
                   if (mime.startsWith("image")) data["imageUri"] = uri.toString()
                   else if (mime.startsWith("video")) data["videoUri"] = uri.toString()
               }
               methodChannel?.invokeMethod("onShare", data)
           }
       }
   }
   ```
   O método `onShare` será capturado no Dart (`MethodChannel`).

3. **Flutter side**
   ```dart
   static const platform = MethodChannel('com.example.facebook_save/share');
   platform.setMethodCallHandler((call) async {
     if (call.method == 'onShare') {
       await _handleSharedData(call.arguments as Map);
     }
   });
   ```

## Testes
- Instale a app no dispositivo (`flutter run`).
- No Facebook, escolha *Compartilhar* → *facebook_save_app*.
- Verifique se o `SnackBar` “Conteúdo salvo!” aparece.

## Dicas
- Use `flutter logs` para depurar o conteúdo recebido.
- Certifique‑se de que o `android:exported="true"` está definido no `<activity>` (necessário a partir do Android 12).

---
