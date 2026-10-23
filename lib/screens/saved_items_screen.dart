// lib/screens/saved_items_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_item.dart';
import '../services/saved_items_repository.dart';

class SavedItemsScreen extends StatelessWidget {
  final String type; // 'text', 'image', 'video', 'link', 'comment'
  final String title;
  final IconData categoryIcon;
  final Color accentColor;
  final VoidCallback onAddPressed;

  const SavedItemsScreen({
    super.key,
    required this.type,
    required this.title,
    required this.categoryIcon,
    required this.accentColor,
    required this.onAddPressed,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: accentColor.withOpacity(0.25)),
                ),
              ),
              child: Row(
                children: [
                  Icon(categoryIcon, color: accentColor, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$title (${items.length})',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    onPressed: onAddPressed,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Novo em $title'),
                  ),
                ],
              ),
            ),
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
                              'Ainda não guardaste nada em $title.\nToca no botão abaixo para adicionar.',
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
                                  vertical: 12,
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
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _buildItemTile(context, items[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUrl(BuildContext context, String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) return;
    var formatted = rawUrl.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }
    final uri = Uri.tryParse(formatted);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteItem(String id) async {
    await SavedItemsRepository.instance.deleteItem(id);
  }

  Widget _buildItemTile(BuildContext context, SavedItem item) {
    final hasUrl = item.url != null && item.url!.isNotEmpty;

    return Card(
      elevation: 1,
      child: ListTile(
        leading: item.type == 'image' && hasUrl
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.url!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(categoryIcon, color: accentColor),
                ),
              )
            : CircleAvatar(
                backgroundColor: accentColor.withOpacity(0.12),
                child: Icon(categoryIcon, color: accentColor),
              ),
        title: Text(
          item.title ?? item.content ?? item.url ?? 'Item guardado',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          item.url ?? item.content ?? title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: hasUrl ? () => _openUrl(context, item.url) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasUrl)
              IconButton(
                icon: Icon(Icons.open_in_new, color: accentColor),
                tooltip: 'Abrir Link',
                onPressed: () => _openUrl(context, item.url),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Eliminar',
              onPressed: () => _deleteItem(item.id),
            ),
          ],
        ),
      ),
    );
  }
}
