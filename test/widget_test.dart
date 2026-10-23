import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:facebook_save_app/main.dart';
import 'package:facebook_save_app/models/saved_item.dart';
import 'package:facebook_save_app/services/link_analyzer_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  test('SavedItem.fromMap parses fields and defaults safely', () {
    final now = Timestamp.now();
    final item = SavedItem.fromMap({
      'type': 'link',
      'title': 'Post de Jardinagem',
      'originalUrl': 'https://www.facebook.com/post/123',
      'createdAt': now,
    }, 'doc-1');

    expect(item.id, 'doc-1');
    expect(item.type, 'link');
    expect(item.title, 'Post de Jardinagem');
    expect(item.url, 'https://www.facebook.com/post/123');
    expect(item.createdAt, now);
  });

  test('LinkAnalyzerService detects videos, photos, posts, and comments', () {
    final videoResult = LinkAnalyzerService.analyze(
      'https://www.facebook.com/reel/987654321',
    );
    expect(videoResult.recommendedType, 'video');

    final imageResult = LinkAnalyzerService.analyze(
      'https://www.facebook.com/photo/?fbid=123456',
    );
    expect(imageResult.recommendedType, 'image');

    final postResult = LinkAnalyzerService.analyze(
      'https://www.facebook.com/jardins/posts/112233',
    );
    expect(postResult.recommendedType, 'text');

    final commentResult = LinkAnalyzerService.analyze(
      'https://www.facebook.com/jardins/posts/112233?comment_id=999',
    );
    expect(commentResult.recommendedType, 'comment');
  });

  testWidgets('Full paste -> recommend video -> confirm -> verify all tabs & buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FacebookSaveApp());
    await tester.pumpAndSettle();

    // 1. Verify we start on Início
    expect(find.text('FB Save • Início'), findsOneWidget);

    // 2. Enter a Facebook Reel URL
    await tester.enterText(
      find.byType(TextField).first,
      'https://www.facebook.com/reel/555666777',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // 3. Verify confirmation screen opened with Vídeos recommended
    expect(find.text('Confirmar e Guardar'), findsOneWidget);
    expect(find.text('Confirmar e Guardar em Vídeos'), findsOneWidget);

    // 4. Tap Confirmar e Guardar em Vídeos
    await tester.tap(find.text('Confirmar e Guardar em Vídeos'));
    await tester.pumpAndSettle();

    // 5. Verify it transitioned to Vídeos screen and saved the item
    expect(find.text('FB Save • Vídeos'), findsOneWidget);
    expect(find.text('Abrir no Facebook'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('Apagar'), findsOneWidget);

    // 6. Test Copy button on Vídeos tab
    await tester.tap(find.text('Copiar'));
    await tester.pumpAndSettle();

    // 7. Test Delete button on Vídeos tab
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    expect(find.text('Secção de Vídeos vazia'), findsOneWidget);

    // 8. Test Colar Novo button on Vídeos tab
    await tester.tap(find.text('Colar Novo'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar e Guardar'), findsOneWidget);
    // Cancel back to Vídeos
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Vídeos'), findsOneWidget);

    // 9. Verify switching across ALL tabs (Posts, Imagens, Vídeos, Links, Comentários, Início)
    await tester.tap(find.byKey(const ValueKey<String>('top_tab_1')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Posts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('top_tab_2')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Imagens'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('top_tab_4')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Links'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('top_tab_5')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Comentários'), findsOneWidget);

    // 10. Test Início button inside tab header
    await tester.tap(find.byKey(const ValueKey<String>('top_tab_0')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Início'), findsOneWidget);
  });
}
