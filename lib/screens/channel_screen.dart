import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../services/server_config.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChannelScreen extends StatefulWidget {
  final Channel channel;
  final WebSocketService wsService;
  final String currentUser;

  const ChannelScreen({
    super.key,
    required this.channel,
    required this.wsService,
    required this.currentUser,
  });

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final List<Message> _messages = [];
  final _scrollController = ScrollController();
  bool _loading = true;
  Timer? _pollTimer;

  String get _baseUrl => ServerConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    widget.wsService.events.listen(_onWsEvent);
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
  }

  @override
  void didUpdateWidget(ChannelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id != widget.channel.id) {
      setState(() {
        _messages.clear();
        _loading = true;
      });
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/messages?channelId=${widget.channel.id}'),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final fetched = list.map((j) => Message.fromJson(j as Map<String, dynamic>)).toList();
        final existingIds = _messages.map((m) => m.id).toSet();
        final newMessages = fetched.where((m) => !existingIds.contains(m.id)).toList();
        if (newMessages.isNotEmpty) {
          setState(() {
            _messages.addAll(newMessages);
            _loading = false;
          });
          _scrollToBottom();
        } else {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      debugPrint('Load messages error: $e');
      setState(() => _loading = false);
    }
  }

  void _onWsEvent(WsEvent event) {
    if (event.type == WsEventType.message) {
      final msg = Message.fromJson(event.data);
      if (msg.channelId == widget.channel.id) {
        final exists = _messages.any((m) => m.id == msg.id);
        if (!exists) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      }
    }
  }

  Future<void> _sendMessage(String content) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/messages'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'channelId': widget.channel.id,
          'from': widget.currentUser,
          'content': content,
        }),
      );
    } catch (e) {
      debugPrint('Send message error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Text(
                '# ${widget.channel.name}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (widget.channel.description != null) ...[
                const SizedBox(width: 8),
                Text(
                  widget.channel.description!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet.\nSend a message to get started!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => MessageBubble(
                        message: _messages[i],
                        isCurrentUser:
                            _messages[i].from == widget.currentUser,
                      ),
                    ),
        ),
        // Input
        MessageInput(
          channelName: widget.channel.name,
          onSend: _sendMessage,
        ),
      ],
    );
  }

}
