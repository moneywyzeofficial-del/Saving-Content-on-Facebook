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
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final TextEditingController _quickPasteController = TextEditingController();
  // 0 = Página Principal (Início / Colar Link), 1..5 = Categorias
  int _selectedIndex = 0;
  // Quando diferente de null, mostra o corpo de Revisão e Confirmação dentro do mesmo Scaffold
  String? _reviewingInput;
  String? _reviewFallbackType;
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

  void _showMessage(String message, {Color? bgColor}) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _openReviewScreen(String inputText, {String? fallbackType}) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _reviewingInput = inputText;
      _reviewFallbackType = fallbackType;
    });
  }

  void _handleSaved(String savedType) {
    _quickPasteController.clear();
    final catIndex = _categories.indexWhere((c) => c.type == savedType);
    final targetTitle = _categories
        .firstWhere(
          (c) => c.type == savedType,
          orElse: () => _categories.first,
        )
        .title;

    setState(() {
      _reviewingInput = null;
      _reviewFallbackType = null;
      if (catIndex != -1) {
        _selectedIndex = catIndex + 1;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMessage(
        'Guardado com sucesso em $targetTitle!',
        bgColor: Colors.green.shade700,
      );
    });
  }

  void _handleCancelReview() {
    setState(() {
      _reviewingInput = null;
      _reviewFallbackType = null;
    });
  }

  void _selectTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _reviewingInput = null;
      _reviewFallbackType = null;
      _selectedIndex = index;
    });
  }

  Future<void> _pasteFromClipboardAndAnalyze() async {
    final existing = _quickPasteController.text.trim();
    if (existing.isNotEmpty) {
      _openReviewScreen(existing);
      return;
    }
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final clipText = data?.text?.trim() ?? '';
      if (clipText.isNotEmpty) {
        _quickPasteController.text = clipText;
        _openReviewScreen(clipText);
        return;
      }
    } catch (_) {}

    _showMessage('Cola primeiro o link no campo de texto acima.');
  }

  void _onQuickFieldChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.length > 8 &&
        (trimmed.startsWith('http://') ||
            trimmed.startsWith('https://') ||
            trimmed.contains('facebook.com/') ||
            trimmed.contains('fb.watch/') ||
            trimmed.contains('fb.com/'))) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted && _reviewingInput == null) {
          _openReviewScreen(trimmed);
        }
      });
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
          _openReviewScreen(shared);
        }
      }
    });
  }

  // Barra superior de separadores (sempre visível no ecrã sem esconder abas)
  Widget _buildTopTabsStrip(Color activeColor) {
    return ListenableBuilder(
      listenable: SavedItemsRepository.instance,
      builder: (context, _) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTabPill(
                index: 0,
                label: 'Início',
                icon: Icons.home_filled,
                color: const Color(0xFF1877F2),
              ),
              ...List.generate(_categories.length, (i) {
                final cat = _categories[i];
                final count =
                    SavedItemsRepository.instance.countByType(cat.type);
                return _buildTabPill(
                  index: i + 1,
                  label: count > 0 ? '${cat.title} ($count)' : cat.title,
                  icon: cat.icon,
                  color: cat.color,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabPill({
    required int index,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedIndex == index && _reviewingInput == null;
    return ElevatedButton.icon(
      key: ValueKey<String>('top_tab_$index'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey.shade100,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? color : Colors.grey.shade300,
          ),
        ),
      ),
      onPressed: () => _selectTab(index),
      icon: Icon(
        icon,
        size: 17,
        color: isSelected ? Colors.white : color,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHomePasteScreen() {
    return ListenableBuilder(
      listenable: SavedItemsRepository.instance,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cartão Principal para Colar Link
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                const Color(0xFF1877F2).withOpacity(0.12),
                            child: const Icon(
                              Icons.add_link,
                              color: Color(0xFF1877F2),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Guardar do Facebook',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Cola o link abaixo para detetar e escolher onde guardar',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
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
                          labelText: 'Cola aqui o link do Facebook',
                          hintText: 'https://www.facebook.com/...',
                          filled: true,
                          fillColor: const Color(0xFFF5F7FB),
                          prefixIcon: const Icon(
                            Icons.link,
                            color: Color(0xFF1877F2),
                          ),
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _quickPasteController,
                            builder: (_, value, __) {
                              if (value.text.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _quickPasteController.clear,
                              );
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _pasteFromClipboardAndAnalyze,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text(
                          'Analisar Link e Escolher Pasta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'As tuas pastas guardadas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(_categories.length, (i) {
                final cat = _categories[i];
                final count =
                    SavedItemsRepository.instance.countByType(cat.type);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      key: ValueKey<String>('folder_card_${cat.type}'),
                      onTap: () => _selectTab(i + 1),
                      leading: CircleAvatar(
                        backgroundColor: cat.color.withOpacity(0.12),
                        child: Icon(cat.icon, color: cat.color),
                      ),
                      title: Text(
                        cat.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        count == 0
                            ? 'Nenhum item guardado'
                            : '$count ${count == 1 ? "item guardado" : "itens guardados"}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _selectedIndex == 0;
    final currentCategory = isHome ? null : _categories[_selectedIndex - 1];
    final activeColor =
        isHome ? const Color(0xFF1877F2) : currentCategory!.color;

    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Facebook Save Content',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: false,
      ),
      home: _reviewingInput != null
          ? AddSharedLinkScreen(
              key: ValueKey<String>('review_${_reviewingInput!}'),
              initialInput: _reviewingInput!,
              fallbackType: _reviewFallbackType,
              onSaved: _handleSaved,
              onCancel: _handleCancelReview,
            )
          : Scaffold(
              backgroundColor: const Color(0xFFF8F9FA),
              appBar: AppBar(
                backgroundColor: activeColor,
                elevation: 0,
                leading: isHome
                    ? null
                    : IconButton(
                        key: const ValueKey<String>('appbar_back_home'),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Voltar ao Início',
                        onPressed: () => _selectTab(0),
                      ),
                title: Text(
                  isHome
                      ? 'FB Save • Início'
                      : 'FB Save • ${currentCategory!.title}',
                ),
                actions: [
                  if (!isHome)
                    TextButton.icon(
                      onPressed: () => _selectTab(0),
                      icon: const Icon(Icons.add_link, color: Colors.white),
                      label: const Text(
                        'COLAR LINK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopTabsStrip(activeColor),
                  const Divider(height: 1),
                  Expanded(
                    child: isHome
                        ? _buildHomePasteScreen()
                        : SavedItemsScreen(
                            key: ValueKey<String>(currentCategory!.type),
                            type: currentCategory.type,
                            title: currentCategory.title,
                            categoryIcon: currentCategory.icon,
                            accentColor: currentCategory.color,
                            onBackToHome: () => _selectTab(0),
                            onOpenCategoryType: (targetType) {
                              final idx = _categories.indexWhere(
                                (c) => c.type == targetType,
                              );
                              if (idx != -1) {
                                _selectTab(idx + 1);
                              }
                            },
                            onShowMessage: (msg) => _showMessage(msg),
                            onAddPressed: () => _openReviewScreen(
                              '',
                              fallbackType: currentCategory.type,
                            ),
                          ),
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  selectedItemColor: activeColor,
                  unselectedItemColor: Colors.grey.shade600,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  onTap: _selectTab,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.home_filled),
                      label: 'Início',
                    ),
                    ..._categories.map(
                      (c) => BottomNavigationBarItem(
                        icon: Icon(c.icon),
                        label: c.title,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
