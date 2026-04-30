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
          _channels.addAll(list.map((j) => Channel.fromJson(j as Map<String, dynamic>)));
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
        title: const Text('新しいチャンネル'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'チャンネル名'),
              autofocus: true,
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: '説明（任意）'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('作成')),
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
            'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
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
        title: const Text('サーバー設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostController,
              decoration: const InputDecoration(labelText: 'Host', hintText: '192.168.1.x'),
            ),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );

    if (result == true) {
      await ServerConfig.save(hostController.text.trim(), portController.text.trim());
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F0E40),
        foregroundColor: Colors.white,
        title: _selectedChannel != null
            ? Text('# ${_selectedChannel!.name}', style: const TextStyle(fontSize: 16))
            : const Text('Local Chat'),
        actions: [
          Icon(
            _connected ? Icons.circle : Icons.circle_outlined,
            color: _connected ? Colors.greenAccent : Colors.redAccent,
            size: 12,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF3F0E40),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Local Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _connected ? Icons.circle : Icons.circle_outlined,
                        color: _connected ? Colors.greenAccent : Colors.redAccent,
                        size: 10,
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: ChannelList(
                    channels: _channels,
                    selectedChannelId: _selectedChannel?.id,
                    onChannelSelected: (ch) {
                      setState(() => _selectedChannel = ch);
                      Navigator.pop(context);
                    },
                    onAddChannel: _addChannel,
                  ),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                  title: Text(_currentUser, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white54, size: 18),
                    onPressed: () {
                      Navigator.pop(context);
                      _showSettings();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _selectedChannel == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('チャンネルを選択してください',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    ServerConfig.baseUrl,
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
    );
  }
}
