// lib/models/saved_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedItem {
  final String id;
  final String type; // 'text', 'image', 'video', 'link', 'comment'
  final String? title;
  final String? content; // for text/comments/description
  final String? url; // for images, videos, links
  final Timestamp createdAt;

  SavedItem({
    required this.id,
    required this.type,
    this.title,
    this.content,
    this.url,
    required this.createdAt,
  });

  factory SavedItem.fromMap(Map<String, dynamic> map, String docId) {
    final rawCreatedAt = map['createdAt'];
    return SavedItem(
      id: docId,
      type: (map['type'] as String?) ?? 'link',
      title: map['title'] as String?,
      content: (map['content'] ?? map['description']) as String?,
      url: (map['url'] ?? map['originalUrl'] ?? map['imageUrl'] ?? map['videoUrl']) as String?,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (url != null) 'url': url,
      'createdAt': createdAt,
    };
  }
}
