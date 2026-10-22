---
name: URL Launcher Integration
description: Instruções para adicionar a dependência url_launcher, atualizar o pubspec.yaml, rodar flutter pub get e usar o pacote para abrir links nas telas.
---

## 1️⃣ Atualizar `pubspec.yaml`
Adicione a linha abaixo em `dependencies`:
```yaml
url_launcher: ^6.2.6
```
Já foi incluída no arquivo `pubspec.yaml`.

## 2️⃣ Instalar a dependência
Execute no terminal, dentro da pasta do projeto:
```bash
flutter pub get
```
Isso baixa o pacote e gera o código necessário.

## 3️⃣ Importar no código Dart
Em qualquer arquivo que precise abrir URLs (ex.: `saved_items_screen.dart`), adicione:
```dart
import 'package:url_launcher/url_launcher.dart';
```
A importação já está presente.

## 4️⃣ Utilizar `launchUrl`
Para abrir um link use:
```dart
Future<void> _openLink(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw 'Could not launch $url';
  }
}
```
No `SavedItemsScreen`, substitua o `onTap` por:
```dart
onTap: () async => await _openLink(item.url!),
```

## 5️⃣ Teste rápido
- Rode a app (`flutter run`).
- Navegue até a aba **Links**.
- Toque em um item e verifique se o navegador do dispositivo abre.

---
