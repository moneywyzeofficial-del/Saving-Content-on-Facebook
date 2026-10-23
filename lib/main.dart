// lib/main.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/saved_items_repository.dart';
import 'screens/saved_items_screen.dart';
import 'screens/add_shared_link_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SavedItemsRepository.instance.init();
  runApp(const FacebookSaveApp());
}

class FacebookSaveApp extends StatefulWidget {
  const FacebookSaveApp({super.key});

  @override
  State<FacebookSaveApp> createState() => _FacebookSaveAppState();
}

class _CategorySpec {
  final String type;
  final String title;
  final IconData icon;
  final Color color;

  const _CategorySpec({
    required this.type,
    required this.title,
    required this.icon,
    required this.color,
  });
}

class _FacebookSaveAppState extends State<FacebookSaveApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _selectedIndex = 0;
  static const platform = MethodChannel('com.example.facebook_save/share');

  static const List<_CategorySpec> _categories = <_CategorySpec>[
    _CategorySpec(
      type: 'text',
      title: 'Posts',
      icon: Icons.article,
      color: Color(0xFF3F51B5),
    ),
    _CategorySpec(
      type: 'image',
      title: 'Imagens',
      icon: Icons.image,
      color: Color(0xFF00897B),
    ),
    _CategorySpec(
      type: 'video',
      title: 'Vídeos',
      icon: Icons.videocam,
      color: Color(0xFFE53935),
    ),
    _CategorySpec(
      type: 'link',
      title: 'Links',
      icon: Icons.link,
      color: Color(0xFF1E88E5),
    ),
    _CategorySpec(
      type: 'comment',
      title: 'Comentários',
      icon: Icons.comment,
      color: Color(0xFF8E24AA),
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _listenForShareIntent();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkWebShareQueryParams();
      });
    }
  }

  Future<void> _openAddScreen({
    String? initialType,
    String? initialUrl,
    String? initialText,
  }) async {
    final targetType = initialType ?? _categories[_selectedIndex].type;
    final savedType = await _navigatorKey.currentState?.push<String>(
      MaterialPageRoute(
        builder: (_) => AddSharedLinkScreen(
          initialType: targetType,
          initialUrl: initialUrl,
          initialText: initialText,
        ),
      ),
    );

    if (savedType != null && mounted) {
      final newIndex = _categories.indexWhere((c) => c.type == savedType);
      if (newIndex != -1) {
        setState(() => _selectedIndex = newIndex);
      }
      final ctx = _navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Conteúdo guardado com sucesso!')),
        );
      }
    }
  }

  void _checkWebShareQueryParams() {
    final params = Uri.base.queryParameters;
    final sharedUrl = params['url'] ?? params['link'];
    final sharedText = params['text'] ?? params['title'];
    if ((sharedUrl != null && sharedUrl.isNotEmpty) ||
        (sharedText != null && sharedText.isNotEmpty)) {
      _openAddScreen(
        initialType: sharedUrl != null ? 'link' : 'text',
        initialUrl: sharedUrl,
        initialText: sharedText,
      );
    }
  }

  void _listenForShareIntent() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final Map args = call.arguments as Map;
        await _handleSharedData(args);
      }
    });
  }

  Future<void> _handleSharedData(Map data) async {
    if (data.containsKey('text')) {
      await SavedItemsRepository.instance.addItem(
        type: 'text',
        title: data['text']?.toString(),
        content: data['text']?.toString(),
      );
    }
    if (data.containsKey('url')) {
      await SavedItemsRepository.instance.addItem(
        type: 'link',
        title: data['url']?.toString(),
        url: data['url']?.toString(),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentCategory = _categories[_selectedIndex];

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Facebook Save Content',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: false,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: currentCategory.color,
          title: Text('FB Save • ${currentCategory.title}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Guardar Conteúdo',
              onPressed: () => _openAddScreen(initialType: currentCategory.type),
            ),
          ],
        ),
        body: SafeArea(
          child: SavedItemsScreen(
            key: ValueKey<String>(currentCategory.type),
            type: currentCategory.type,
            title: currentCategory.title,
            categoryIcon: currentCategory.icon,
            accentColor: currentCategory.color,
            onAddPressed: () =>
                _openAddScreen(initialType: currentCategory.type),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: currentCategory.color,
          icon: const Icon(Icons.add),
          label: const Text('Guardar'),
          onPressed: () => _openAddScreen(initialType: currentCategory.type),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: currentCategory.color,
          unselectedItemColor: Colors.grey.shade600,
          onTap: _onItemTapped,
          items: _categories
              .map(
                (c) => BottomNavigationBarItem(
                  icon: Icon(c.icon),
                  label: c.title,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
