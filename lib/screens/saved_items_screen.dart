// lib/screens/saved_items_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_item.dart';
import '../services/saved_items_repository.dart';

class SavedItemsScreen extends StatelessWidget {
  final String type; // 'text', 'image', 'video', 'link', 'comment'
  final String title;
  final IconData categoryIcon;
  final Color accentColor;
  final VoidCallback onAddPressed;
  final VoidCallback? onBackToHome;
  final ValueChanged<String>? onOpenCategoryType;
  final void Function(String message)? onShowMessage;

  const SavedItemsScreen({
    super.key,
    required this.type,
    required this.title,
    required this.categoryIcon,
    required this.accentColor,
    required this.onAddPressed,
    this.onBackToHome,
    this.onOpenCategoryType,
    this.onShowMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SavedItemsRepository.instance,
      builder: (context, _) {
        final items = SavedItemsRepository.instance.itemsByType(type);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho da Aba com botões claros
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: accentColor.withOpacity(0.25)),
                ),
              ),
              child: Row(
                children: [
                  Icon(categoryIcon, color: accentColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$title (${items.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  if (onBackToHome != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: onBackToHome,
                      icon: const Icon(Icons.home_outlined, size: 18),
                      label: const Text('Início'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: onAddPressed,
                    icon: const Icon(Icons.add_link, size: 18),
                    label: const Text('Colar Novo'),
                  ),
                ],
              ),
            ),

            // Lista de itens ou estado vazio
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: accentColor.withOpacity(0.12),
                              child: Icon(
                                categoryIcon,
                                size: 36,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Secção de $title vazia',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ainda não guardaste nada em $title.\nToca no botão abaixo para colar ou adicionar conteúdo.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                              ),
                              onPressed: onAddPressed,
                              icon: const Icon(Icons.add_circle_outline),
                              label: Text('Adicionar a $title'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildItemCard(context, items[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String? _resolveUrl(SavedItem item) {
    final candidates = [item.url, item.title, item.content];
    for (final raw in candidates) {
      if (raw == null || raw.trim().isEmpty) continue;
      final trimmed = raw.trim();
      final match = RegExp(
        r'(https?:\/\/[^\s]+|(?:www\.|m\.|web\.)?facebook\.com\/[^\s]+|fb\.watch\/[^\s]+)',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (match != null) {
        var found = match.group(0)!;
        if (!found.startsWith('http://') && !found.startsWith('https://')) {
          found = 'https://$found';
        }
        return found;
      }
      if (!trimmed.contains(' ') && trimmed.contains('.')) {
        return trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
      }
    }
    return null;
  }

  Future<void> _openItemUrl(BuildContext context, SavedItem item) async {
    final resolved = _resolveUrl(item);
    if (resolved == null) {
      _notify(context, 'Este item não contém um link web para abrir.');
      return;
    }
    final uri = Uri.tryParse(resolved);
    if (uri == null) {
      _notify(context, 'Link inválido: $resolved');
      return;
    }
    try {
      // No iOS Safari / PWA, platformDefault + _blank ou _self evita bloqueio de popups
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
      }
    } catch (e) {
      _notify(context, 'Não foi possível abrir o link: $e');
    }
  }

  Future<void> _copyItem(BuildContext context, SavedItem item) async {
    final textToCopy =
        _resolveUrl(item) ?? item.url ?? item.title ?? item.content ?? '';
    if (textToCopy.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: textToCopy));
    } catch (_) {}
    if (context.mounted) {
      _notify(context, 'Copiado: $textToCopy');
    }
  }

  void _deleteItem(BuildContext context, SavedItem item) {
    SavedItemsRepository.instance.deleteItemSync(item.id);
    _notify(context, 'Item removido de $title.');
  }

  void _notify(BuildContext context, String message) {
    if (onShowMessage != null) {
      onShowMessage!(message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, SavedItem item) {
    final resolvedUrl = _resolveUrl(item);
    final hasUrl = resolvedUrl != null && resolvedUrl.isNotEmpty;

    return Card(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.type == 'image' && hasUrl)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      resolvedUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => CircleAvatar(
                        radius: 22,
                        backgroundColor: accentColor.withOpacity(0.12),
                        child: Icon(categoryIcon, color: accentColor),
                      ),
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accentColor.withOpacity(0.12),
                    child: Icon(categoryIcon, color: accentColor),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title ?? item.content ?? resolvedUrl ?? 'Conteúdo guardado',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (resolvedUrl != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          resolvedUrl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Barra de botões de ação explícitos e logo visíveis no topo do cartão
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                if (hasUrl)
                  ElevatedButton.icon(
                    key: ValueKey<String>('open_${item.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => _openItemUrl(context, item),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Abrir no Facebook'),
                  ),
                OutlinedButton.icon(
                  key: ValueKey<String>('copy_${item.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => _copyItem(context, item),
                  icon: const Icon(Icons.copy, size: 17),
                  label: const Text('Copiar'),
                ),
                OutlinedButton.icon(
                  key: ValueKey<String>('delete_${item.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => _deleteItem(context, item),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Apagar'),
                ),
              ],
            ),
            if (item.summary != null && item.summary!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withOpacity(0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.summarize_outlined,
                          size: 16,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Resumo do Conteúdo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.summary!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.extractedLinks.isNotEmpty ||
                item.extractedImages.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (item.extractedLinks.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(
                        Icons.link,
                        size: 16,
                        color: Color(0xFF1E88E5),
                      ),
                      backgroundColor:
                          const Color(0xFF1E88E5).withOpacity(0.1),
                      label: Text(
                        '${item.extractedLinks.length} link(s) na aba Links',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                      onPressed: () {
                        onOpenCategoryType?.call('link');
                      },
                    ),
                  if (item.extractedImages.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(
                        Icons.image,
                        size: 16,
                        color: Color(0xFF00897B),
                      ),
                      backgroundColor:
                          const Color(0xFF00897B).withOpacity(0.1),
                      label: Text(
                        '${item.extractedImages.length} imagem(ns) na aba Imagens',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00897B),
                        ),
                      ),
                      onPressed: () {
                        onOpenCategoryType?.call('image');
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
