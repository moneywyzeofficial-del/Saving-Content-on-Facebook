// lib/services/link_analyzer_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class LinkAnalysisResult {
  final String rawInput;
  final String? normalizedUrl;
  final String recommendedType; // 'text', 'image', 'video', 'link', 'comment'
  final String detectedLabel;
  final String recommendationReason;
  final String suggestedTitle;
  final String summary;
  final List<String> extractedLinks;
  final List<String> extractedImages;
  final String host;
  final bool metadataFetched;

  const LinkAnalysisResult({
    required this.rawInput,
    required this.normalizedUrl,
    required this.recommendedType,
    required this.detectedLabel,
    required this.recommendationReason,
    required this.suggestedTitle,
    this.summary = '',
    this.extractedLinks = const <String>[],
    this.extractedImages = const <String>[],
    required this.host,
    this.metadataFetched = false,
  });

  LinkAnalysisResult copyWith({
    String? rawInput,
    String? normalizedUrl,
    String? recommendedType,
    String? detectedLabel,
    String? recommendationReason,
    String? suggestedTitle,
    String? summary,
    List<String>? extractedLinks,
    List<String>? extractedImages,
    String? host,
    bool? metadataFetched,
  }) {
    return LinkAnalysisResult(
      rawInput: rawInput ?? this.rawInput,
      normalizedUrl: normalizedUrl ?? this.normalizedUrl,
      recommendedType: recommendedType ?? this.recommendedType,
      detectedLabel: detectedLabel ?? this.detectedLabel,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      suggestedTitle: suggestedTitle ?? this.suggestedTitle,
      summary: summary ?? this.summary,
      extractedLinks: extractedLinks ?? this.extractedLinks,
      extractedImages: extractedImages ?? this.extractedImages,
      host: host ?? this.host,
      metadataFetched: metadataFetched ?? this.metadataFetched,
    );
  }
}

class LinkAnalyzerService {
  LinkAnalyzerService._();

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s\)\]\>\"' "'" r']+|(?:www\.|m\.|web\.)?facebook\.com\/[^\s\)\]\>\"' "'" r']+|fb\.watch\/[^\s\)\]\>\"' "'" r']+|(?:www\.|bit\.ly\/|t\.me\/|youtu\.be\/|instagram\.com\/|tiktok\.com\/)[^\s\)\]\>\"' "'" r']+)',
    caseSensitive: false,
  );

  /// Verifica se um URL corresponde a uma imagem ou fotografia
  static bool isImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    final fullLower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        fullLower.contains('/photo') ||
        fullLower.contains('/photos/') ||
        fullLower.contains('fbid=') ||
        fullLower.contains('scontent');
  }

  static bool _isGenericFacebookIcon(String url) {
    final lower = url.toLowerCase();
    return lower.contains('fb_icon') ||
        lower.contains('rsrc.php') ||
        lower.contains('static.xx.fbcdn.net/rsrc');
  }

  /// Extrai todos os URLs presentes num texto, normalizando para https://
  static List<String> extractAllUrls(String text) {
    if (text.trim().isEmpty) return const <String>[];
    final matches = _urlRegex.allMatches(text);
    final result = <String>[];
    final seen = <String>{};

    for (final m in matches) {
      var raw = m.group(0)!.trim();
      raw = raw.replaceAll(RegExp(r'[\.,;:!\?]+$'), '');
      if (raw.isEmpty) continue;
      if (!raw.toLowerCase().startsWith('http://') &&
          !raw.toLowerCase().startsWith('https://')) {
        raw = 'https://$raw';
      }
      final key = _canonicalUrlKey(raw);
      if (seen.add(key)) {
        result.add(raw);
      }
    }
    return result;
  }

  static String _canonicalUrlKey(String url) {
    final lower = url.toLowerCase().trim();
    return lower
        .replaceFirst(RegExp(r'^https?:\/\/'), '')
        .replaceFirst(RegExp(r'^(www\.|m\.|web\.)'), '')
        .replaceAll(RegExp(r'\/+$'), '');
  }

  static LinkAnalysisResult analyze(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const LinkAnalysisResult(
        rawInput: '',
        normalizedUrl: null,
        recommendedType: 'link',
        detectedLabel: 'Conteúdo manual',
        recommendationReason: 'Escolhe a categoria onde pretendes guardar.',
        suggestedTitle: '',
        summary: '',
        extractedLinks: <String>[],
        extractedImages: <String>[],
        host: '',
      );
    }

    final allUrls = extractAllUrls(trimmed);

    // O link principal é preferencialmente o do Facebook (ou o primeiro encontrado)
    String? primaryUrl;
    if (allUrls.isNotEmpty) {
      primaryUrl = allUrls.firstWhere(
        (u) =>
            u.toLowerCase().contains('facebook.com') ||
            u.toLowerCase().contains('fb.watch') ||
            u.toLowerCase().contains('fb.com'),
        orElse: () => allUrls.first,
      );
    } else if (!trimmed.contains(' ') && trimmed.contains('.')) {
      primaryUrl =
          trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
    }

    final primaryKey = primaryUrl != null ? _canonicalUrlKey(primaryUrl) : '';
    final secondaryUrls = allUrls
        .where((u) => _canonicalUrlKey(u) != primaryKey)
        .toList();

    final extraImages =
        secondaryUrls.where((u) => isImageUrl(u)).toList();
    final extraLinks =
        secondaryUrls.where((u) => !isImageUrl(u)).toList();

    // Remove os URLs do texto para obter a descrição/legenda limpa
    var cleanText = trimmed;
    for (final m in _urlRegex.allMatches(trimmed)) {
      cleanText = cleanText.replaceAll(m.group(0)!, '');
    }
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (primaryUrl == null) {
      final isShortComment = trimmed.length < 140;
      return LinkAnalysisResult(
        rawInput: trimmed,
        normalizedUrl: null,
        recommendedType: isShortComment ? 'comment' : 'text',
        detectedLabel:
            isShortComment ? 'Comentário / Nota curta' : 'Texto de Publicação',
        recommendationReason: isShortComment
            ? 'Texto curto sem link — recomendado guardar em Comentários.'
            : 'Texto longo sem link — recomendado guardar em Posts.',
        suggestedTitle: trimmed,
        summary: _buildLocalSummary(
          label: isShortComment ? 'Comentário' : 'Publicação em texto',
          cleanText: trimmed,
          extraLinks: extraLinks,
          extraImages: extraImages,
        ),
        extractedLinks: extraLinks,
        extractedImages: extraImages,
        host: 'Texto local',
      );
    }

    final uri = Uri.tryParse(primaryUrl);
    final lowerUrl = primaryUrl.toLowerCase();
    final host = uri?.host.replaceFirst('www.', '').replaceFirst('m.', '') ??
        'facebook.com';

    // 1. Check for Comments
    if (lowerUrl.contains('comment_id=') ||
        lowerUrl.contains('reply_comment_id=')) {
      final title = cleanText.isNotEmpty
          ? cleanText
          : _buildFriendlyTitle(uri, 'Comentário do Facebook');
      return LinkAnalysisResult(
        rawInput: trimmed,
        normalizedUrl: primaryUrl,
        recommendedType: 'comment',
        detectedLabel: 'Comentário do Facebook',
        recommendationReason:
            'O link contém um identificador de comentário (comment_id).',
        suggestedTitle: title,
        summary: _buildLocalSummary(
          label: 'Comentário do Facebook',
          cleanText: cleanText,
          extraLinks: extraLinks,
          extraImages: extraImages,
          uri: uri,
        ),
        extractedLinks: extraLinks,
        extractedImages: extraImages,
        host: host,
      );
    }

    // 2. Check for Videos / Reels / Watch
    if (lowerUrl.contains('/reel/') ||
        lowerUrl.contains('/reels/') ||
        lowerUrl.contains('/videos/') ||
        lowerUrl.contains('/watch') ||
        lowerUrl.contains('fb.watch') ||
        lowerUrl.contains('video.php') ||
        lowerUrl.contains('/share/v/') ||
        lowerUrl.contains('/share/r/') ||
        lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mov')) {
      final isReel =
          lowerUrl.contains('/reel') || lowerUrl.contains('/share/r/');
      final label =
          isReel ? 'Reel / Vídeo do Facebook' : 'Vídeo do Facebook';
      final title = cleanText.isNotEmpty
          ? cleanText
          : _buildFriendlyTitle(uri, label);
      return LinkAnalysisResult(
        rawInput: trimmed,
        normalizedUrl: primaryUrl,
        recommendedType: 'video',
        detectedLabel: label,
        recommendationReason:
            'O endereço corresponde a um formato de vídeo ou Reel do Facebook.',
        suggestedTitle: title,
        summary: _buildLocalSummary(
          label: label,
          cleanText: cleanText,
          extraLinks: extraLinks,
          extraImages: extraImages,
          uri: uri,
        ),
        extractedLinks: extraLinks,
        extractedImages: extraImages,
        host: host,
      );
    }

    // 3. Check for Photos / Images
    if (isImageUrl(primaryUrl)) {
      final title = cleanText.isNotEmpty
          ? cleanText
          : _buildFriendlyTitle(uri, 'Imagem do Facebook');
      return LinkAnalysisResult(
        rawInput: trimmed,
        normalizedUrl: primaryUrl,
        recommendedType: 'image',
        detectedLabel: 'Fotografia / Imagem do Facebook',
        recommendationReason:
            'O link aponta diretamente para uma fotografia ou álbum de imagem.',
        suggestedTitle: title,
        summary: _buildLocalSummary(
          label: 'Fotografia / Imagem do Facebook',
          cleanText: cleanText,
          extraLinks: extraLinks,
          extraImages: extraImages,
          uri: uri,
        ),
        extractedLinks: extraLinks,
        extractedImages: extraImages,
        host: host,
      );
    }

    // 4. Check for Facebook Posts / Groups / Permalinks
    if (lowerUrl.contains('/posts/') ||
        lowerUrl.contains('/permalink') ||
        lowerUrl.contains('story.php') ||
        lowerUrl.contains('/share/p/') ||
        lowerUrl.contains('/groups/')) {
      final isGroup = lowerUrl.contains('/groups/');
      final label = isGroup
          ? 'Publicação de Grupo do Facebook'
          : 'Publicação (Post) do Facebook';
      final title = cleanText.isNotEmpty
          ? cleanText
          : _buildFriendlyTitle(uri, label);
      return LinkAnalysisResult(
        rawInput: trimmed,
        normalizedUrl: primaryUrl,
        recommendedType: 'text',
        detectedLabel: label,
        recommendationReason:
            'Detetada estrutura de publicação ou post do Facebook.',
        suggestedTitle: title,
        summary: _buildLocalSummary(
          label: label,
          cleanText: cleanText,
          extraLinks: extraLinks,
          extraImages: extraImages,
          uri: uri,
        ),
        extractedLinks: extraLinks,
        extractedImages: extraImages,
        host: host,
      );
    }

    // 5. Default to Link
    final isFb = host.contains('facebook.com') || host.contains('fb.com');
    final defaultLabel =
        isFb ? 'Link / Página do Facebook' : 'Link Externo ($host)';
    final title = cleanText.isNotEmpty
        ? cleanText
        : _buildFriendlyTitle(uri, defaultLabel);
    return LinkAnalysisResult(
      rawInput: trimmed,
      normalizedUrl: primaryUrl,
      recommendedType: 'link',
      detectedLabel: defaultLabel,
      recommendationReason:
          'Link geral detetado — recomendado guardar na secção de Links.',
      suggestedTitle: title,
      summary: _buildLocalSummary(
        label: defaultLabel,
        cleanText: cleanText,
        extraLinks: extraLinks,
        extraImages: extraImages,
        uri: uri,
      ),
      extractedLinks: extraLinks,
      extractedImages: extraImages,
      host: host,
    );
  }

  /// Lê os metadados reais do vídeo/post (via API Microlink com suporte CORS)
  /// e devolve um resumo detalhado do vídeo + links para Links + imagens para Imagens.
  static Future<LinkAnalysisResult> fetchAndAnalyze(
    String input, {
    http.Client? client,
  }) async {
    final base = analyze(input);
    final targetUrl = base.normalizedUrl;
    if (targetUrl == null || targetUrl.isEmpty) {
      return base;
    }

    final httpClient = client ?? http.Client();
    try {
      final apiUri = Uri.parse(
        'https://api.microlink.io/?url=${Uri.encodeComponent(targetUrl)}',
      );
      final response = await httpClient
          .get(apiUri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return base;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'success') {
        return base;
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return base;
      }

      final rawTitle = (data['title'] as String?)?.trim() ?? '';
      final rawDesc = (data['description'] as String?)?.trim() ?? '';
      final rawAuthor = (data['author'] as String?)?.trim() ?? '';
      final resolvedUrl = (data['url'] as String?)?.trim() ?? targetUrl;

      // Extrai imagem de capa/miniatura se existir nos metadados (data.image.url)
      String? metadataImageUrl;
      final imageField = data['image'];
      if (imageField is Map<String, dynamic>) {
        final candidate = (imageField['url'] as String?)?.trim();
        if (candidate != null &&
            candidate.isNotEmpty &&
            !_isGenericFacebookIcon(candidate)) {
          metadataImageUrl = candidate;
        }
      } else if (imageField is String &&
          imageField.trim().isNotEmpty &&
          !_isGenericFacebookIcon(imageField.trim())) {
        metadataImageUrl = imageField.trim();
      }

      // Verifica se um link curto (ex: facebook.com/share/...) resolveu para vídeo ou imagem
      final reanalyzedResolved = analyze(resolvedUrl);
      final effectiveType = (base.recommendedType == 'link' &&
              reanalyzedResolved.recommendedType != 'link')
          ? reanalyzedResolved.recommendedType
          : base.recommendedType;
      final effectiveLabel = (base.recommendedType == 'link' &&
              reanalyzedResolved.recommendedType != 'link')
          ? reanalyzedResolved.detectedLabel
          : base.detectedLabel;

      // Extrai métricas, autor e legenda a partir do título do Facebook
      String? metricsPart;
      String? captionFromTitle;
      String? pageOrAuthor = rawAuthor.isNotEmpty ? rawAuthor : null;

      if (rawTitle.isNotEmpty &&
          rawTitle.toLowerCase() != 'facebook' &&
          rawTitle.toLowerCase() != 'log in or sign up to view') {
        final segments = rawTitle
            .split('|')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.toLowerCase() != 'facebook')
            .toList();

        if (segments.isNotEmpty) {
          final firstLower = segments.first.toLowerCase();
          final looksLikeMetrics = firstLower.contains('view') ||
              firstLower.contains('visualiza') ||
              firstLower.contains('reaction') ||
              firstLower.contains('reaç') ||
              firstLower.contains('like') ||
              firstLower.contains('gosto') ||
              firstLower.contains('·');

          if (looksLikeMetrics && segments.length >= 2) {
            metricsPart = segments[0];
            captionFromTitle = segments[1];
            if (segments.length >= 3 && pageOrAuthor == null) {
              pageOrAuthor = segments[2];
            }
          } else {
            captionFromTitle = segments.first;
            if (segments.length >= 2 && pageOrAuthor == null) {
              pageOrAuthor = segments.last;
            }
          }
        }
      }

      final mainDescription =
          rawDesc.isNotEmpty ? rawDesc : (captionFromTitle ?? '');

      // Separa URLs secundários em Links (para aba Links) e Imagens (para aba Imagens)
      final primaryKeys = <String>{
        _canonicalUrlKey(targetUrl),
        _canonicalUrlKey(resolvedUrl),
      };
      final combinedUrls = <String>[
        ...base.extractedLinks,
        ...base.extractedImages,
        ...extractAllUrls(rawDesc),
        ...extractAllUrls(rawTitle),
        if (metadataImageUrl != null && effectiveType != 'image')
          metadataImageUrl,
      ];

      final dedupedExtraLinks = <String>[];
      final dedupedExtraImages = <String>[];
      final seenKeys = <String>{...primaryKeys};

      for (final candidate in combinedUrls) {
        final key = _canonicalUrlKey(candidate);
        if (key == 'facebook.com' || key == 'fb.com') continue;
        if (!seenKeys.add(key)) continue;

        if (candidate == metadataImageUrl || isImageUrl(candidate)) {
          dedupedExtraImages.add(candidate);
        } else {
          dedupedExtraLinks.add(candidate);
        }
      }

      // Constrói o título sugerido
      String bestTitle = captionFromTitle ?? mainDescription;
      if (bestTitle.isEmpty) {
        bestTitle = base.suggestedTitle;
      } else if (bestTitle.length > 90) {
        bestTitle = '${bestTitle.substring(0, 87)}...';
      }

      // Constrói o resumo estruturado em português
      final summaryParts = <String>[];
      if (mainDescription.isNotEmpty) {
        summaryParts.add('• Conteúdo: $mainDescription');
      } else {
        summaryParts.add('• Tipo: $effectiveLabel');
      }
      if (pageOrAuthor != null &&
          pageOrAuthor.isNotEmpty &&
          pageOrAuthor != captionFromTitle) {
        summaryParts.add('• Publicado por: $pageOrAuthor');
      }
      if (metricsPart != null && metricsPart.isNotEmpty) {
        summaryParts.add('• Alcance: $metricsPart');
      }
      if (dedupedExtraLinks.isNotEmpty) {
        summaryParts.add(
          '• Links detetados (${dedupedExtraLinks.length}) → Separador Links',
        );
      }
      if (dedupedExtraImages.isNotEmpty) {
        summaryParts.add(
          '• Imagens detetadas (${dedupedExtraImages.length}) → Separador Imagens',
        );
      }

      final finalSummary = summaryParts.isNotEmpty
          ? summaryParts.join('\n')
          : base.summary;

      return base.copyWith(
        recommendedType: effectiveType,
        detectedLabel: effectiveLabel,
        suggestedTitle: bestTitle,
        summary: finalSummary,
        extractedLinks: dedupedExtraLinks,
        extractedImages: dedupedExtraImages,
        metadataFetched: mainDescription.isNotEmpty ||
            metricsPart != null ||
            metadataImageUrl != null,
      );
    } catch (_) {
      return base;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  static String _buildLocalSummary({
    required String label,
    required String cleanText,
    required List<String> extraLinks,
    required List<String> extraImages,
    Uri? uri,
  }) {
    final parts = <String>[];
    if (cleanText.isNotEmpty) {
      parts.add('• Resumo: $cleanText');
    } else {
      final topic = _extractTopicFromUri(uri);
      if (topic != null) {
        parts.add('• Tipo: $label ($topic)');
      } else {
        parts.add('• Tipo: $label');
      }
    }
    if (extraLinks.isNotEmpty) {
      parts.add(
        '• Links detetados (${extraLinks.length}) → Separador Links',
      );
    }
    if (extraImages.isNotEmpty) {
      parts.add(
        '• Imagens detetadas (${extraImages.length}) → Separador Imagens',
      );
    }
    return parts.join('\n');
  }

  static String? _extractTopicFromUri(Uri? uri) {
    if (uri == null) return null;
    final meaningful = uri.pathSegments
        .where((s) =>
            s.trim().isNotEmpty &&
            s != 'posts' &&
            s != 'videos' &&
            s != 'photos' &&
            s != 'reel' &&
            s != 'reels' &&
            s != 'watch' &&
            s != 'share' &&
            s != 'p' &&
            s != 'v' &&
            s != 'r')
        .toList();
    if (meaningful.isEmpty) return null;
    return meaningful.first;
  }

  static String _buildFriendlyTitle(Uri? uri, String fallbackPrefix) {
    final topic = _extractTopicFromUri(uri);
    if (topic != null && topic.length <= 28) {
      return '$fallbackPrefix • $topic';
    }
    if (uri != null && uri.pathSegments.isEmpty) {
      return '$fallbackPrefix (${uri.host})';
    }
    return fallbackPrefix;
  }
}
