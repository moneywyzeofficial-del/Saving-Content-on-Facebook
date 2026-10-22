// lib/screens/saved_items_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_item.dart';

class SavedItemsScreen extends StatelessWidget {
  final String type; // 'text', 'image', 'video', 'link', 'comment'
  final String title;

  const SavedItemsScreen({Key? key, required this.type, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('saved_items')
            .where('type', isEqualTo: type)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar $title'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('Nenhum $title encontrado'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final item = SavedItem.fromMap(data);
              return _buildItemTile(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildItemTile(SavedItem item) {
    switch (item.type) {
      case 'text':
        return ListTile(title: Text(item.content ?? ''), subtitle: Text('Post')); 
      case 'link':
        return ListTile(
          title: Text(item.url ?? ''),
          leading: Icon(Icons.link),
          subtitle: Text('Link'),
          onTap: () async => await launchUrl(item.url!),
        );
      case 'image':
        return ListTile(
          leading: Image.network(item.url ?? '', width: 60, height: 60, fit: BoxFit.cover),
          title: Text('Imagem'),
          subtitle: Text(item.url ?? ''),
        );
      case 'video':
        return ListTile(
          leading: Icon(Icons.videocam),
          title: Text('Vídeo'),
          subtitle: Text(item.url ?? ''),
        );
      case 'comment':
        return ListTile(title: Text(item.content ?? ''), subtitle: Text('Comentário'));
      default:
        return ListTile(title: Text('Tipo desconhecido'));
    }
  }
}
