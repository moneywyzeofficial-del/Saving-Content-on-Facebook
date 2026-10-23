import 'package:flutter_test/flutter_test.dart';
import 'package:facebook_save_app/models/saved_item.dart';
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
}
