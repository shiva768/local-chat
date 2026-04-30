import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/channel.dart';
import '../services/websocket_service.dart';
import '../widgets/channel_list.dart';
import 'channel_screen.dart';

final _uuid = Uuid();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Channel> _channels = [];
  Channel? _selectedChannel;
  final _wsService = WebSocketService();
  bool _connected = false;
  final String _currentUser = 'human';

  static const _baseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _wsService.connect();
    _wsService.events.listen(_onWsEvent);
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/channels'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _channels.clear();
          _channels.addAll(
              list.map((j) => Channel.fromJson(j as Map<String, dynamic>)));
          _connected = true;
          if (_selectedChannel == null && _channels.isNotEmpty) {
            _selectedChannel = _channels.first;
          }
        });
      }
    } catch (e) {
      setState(() => _connected = false);
      // Retry after 3 seconds
      Future.delayed(const Duration(seconds: 3), _loadChannels);
    }
  }

  void _onWsEvent(WsEvent event) {
    if (event.type == WsEventType.channel) {
      final ch = Channel.fromJson(event.data);
      setState(() {
        final idx = _channels.indexWhere((c) => c.id == ch.id);
        if (idx >= 0) {
          _channels[idx] = ch;
        } else {
          _channels.add(ch);
        }
      });
    }
  }

  Future<void> _addChannel() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Channel name'),
              autofocus: true,
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('$_baseUrl/api/channels'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'id': _uuid.v4(),
            'name': nameController.text.trim(),
            'description': descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
            'chatDir': '.chat/${nameController.text.trim()}',
          }),
        );
        if (res.statusCode == 200) {
          await _loadChannels();
        }
      } catch (e) {
        debugPrint('Create channel error: $e');
      }
    }
  }

  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: const Color(0xFF3F0E40),
            child: Column(
              children: [
                // Workspace header
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Local Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Icon(
                        _connected ? Icons.circle : Icons.circle_outlined,
                        color: _connected ? Colors.green : Colors.red,
                        size: 10,
                      ),
                    ],
                  ),
                ),
                // Channel list
                Expanded(
                  child: ChannelList(
                    channels: _channels,
                    selectedChannelId: _selectedChannel?.id,
                    onChannelSelected: (ch) =>
                        setState(() => _selectedChannel = ch),
                    onAddChannel: _addChannel,
                  ),
                ),
                // Current user
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentUser,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: _selectedChannel == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Select a channel to start chatting',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Make sure the server is running:\ndart run server/main.dart',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ChannelScreen(
                    key: ValueKey(_selectedChannel!.id),
                    channel: _selectedChannel!,
                    wsService: _wsService,
                    currentUser: _currentUser,
                  ),
          ),
        ],
      ),
    );
  }
}
