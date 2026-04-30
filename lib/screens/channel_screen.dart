import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../models/agent.dart' as ag;
import '../services/websocket_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

final _uuid = Uuid();

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
  final List<ag.Agent> _agents = [];
  final _scrollController = ScrollController();
  bool _loading = true;

  static const _baseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.wsService.events.listen(_onWsEvent);
  }

  @override
  void didUpdateWidget(ChannelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id != widget.channel.id) {
      setState(() {
        _messages.clear();
        _loading = true;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    await Future.wait([_loadMessages(), _loadAgents()]);
    setState(() => _loading = false);
    _scrollToBottom();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/messages?channelId=${widget.channel.id}'),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _messages.clear();
          _messages.addAll(list.map((j) => Message.fromJson(j as Map<String, dynamic>)));
        });
      }
    } catch (e) {
      debugPrint('Load messages error: $e');
    }
  }

  Future<void> _loadAgents() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/agents?channelId=${widget.channel.id}'),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _agents.clear();
          _agents.addAll(list.map((j) => ag.Agent.fromJson(j as Map<String, dynamic>)));
        });
      }
    } catch (e) {
      debugPrint('Load agents error: $e');
    }
  }

  void _onWsEvent(WsEvent event) {
    if (event.type == WsEventType.message) {
      final msg = Message.fromJson(event.data);
      if (msg.channelId == widget.channel.id) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } else if (event.type == WsEventType.agentStatus) {
      final id = event.data['id'] as String;
      final status = event.data['status'] as String;
      setState(() {
        final idx = _agents.indexWhere((a) => a.id == id);
        if (idx >= 0) {
          _agents[idx] = _agents[idx].copyWith(
            status: ag.AgentStatus.values.firstWhere(
              (s) => s.name == status,
              orElse: () => ag.AgentStatus.idle,
            ),
          );
        }
      });
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
              // Agent status indicators
              ..._agents.map((a) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Chip(
                      label: Text(
                        a.name,
                        style: const TextStyle(fontSize: 11),
                      ),
                      avatar: CircleAvatar(
                        radius: 4,
                        backgroundColor: _statusColor(a.status),
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )),
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                onPressed: _showAddAgentDialog,
                tooltip: 'Add agent',
              ),
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

  Color _statusColor(ag.AgentStatus status) {
    switch (status) {
      case ag.AgentStatus.active:
        return Colors.green;
      case ag.AgentStatus.idle:
        return Colors.grey;
      case ag.AgentStatus.sleeping:
        return Colors.orange;
    }
  }

  Future<void> _showAddAgentDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Agent'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Agent name',
            hintText: 'e.g. impl, reviewer',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/agents'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'id': _uuid.v4(),
            'name': result,
            'channelId': widget.channel.id,
            'status': 'idle',
          }),
        );
        await _loadAgents();
      } catch (e) {
        debugPrint('Add agent error: $e');
      }
    }
  }
}
