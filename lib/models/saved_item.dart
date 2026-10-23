// lib/models/saved_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedItem {
  final String id;
  final String type; // 'text', 'image', 'video', 'link', 'comment'
  final String? title;
  final String? content; // for text/comments/description
  final String? summary; // resumo automático ou personalizado do vídeo/post
  final String? url; // for images, videos, links
  final List<String> extractedLinks; // links extraídos e guardados em Links
  final List<String> extractedImages; // imagens extraídas e guardadas em Imagens
  final Timestamp createdAt;

  SavedItem({
    required this.id,
    required this.type,
    this.title,
    this.content,
    this.summary,
    this.url,
    this.extractedLinks = const <String>[],
    this.extractedImages = const <String>[],
    required this.createdAt,
  });

  factory SavedItem.fromMap(Map<String, dynamic> map, String docId) {
    final rawCreatedAt = map['createdAt'];
    final rawLinks = map['extractedLinks'];
    final parsedLinks = rawLinks is List
        ? rawLinks.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];
    final rawImages = map['extractedImages'];
    final parsedImages = rawImages is List
        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];

    return SavedItem(
      id: docId,
      type: (map['type'] as String?) ?? 'link',
      title: map['title'] as String?,
      content: (map['content'] ?? map['description']) as String?,
      summary: map['summary'] as String?,
      url: (map['url'] ??
              map['originalUrl'] ??
              map['imageUrl'] ??
              map['videoUrl']) as String?,
      extractedLinks: parsedLinks,
      extractedImages: parsedImages,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (summary != null) 'summary': summary,
      if (url != null) 'url': url,
      if (extractedLinks.isNotEmpty) 'extractedLinks': extractedLinks,
      if (extractedImages.isNotEmpty) 'extractedImages': extractedImages,
      'createdAt': createdAt,
    };
  }
}
