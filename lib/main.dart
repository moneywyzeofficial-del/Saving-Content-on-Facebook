// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'screens/saved_items_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(FacebookSaveApp());
}

class FacebookSaveApp extends StatefulWidget {
  @override
  _FacebookSaveAppState createState() => _FacebookSaveAppState();
}

class _FacebookSaveAppState extends State<FacebookSaveApp> {
  AccessToken? _fbAccessToken;
  int _selectedIndex = 0;
  static const platform = MethodChannel('com.example.facebook_save/share');

  @override
  void initState() {
    super.initState();
    _checkLogin();
    _listenForShareIntent();
  }

  Future<void> _checkLogin() async {
    final accessToken = await FacebookAuth.instance.accessToken;
    setState(() => _fbAccessToken = accessToken);
  }

  Future<void> _login() async {
    final result = await FacebookAuth.instance.login();
    if (result.status == LoginStatus.success) {
      setState(() => _fbAccessToken = result.accessToken);
    }
  }

  // Listen for share intents from Android / iOS extensions
  void _listenForShareIntent() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final Map args = call.arguments as Map;
        await _handleSharedData(args);
      }
    });
  }

  Future<void> _handleSharedData(Map data) async {
    // Data may contain: 'text', 'imageUri', 'videoUri', 'url'
    final userId = _fbAccessToken?.userId ?? 'anonymous';
    final now = FieldValue.serverTimestamp();
    if (data.containsKey('text')) {
      await FirebaseFirestore.instance.collection('saved_items').add({
        'type': 'text',
        'content': data['text'],
        'owner': userId,
        'createdAt': now,
      });
    }
    if (data.containsKey('url')) {
      await FirebaseFirestore.instance.collection('saved_items').add({
        'type': 'link',
        'url': data['url'],
        'owner': userId,
        'createdAt': now,
      });
    }
    if (data.containsKey('imageUri') || data.containsKey('videoUri')) {
      final uri = data['imageUri'] ?? data['videoUri'];
      final isVideo = data.containsKey('videoUri');
      final file = File(uri);
      final bytes = await file.readAsBytes();
      final storageRef = FirebaseStorage.instance.ref().child('media/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}');
      await storageRef.putData(bytes, SettableMetadata(contentType: isVideo ? 'video/mp4' : 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance.collection('saved_items').add({
        'type': isVideo ? 'video' : 'image',
        'url': downloadUrl,
        'owner': userId,
        'createdAt': now,
      });
    }
    // Show a snackbar to confirm
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conteúdo salvo!')));
  }

  static const List<Widget> _pages = <Widget>[
    SavedItemsScreen(type: 'text', title: 'Posts'),
    SavedItemsScreen(type: 'image', title: 'Imagens'),
    SavedItemsScreen(type: 'video', title: 'Vídeos'),
    SavedItemsScreen(type: 'link', title: 'Links'),
    SavedItemsScreen(type: 'comment', title: 'Comentários'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facebook Save Content',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Facebook Save Content'),
          actions: [_fbAccessToken == null ? IconButton(icon: Icon(Icons.login), onPressed: _login) : Container()],
        ),
        body: _pages.elementAt(_selectedIndex),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Posts'),
            BottomNavigationBarItem(icon: Icon(Icons.image), label: 'Imagens'),
            BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Vídeos'),
            BottomNavigationBarItem(icon: Icon(Icons.link), label: 'Links'),
            BottomNavigationBarItem(icon: Icon(Icons.comment), label: 'Comentários'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.indigoAccent,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
