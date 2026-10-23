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
  final TextEditingController _quickPasteController = TextEditingController();
  int _selectedIndex = 0;
  bool _isOpeningReview = false;
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

  @override
  void dispose() {
    _quickPasteController.dispose();
    super.dispose();
  }

  Future<void> _openReviewScreen(String inputText, {String? fallbackType}) async {
    if (_isOpeningReview) return;
    _isOpeningReview = true;
    try {
      final savedType = await _navigatorKey.currentState?.push<String>(
        MaterialPageRoute(
          builder: (_) => AddSharedLinkScreen(
            initialInput: inputText,
            fallbackType: fallbackType ?? _categories[_selectedIndex].type,
          ),
        ),
      );

      if (savedType != null && mounted) {
        _quickPasteController.clear();
        final newIndex = _categories.indexWhere((c) => c.type == savedType);
        if (newIndex != -1) {
          setState(() => _selectedIndex = newIndex);
        }
        final ctx = _navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          final targetTitle = _categories
              .firstWhere((c) => c.type == savedType,
                  orElse: () => _categories.first)
              .title;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('Guardado com sucesso em $targetTitle!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } finally {
      _isOpeningReview = false;
    }
  }

  Future<void> _pasteFromClipboardAndAnalyze() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final clipText = data?.text?.trim() ?? '';
      if (clipText.isNotEmpty) {
        _quickPasteController.text = clipText;
        await _openReviewScreen(clipText);
        return;
      }
    } catch (_) {}

    // If clipboard access is blocked by iOS Safari permissions, use field text or open screen
    final currentText = _quickPasteController.text.trim();
    if (currentText.isNotEmpty) {
      await _openReviewScreen(currentText);
    } else {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text(
              'Toca no campo acima, escolhe "Colar" e toca em Analisar.',
            ),
          ),
        );
      }
    }
  }

  void _onQuickFieldChanged(String value) {
    final trimmed = value.trim();
    // When the user pastes a full URL into the main screen field, automatically open the review page!
    if (trimmed.length > 10 &&
        (trimmed.startsWith('http://') ||
            trimmed.startsWith('https://') ||
            trimmed.contains('facebook.com/') ||
            trimmed.contains('fb.watch/'))) {
      FocusManager.instance.primaryFocus?.unfocus();
      _openReviewScreen(trimmed);
    }
  }

  void _checkWebShareQueryParams() {
    final params = Uri.base.queryParameters;
    final sharedUrl = params['url'] ?? params['link'];
    final sharedText = params['text'] ?? params['title'];
    final combined = [sharedUrl, sharedText]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' ');
    if (combined.isNotEmpty) {
      _openReviewScreen(combined);
    }
  }

  void _listenForShareIntent() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final Map args = call.arguments as Map;
        final shared = (args['url'] ?? args['text'] ?? '').toString();
        if (shared.isNotEmpty) {
          await _openReviewScreen(shared);
        }
      }
    });
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
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: currentCategory.color,
          elevation: 0,
          title: Text('FB Save • ${currentCategory.title}'),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra Principal para Colar Link e Analisar
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Cola aqui o link do Facebook para analisar e guardar:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quickPasteController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.go,
                            onChanged: _onQuickFieldChanged,
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                _openReviewScreen(val.trim());
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Colar link (Post, Vídeo, Foto...)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              prefixIcon: Icon(
                                Icons.paste_rounded,
                                color: currentCategory.color,
                              ),
                              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _quickPasteController,
                                builder: (_, value, __) {
                                  if (value.text.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: _quickPasteController.clear,
                                  );
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentCategory.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            final txt = _quickPasteController.text.trim();
                            if (txt.isNotEmpty) {
                              _openReviewScreen(txt);
                            } else {
                              _pasteFromClipboardAndAnalyze();
                            }
                          },
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text(
                            'Analisar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Lista da Categoria Selecionada
              Expanded(
                child: SavedItemsScreen(
                  key: ValueKey<String>(currentCategory.type),
                  type: currentCategory.type,
                  title: currentCategory.title,
                  categoryIcon: currentCategory.icon,
                  accentColor: currentCategory.color,
                  onAddPressed: () => _openReviewScreen(
                    _quickPasteController.text.trim(),
                    fallbackType: currentCategory.type,
                  ),
                ),
              ),
            ],
          ),
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
