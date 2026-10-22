// lib/models/saved_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedItem {
  final String id;
  final String type; // 'text', 'image', 'video', 'link', 'comment'
  final String? content; // for text/comments
  final String? url; // for images, videos, links
  final Timestamp createdAt;

  SavedItem({
    required this.id,
    required this.type,
    this.content,
    this.url,
    required this.createdAt,
  });

  factory SavedItem.fromMap(Map<String, dynamic> map, String docId) {
    return SavedItem(
      id: docId,
      type: map['type'] as String,
      content: map['content'] as String?,
      url: map['url'] as String?,
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (content != null) 'content': content,
      if (url != null) 'url': url,
      'createdAt': createdAt,
    };
  }
}
