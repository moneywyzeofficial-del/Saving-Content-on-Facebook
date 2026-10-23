import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

    // Test extraction of summary, secondary links (for Links), and images (for Imagens)
    final richVideoInput =
        'Dicas de poda de árvores de fruto https://www.facebook.com/reel/987654321 '
        'Guia completo em https://jardim-pro.pt/guia e foto https://exemplo.pt/esquema.jpg';
    final richResult = LinkAnalyzerService.analyze(richVideoInput);
    expect(richResult.recommendedType, 'video');
    expect(richResult.summary, contains('Dicas de poda de árvores de fruto'));
    expect(richResult.extractedLinks, contains('https://jardim-pro.pt/guia'));
    expect(
      richResult.extractedImages,
      contains('https://exemplo.pt/esquema.jpg'),
    );
  });

  test('LinkAnalyzerService.fetchAndAnalyze parses remote video metadata, summary, links, and images',
      () async {
    final mockClient = MockClient((request) async {
      final body = jsonEncode({
        'status': 'success',
        'data': {
          'title':
              '120 mil visualizações · 3.4K reações | Como tratar a água da piscina no verão | Piscinas & Jardins | Facebook',
          'description':
              'Passo a passo para manter o pH equilibrado. Catálogo em https://piscinas.pt/catalogo e tabela https://piscinas.pt/tabela.png',
          'author': 'Piscinas & Jardins',
          'url': 'https://www.facebook.com/watch/?v=123456789',
          'image': {
            'url': 'https://scontent.flis1-1.fna.fbcdn.net/v/capa_video.jpg',
          },
        },
      });
      return http.Response.bytes(
        utf8.encode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final result = await LinkAnalyzerService.fetchAndAnalyze(
      'https://www.facebook.com/watch/?v=123456789',
      client: mockClient,
    );

    expect(result.recommendedType, 'video');
    expect(result.metadataFetched, isTrue);
    expect(result.suggestedTitle, 'Como tratar a água da piscina no verão');
    expect(result.summary, contains('Passo a passo para manter o pH equilibrado'));
    expect(result.summary, contains('Piscinas & Jardins'));
    expect(result.summary, contains('120 mil visualizações'));
    expect(result.extractedLinks, contains('https://piscinas.pt/catalogo'));
    expect(result.extractedImages, contains('https://piscinas.pt/tabela.png'));
    expect(
      result.extractedImages,
      contains('https://scontent.flis1-1.fna.fbcdn.net/v/capa_video.jpg'),
    );
  });

  testWidgets('Full paste -> recommend video -> confirm -> verify all tabs & buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FacebookSaveApp());
    await tester.pumpAndSettle();

    // 1. Verify we start on Início
    expect(find.text('FB Save • Início'), findsOneWidget);

    // 2. Enter a Facebook Reel URL containing an extra link and an extra image
    await tester.enterText(
      find.byType(TextField).first,
      'Vídeo sobre manutenção de relvado https://www.facebook.com/reel/555666777 '
      'Mais info em https://relvados.pt/dicas e imagem https://relvados.pt/foto.png',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // 3. Verify confirmation screen opened with Vídeos recommended + Summary + Links + Imagens
    expect(find.text('Confirmar e Guardar'), findsOneWidget);
    expect(find.text('Resumo do Vídeo / Conteúdo'), findsOneWidget);
    expect(find.text('Links para o separador Links (1)'), findsOneWidget);
    expect(find.text('Imagens para o separador Imagens (1)'), findsOneWidget);
    expect(find.text('Confirmar e Guardar em Vídeos'), findsOneWidget);

    // 4. Tap Confirmar e Guardar em Vídeos
    await tester.tap(find.text('Confirmar e Guardar em Vídeos'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 5. Verify it transitioned to Vídeos screen and saved the video + its summary
    expect(find.text('FB Save • Vídeos'), findsOneWidget);
    expect(find.text('Resumo do Conteúdo'), findsOneWidget);
    expect(find.text('1 link(s) na aba Links'), findsOneWidget);
    expect(find.text('1 imagem(ns) na aba Imagens'), findsOneWidget);
    expect(find.text('Abrir no Facebook'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('Apagar'), findsOneWidget);

    // 6. Test Copy button on Vídeos tab
    await tester.tap(find.text('Copiar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 7. Test Delete button on Vídeos tab
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
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

    // 9. Verify switching across ALL tabs and check that Imagens (tab 2) and Links (tab 4) received the extracted items!
    await tester.tap(find.byKey(const ValueKey<String>('top_tab_1')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Posts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('top_tab_2')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Imagens'), findsOneWidget);
    expect(find.textContaining('https://relvados.pt/foto.png'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('top_tab_4')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Links'), findsOneWidget);
    expect(find.textContaining('https://relvados.pt/dicas'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('top_tab_5')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Comentários'), findsOneWidget);

    // 10. Test Início button inside tab header
    await tester.tap(find.byKey(const ValueKey<String>('top_tab_0')));
    await tester.pumpAndSettle();
    expect(find.text('FB Save • Início'), findsOneWidget);
  });
}
