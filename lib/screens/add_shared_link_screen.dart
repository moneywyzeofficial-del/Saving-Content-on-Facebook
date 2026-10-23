// lib/screens/add_shared_link_screen.dart
import 'package:flutter/material.dart';
import '../services/link_analyzer_service.dart';
import '../services/saved_items_repository.dart';

class AddSharedLinkScreen extends StatefulWidget {
  final String initialInput;
  final String? fallbackType;
  final ValueChanged<String>? onSaved;
  final VoidCallback? onCancel;

  const AddSharedLinkScreen({
    super.key,
    required this.initialInput,
    this.fallbackType,
    this.onSaved,
    this.onCancel,
  });

  @override
  State<AddSharedLinkScreen> createState() => _AddSharedLinkScreenState();
}

class _CategoryOption {
  final String type;
  final String title;
  final IconData icon;
  final Color color;

  const _CategoryOption({
    required this.type,
    required this.title,
    required this.icon,
    required this.color,
  });
}

class _AddSharedLinkScreenState extends State<AddSharedLinkScreen> {
  static const List<_CategoryOption> _options = <_CategoryOption>[
    _CategoryOption(
      type: 'text',
      title: 'Posts',
      icon: Icons.article,
      color: Color(0xFF3F51B5),
    ),
    _CategoryOption(
      type: 'image',
      title: 'Imagens',
      icon: Icons.image,
      color: Color(0xFF00897B),
    ),
    _CategoryOption(
      type: 'video',
      title: 'Vídeos',
      icon: Icons.videocam,
      color: Color(0xFFE53935),
    ),
    _CategoryOption(
      type: 'link',
      title: 'Links',
      icon: Icons.link,
      color: Color(0xFF1E88E5),
    ),
    _CategoryOption(
      type: 'comment',
      title: 'Comentários',
      icon: Icons.comment,
      color: Color(0xFF8E24AA),
    ),
  ];

  late LinkAnalysisResult _analysis;
  late String _selectedType;
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _analysis = LinkAnalyzerService.analyze(widget.initialInput);
    _selectedType = widget.initialInput.trim().isNotEmpty
        ? _analysis.recommendedType
        : (widget.fallbackType ?? _analysis.recommendedType);
    _urlController = TextEditingController(
      text: _analysis.normalizedUrl ?? widget.initialInput.trim(),
    );
    _titleController = TextEditingController(
      text: _analysis.suggestedTitle,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _reanalyzeUrl(String value) {
    final updated = LinkAnalyzerService.analyze(value);
    setState(() {
      _analysis = updated;
      _selectedType = updated.recommendedType;
      if (_titleController.text.trim().isEmpty ||
          _titleController.text == _analysis.suggestedTitle) {
        _titleController.text = updated.suggestedTitle;
      }
    });
  }

  _CategoryOption _optionFor(String type) {
    return _options.firstWhere(
      (o) => o.type == type,
      orElse: () => _options.first,
    );
  }

  void _confirmAndSave() {
    FocusManager.instance.primaryFocus?.unfocus();
    var rawUrl = _urlController.text.trim();
    final customTitle = _titleController.text.trim();

    if (rawUrl.isEmpty && customTitle.isEmpty) {
      rawUrl = widget.initialInput.trim();
    }

    String? finalUrl;
    if (rawUrl.isNotEmpty) {
      if (!rawUrl.startsWith('http://') &&
          !rawUrl.startsWith('https://') &&
          rawUrl.contains('.')) {
        rawUrl = 'https://$rawUrl';
      }
      if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
        finalUrl = rawUrl;
      }
    }

    final displayTitle = customTitle.isNotEmpty
        ? customTitle
        : (_analysis.suggestedTitle.isNotEmpty
            ? _analysis.suggestedTitle
            : (rawUrl.isNotEmpty ? rawUrl : 'Conteúdo guardado'));

    SavedItemsRepository.instance.addItemSync(
      type: _selectedType,
      title: displayTitle,
      content: customTitle.isNotEmpty ? customTitle : _analysis.detectedLabel,
      url: finalUrl,
    );

    if (widget.onSaved != null) {
      widget.onSaved!(_selectedType);
    } else if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(_selectedType);
    }
  }

  void _handleCancel() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendedOption = _optionFor(_analysis.recommendedType);
    final selectedOption = _optionFor(_selectedType);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: selectedOption.color,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: _handleCancel,
        ),
        title: const Text('Confirmar e Guardar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: selectedOption.color,
                elevation: 0,
              ),
              onPressed: _confirmAndSave,
              icon: const Icon(Icons.check, size: 18),
              label: const Text(
                'GUARDAR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedOption.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _confirmAndSave,
              icon: const Icon(Icons.check_circle, size: 22),
              label: Text(
                'Confirmar e Guardar em ${selectedOption.title}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cartão de Informação Detetada
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: recommendedOption.color.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                recommendedOption.color.withOpacity(0.15),
                            child: Icon(
                              recommendedOption.icon,
                              color: recommendedOption.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: recommendedOption.color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'RECOMENDADO: ${recommendedOption.title.toUpperCase()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _analysis.detectedLabel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _analysis.recommendationReason,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      if (_analysis.normalizedUrl != null) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.link,
                                size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _analysis.normalizedUrl!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Escolha da Categoria
              const Text(
                'Escolhe ou confirma onde guardar:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _options.map((option) {
                  final isSelected = _selectedType == option.type;
                  final isRecommended =
                      _analysis.recommendedType == option.type;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedType = option.type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? option.color : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? option.color
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            option.icon,
                            size: 20,
                            color: isSelected ? Colors.white : option.color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            option.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.auto_awesome,
                              size: 15,
                              color: isSelected
                                  ? Colors.amberAccent
                                  : option.color,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // 3. Título / Descrição editável (sem onTapOutside para não bloquear toques no iOS)
              TextField(
                controller: _titleController,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Título ou Nota (opcional)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Link editável
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                onChanged: _reanalyzeUrl,
                decoration: const InputDecoration(
                  labelText: 'Link colado',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
