// lib/services/saved_items_repository.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_item.dart';

class SavedItemsRepository extends ChangeNotifier {
  SavedItemsRepository._();
  static final SavedItemsRepository instance = SavedItemsRepository._();

  static const String _storageKey = 'fb_saved_items_v1';
  List<SavedItem> _items = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadLocal();
  }

  List<SavedItem> itemsByType(String type) {
    final list = _items.where((i) => i.type == type).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int countByType(String type) {
    return _items.where((i) => i.type == type).length;
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        _items = decoded.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          final ms = map['createdAtMs'] as int? ??
              DateTime.now().millisecondsSinceEpoch;
          map['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(ms);
          return SavedItem.fromMap(map, map['id'] as String? ?? '');
        }).toList();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_items.map((item) {
        return {
          'id': item.id,
          'type': item.type,
          if (item.title != null) 'title': item.title,
          if (item.content != null) 'content': item.content,
          if (item.url != null) 'url': item.url,
          'createdAtMs': item.createdAt.millisecondsSinceEpoch,
        };
      }).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<void> addItem({
    required String type,
    String? title,
    String? content,
    String? url,
    String owner = 'anonymous',
  }) async {
    await init();
    final id = 'item_${DateTime.now().millisecondsSinceEpoch}';
    final now = Timestamp.now();
    final newItem = SavedItem(
      id: id,
      type: type,
      title: title,
      content: content,
      url: url,
      createdAt: now,
    );

    _items.insert(0, newItem);
    notifyListeners();
    await _saveLocal();
  }

  Future<void> deleteItem(String id) async {
    await init();
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    await _saveLocal();
  }
}
