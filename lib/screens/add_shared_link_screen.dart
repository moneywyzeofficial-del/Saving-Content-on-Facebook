// lib/screens/add_shared_link_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/saved_items_repository.dart';

class AddSharedLinkScreen extends StatefulWidget {
  final String initialType;
  final String? initialUrl;
  final String? initialText;

  const AddSharedLinkScreen({
    super.key,
    this.initialType = 'link',
    this.initialUrl,
    this.initialText,
  });

  @override
  State<AddSharedLinkScreen> createState() => _AddSharedLinkScreenState();
}

class _AddSharedLinkScreenState extends State<AddSharedLinkScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _contentController;
  late String _selectedType;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _contentController = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) {
        setState(() {
          if (text.startsWith('http://') ||
              text.startsWith('https://') ||
              text.contains('facebook.com') ||
              text.contains('fb.watch')) {
            _urlController.text = text;
          } else {
            _contentController.text = text;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveItem() async {
    FocusScope.of(context).unfocus();
    var url = _urlController.text.trim();
    final customText = _contentController.text.trim();

    if (url.isEmpty && customText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cola um link ou escreve um texto primeiro.'),
        ),
      );
      return;
    }

    if (url.isNotEmpty &&
        !url.startsWith('http://') &&
        !url.startsWith('https://')) {
      url = 'https://$url';
    }

    setState(() => _loading = true);
    try {
      final displayTitle = customText.isNotEmpty
          ? customText
          : (url.isNotEmpty ? url : 'Conteúdo guardado');

      await SavedItemsRepository.instance.addItem(
        type: _selectedType,
        title: displayTitle,
        content: customText.isNotEmpty ? customText : null,
        url: url.isNotEmpty ? url : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(_selectedType);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar: $e')),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Conteúdo'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _saveItem,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text(
              'GUARDAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Onde queres guardar? (Categoria)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'text', child: Text('Posts / Texto')),
                  DropdownMenuItem(value: 'image', child: Text('Imagens')),
                  DropdownMenuItem(value: 'video', child: Text('Vídeos')),
                  DropdownMenuItem(value: 'link', child: Text('Links')),
                  DropdownMenuItem(
                      value: 'comment', child: Text('Comentários')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      decoration: const InputDecoration(
                        labelText: 'Link / URL do Facebook',
                        hintText: 'https://www.facebook.com/...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _pasteFromClipboard,
                    tooltip: 'Colar',
                    icon: const Icon(Icons.content_paste),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                onSubmitted: (_) => _saveItem(),
                decoration: const InputDecoration(
                  labelText: 'Título, Post ou Comentário',
                  hintText: 'Escreve uma nota ou cola o texto aqui...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _saveItem,
                      icon: const Icon(Icons.bookmark_add),
                      label: const Text(
                        'Guardar Conteúdo',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
