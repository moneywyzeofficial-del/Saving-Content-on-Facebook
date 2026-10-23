import 'package:flutter_test/flutter_test.dart';
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
}
