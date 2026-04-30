import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../services/websocket_service.dart';
import '../services/server_config.dart';
import '../widgets/channel_list.dart';
import 'channel_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    _wsService.connect(url: ServerConfig.wsUrl);
    _wsService.events.listen(_onWsEvent);
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final res = await http.get(Uri.parse('${ServerConfig.baseUrl}/api/channels'));
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
          Uri.parse('${ServerConfig.baseUrl}/api/channels'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
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

  Future<void> _showSettings() async {
    final hostController = TextEditingController(text: ServerConfig.host);
    final portController = TextEditingController(text: ServerConfig.port);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostController,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: '192.168.1.x',
              ),
            ),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
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
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      await ServerConfig.save(
        hostController.text.trim(),
        portController.text.trim(),
      );
      _wsService.dispose();
      setState(() {
        _channels.clear();
        _selectedChannel = null;
        _connected = false;
      });
      _connect();
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
                    border: Border(bottom: BorderSide(color: Colors.white12)),
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
                // Bottom bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      Expanded(
                        child: Text(
                          _currentUser,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white54, size: 18),
                        onPressed: _showSettings,
                        tooltip: 'Server settings',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Select a channel to start chatting',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Server: ${ServerConfig.baseUrl}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
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
