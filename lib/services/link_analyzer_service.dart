// lib/services/link_analyzer_service.dart
class LinkAnalysisResult {
  final String rawInput;
  final String? normalizedUrl;
  final String recommendedType; // 'text', 'image', 'video', 'link', 'comment'
  final String detectedLabel;
  final String recommendationReason;
  final String suggestedTitle;
  final String host;

  const LinkAnalysisResult({
    required this.rawInput,
    required this.normalizedUrl,
    required this.recommendedType,
    required this.detectedLabel,
    required this.recommendationReason,
    required this.suggestedTitle,
    required this.host,
  });
}

class LinkAnalyzerService {
  LinkAnalyzerService._();

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
        host: '',
      );
    }

    // Extract URL if input contains text + URL (common when sharing from Facebook)
    final urlMatch = RegExp(
      r'(https?:\/\/[^\s]+|(?:www\.|m\.|web\.)?facebook\.com\/[^\s]+|fb\.watch\/[^\s]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);

    String? url = urlMatch?.group(0);
    String extraText = trimmed;
    if (url != null) {
      extraText = trimmed.replaceAll(url, '').trim();
      if (!url.toLowerCase().startsWith('http://') &&
          !url.toLowerCase().startsWith('https://')) {
        url = 'https://$url';
      }
    } else if (!trimmed.contains(' ') && trimmed.contains('.')) {
      url = 'https://$trimmed';
      extraText = '';
    }

    if (url == null) {
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
        host: 'Texto local',
      );
    }

    final uri = Uri.tryParse(url);
    final lowerUrl = url.toLowerCase();
    final host = uri?.host.replaceFirst('www.', '').replaceFirst('m.', '') ??
        'facebook.com';

    // 1. Check for Comments
    if (lowerUrl.contains('comment_id=') ||
        lowerUrl.contains('reply_comment_id=')) {
      return LinkAnalysisResult(
        rawInput: trimmed,
        normalizedUrl: url,
        recommendedType: 'comment',
        detectedLabel: 'Comentário do Facebook',
        recommendationReason:
            'O link contém um identificador de comentário (comment_id).',
        suggestedTitle: extraText.isNotEmpty
            ? extraText
            : _buildFriendlyTitle(uri, 'Comentário do Facebook'),
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
      return LinkAnalysisResult(
        rawInput: trimmed,
        normalizedUrl: url,
        recommendedType: 'video',
        detectedLabel: label,
        recommendationReason:
            'O endereço corresponde a um formato de vídeo ou Reel do Facebook.',
        suggestedTitle:
            extraText.isNotEmpty ? extraText : _buildFriendlyTitle(uri, label),
        host: host,
      );
    }

    // 3. Check for Photos / Images
    if (lowerUrl.contains('/photo') ||
        lowerUrl.contains('/photos/') ||
        lowerUrl.contains('fbid=') ||
        lowerUrl.contains('scontent') ||
        lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.webp')) {
      return LinkAnalysisResult(
        rawInput: trimmed,
        normalizedUrl: url,
        recommendedType: 'image',
        detectedLabel: 'Fotografia / Imagem do Facebook',
        recommendationReason:
            'O link aponta diretamente para uma fotografia ou álbum de imagem.',
        suggestedTitle: extraText.isNotEmpty
            ? extraText
            : _buildFriendlyTitle(uri, 'Imagem do Facebook'),
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
      return LinkAnalysisResult(
        rawInput: trimmed,
        normalizedUrl: url,
        recommendedType: 'text',
        detectedLabel: label,
        recommendationReason:
            'Detetada estrutura de publicação ou post do Facebook.',
        suggestedTitle:
            extraText.isNotEmpty ? extraText : _buildFriendlyTitle(uri, label),
        host: host,
      );
    }

    // 5. Default to Link
    final isFb = host.contains('facebook.com') || host.contains('fb.com');
    final defaultLabel =
        isFb ? 'Link / Página do Facebook' : 'Link Externo ($host)';
    return LinkAnalysisResult(
      rawInput: trimmed,
      normalizedUrl: url,
      recommendedType: 'link',
      detectedLabel: defaultLabel,
      recommendationReason:
          'Link geral detetado — recomendado guardar na secção de Links.',
      suggestedTitle: extraText.isNotEmpty
          ? extraText
          : _buildFriendlyTitle(uri, defaultLabel),
      host: host,
    );
  }

  static String _buildFriendlyTitle(Uri? uri, String fallbackPrefix) {
    if (uri == null) return fallbackPrefix;
    final segments =
        uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    if (segments.isEmpty) return '$fallbackPrefix (${uri.host})';
    final meaningful = segments
        .where((s) =>
            s != 'posts' &&
            s != 'videos' &&
            s != 'photos' &&
            s != 'reel' &&
            s != 'share' &&
            s != 'p' &&
            s != 'v' &&
            s != 'r')
        .toList();
    if (meaningful.isNotEmpty) {
      final first = meaningful.first;
      if (first.length <= 28) {
        return '$fallbackPrefix • $first';
      }
    }
    return fallbackPrefix;
  }
}
