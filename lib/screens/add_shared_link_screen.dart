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
  late final TextEditingController _summaryController;
  late final TextEditingController _extraLinkController;
  late final TextEditingController _extraImageController;

  List<String> _extractedLinks = <String>[];
  List<String> _extractedImages = <String>[];
  bool _saveExtraLinksSeparately = true;
  bool _saveExtraImagesSeparately = true;
  bool _isFetchingMetadata = false;

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
    _summaryController = TextEditingController(
      text: _analysis.summary,
    );
    _extraLinkController = TextEditingController();
    _extraImageController = TextEditingController();
    _extractedLinks = List<String>.from(_analysis.extractedLinks);
    _extractedImages = List<String>.from(_analysis.extractedImages);

    if (widget.initialInput.trim().isNotEmpty &&
        _analysis.normalizedUrl != null) {
      _loadRemoteVideoAndPostInfo(widget.initialInput);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _extraLinkController.dispose();
    _extraImageController.dispose();
    super.dispose();
  }

  Future<void> _loadRemoteVideoAndPostInfo(String input) async {
    setState(() {
      _isFetchingMetadata = true;
    });

    final oldSuggestedTitle = _analysis.suggestedTitle;
    final oldSummary = _analysis.summary;
    final enriched = await LinkAnalyzerService.fetchAndAnalyze(input);

    if (!mounted) return;
    setState(() {
      _isFetchingMetadata = false;
      _analysis = enriched;
      _selectedType = enriched.recommendedType;

      if (_titleController.text.trim().isEmpty ||
          _titleController.text == oldSuggestedTitle) {
        _titleController.text = enriched.suggestedTitle;
      }
      if (_summaryController.text.trim().isEmpty ||
          _summaryController.text == oldSummary) {
        _summaryController.text = enriched.summary;
      }

      for (final link in enriched.extractedLinks) {
        if (!_extractedLinks.contains(link)) {
          _extractedLinks.add(link);
        }
      }
      for (final img in enriched.extractedImages) {
        if (!_extractedImages.contains(img)) {
          _extractedImages.add(img);
        }
      }
    });
  }

  void _reanalyzeUrl(String value) {
    final oldSuggestedTitle = _analysis.suggestedTitle;
    final oldSummary = _analysis.summary;
    final updated = LinkAnalyzerService.analyze(value);
    setState(() {
      _analysis = updated;
      _selectedType = updated.recommendedType;
      if (_titleController.text.trim().isEmpty ||
          _titleController.text == oldSuggestedTitle) {
        _titleController.text = updated.suggestedTitle;
      }
      if (_summaryController.text.trim().isEmpty ||
          _summaryController.text == oldSummary) {
        _summaryController.text = updated.summary;
      }
      _extractedLinks = List<String>.from(updated.extractedLinks);
      _extractedImages = List<String>.from(updated.extractedImages);
    });
  }

  void _addManualExtraLink() {
    var raw = _extraLinkController.text.trim();
    if (raw.isEmpty) return;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    setState(() {
      if (!_extractedLinks.contains(raw)) {
        _extractedLinks.add(raw);
      }
      _extraLinkController.clear();
    });
  }

  void _addManualExtraImage() {
    var raw = _extraImageController.text.trim();
    if (raw.isEmpty) return;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    setState(() {
      if (!_extractedImages.contains(raw)) {
        _extractedImages.add(raw);
      }
      _extraImageController.clear();
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

    // Se o utilizador escreveu algum link ou imagem extra nos campos auxiliares sem carregar no "+", adiciona-os já
    if (_extraLinkController.text.trim().isNotEmpty) {
      _addManualExtraLink();
    }
    if (_extraImageController.text.trim().isNotEmpty) {
      _addManualExtraImage();
    }

    var rawUrl = _urlController.text.trim();
    final customTitle = _titleController.text.trim();
    final customSummary = _summaryController.text.trim();

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

    final finalSummary =
        customSummary.isNotEmpty ? customSummary : _analysis.summary;

    final linksToSave = _saveExtraLinksSeparately
        ? List<String>.from(_extractedLinks)
        : const <String>[];
    final imagesToSave = _saveExtraImagesSeparately
        ? List<String>.from(_extractedImages)
        : const <String>[];

    // 1. Guarda o item principal (ex.: Vídeo na aba Vídeos com o respetivo Resumo)
    SavedItemsRepository.instance.addItemSync(
      type: _selectedType,
      title: displayTitle,
      content: customTitle.isNotEmpty ? customTitle : _analysis.detectedLabel,
      summary: finalSummary.isNotEmpty ? finalSummary : null,
      url: finalUrl,
      extractedLinks: linksToSave,
      extractedImages: imagesToSave,
    );

    // 2. Caso tenha links secundários, guarda cada um automaticamente no separador Links
    if (_saveExtraLinksSeparately && linksToSave.isNotEmpty) {
      for (final extraUrl in linksToSave) {
        SavedItemsRepository.instance.addItemSync(
          type: 'link',
          title: 'Link de: $displayTitle',
          content: extraUrl,
          summary: 'Extraído automaticamente de "$displayTitle".',
          url: extraUrl,
        );
      }
    }

    // 3. Caso tenha imagens secundárias / miniatura, guarda cada uma automaticamente no separador Imagens
    if (_saveExtraImagesSeparately && imagesToSave.isNotEmpty) {
      for (final imgUrl in imagesToSave) {
        SavedItemsRepository.instance.addItemSync(
          type: 'image',
          title: 'Imagem de: $displayTitle',
          content: imgUrl,
          summary: 'Imagem extraída automaticamente de "$displayTitle".',
          url: imgUrl,
        );
      }
    }

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
                      if (_isFetchingMetadata) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Color(0xFF1877F2),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A ler informação do vídeo, resumo, links e imagens...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1877F2),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
              const SizedBox(height: 16),

              // 2. Cartão de Resumo do Vídeo / Conteúdo
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.summarize_outlined,
                            color: selectedOption.color,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Resumo do Vídeo / Conteúdo',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_analysis.metadataFetched)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: Colors.green.shade300),
                              ),
                              child: Text(
                                'Lido do Facebook',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey<String>('summary_field'),
                        controller: _summaryController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Resumo automático do vídeo/publicação (podes editar ou acrescentar notas)...',
                          filled: true,
                          fillColor: const Color(0xFFF5F7FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Secção de Links Extraídos -> Separador Links
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: const Color(0xFF1E88E5).withOpacity(0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.link,
                            color: Color(0xFF1E88E5),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Links para o separador Links (${_extractedLinks.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                          ),
                          Switch(
                            value: _saveExtraLinksSeparately,
                            activeColor: const Color(0xFF1E88E5),
                            onChanged: (v) =>
                                setState(() => _saveExtraLinksSeparately = v),
                          ),
                        ],
                      ),
                      if (_extractedLinks.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ..._extractedLinks.map(
                          (link) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF1E88E5).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.open_in_new,
                                    size: 15,
                                    color: Color(0xFF1E88E5),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      link,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() {
                                        _extractedLinks.remove(link);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey<String>('extra_link_field'),
                              controller: _extraLinkController,
                              keyboardType: TextInputType.url,
                              onSubmitted: (_) => _addManualExtraLink(),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText:
                                    'Adicionar link do vídeo para a aba Links...',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            key: const ValueKey<String>('add_extra_link_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _addManualExtraLink,
                            child: const Text('+ Link'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Secção de Imagens Extraídas -> Separador Imagens
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: const Color(0xFF00897B).withOpacity(0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.image,
                            color: Color(0xFF00897B),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Imagens para o separador Imagens (${_extractedImages.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00897B),
                              ),
                            ),
                          ),
                          Switch(
                            value: _saveExtraImagesSeparately,
                            activeColor: const Color(0xFF00897B),
                            onChanged: (v) =>
                                setState(() => _saveExtraImagesSeparately = v),
                          ),
                        ],
                      ),
                      if (_extractedImages.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ..._extractedImages.map(
                          (imgUrl) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF00897B).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.photo_outlined,
                                    size: 16,
                                    color: Color(0xFF00897B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      imgUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() {
                                        _extractedImages.remove(imgUrl);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey<String>('extra_image_field'),
                              controller: _extraImageController,
                              keyboardType: TextInputType.url,
                              onSubmitted: (_) => _addManualExtraImage(),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText:
                                    'Adicionar imagem para a aba Imagens...',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            key: const ValueKey<String>('add_extra_image_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _addManualExtraImage,
                            child: const Text('+ Imagem'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Escolha da Categoria Principal
              const Text(
                'Escolhe ou confirma onde guardar o conteúdo principal:',
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
              const SizedBox(height: 16),

              // 6. Título editável
              TextField(
                controller: _titleController,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Título do Vídeo / Conteúdo',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
              const SizedBox(height: 12),

              // 7. Link principal editável
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                onChanged: _reanalyzeUrl,
                decoration: const InputDecoration(
                  labelText: 'Link principal colado',
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
