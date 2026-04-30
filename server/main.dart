import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'server_state.dart';
import 'handlers/message_handler.dart';
import 'handlers/channel_handler.dart';

final _uuid = Uuid();

void main() async {
  final dbPath = p.join(Directory.current.path, 'local_chat_server.db');
  final state = await ServerState.create(dbPath);

  // Start file watchers for existing channels
  _startFileWatchers(state);

  final router = Router();

  // WebSocket endpoint
  router.get('/ws', webSocketHandler((channel) {
    print('WebSocket client connected');

    void sendFn(String msg) => channel.sink.add(msg);
    state.addSender(sendFn);

    channel.stream.listen(
      (_) {},
      onDone: () {
        print('WebSocket client disconnected');
        state.removeSender(sendFn);
      },
      onError: (_) {
        state.removeSender(sendFn);
      },
    );
  }));

  // REST endpoints
  router.get('/api/channels', (Request r) => channelHandler(state)(r));
  router.post('/api/channels', (Request r) => channelHandler(state)(r));
  router.get('/api/agents', (Request r) => agentHandler(state)(r));
  router.post('/api/agents', (Request r) => agentHandler(state)(r));
  router.get('/api/messages', (Request r) => messageHandler(state)(r));
  router.post('/api/messages', (Request r) => messageHandler(state)(r));

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(router.call);

  final server = await io.serve(handler, 'localhost', 8080);
  print('Server running on http://localhost:${server.port}');
}

Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders());
      }
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders());
    };
  };
}

Map<String, String> _corsHeaders() => {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

void _startFileWatchers(ServerState state) {
  final channels = state.db.query('channels');
  for (final channel in channels) {
    final chatDir = channel['chat_dir'] as String?;
    if (chatDir != null) {
      _watchChannelOutbox(chatDir, channel['id'] as String, state);
    }
  }
}

void _watchChannelOutbox(String chatDir, String channelId, ServerState state) {
  final dir = Directory(chatDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final watcher = DirectoryWatcher(chatDir);
  watcher.events.listen((event) async {
    if (event.path.endsWith('outbox.json') &&
        (event.type == ChangeType.MODIFY || event.type == ChangeType.ADD)) {
      await _processOutbox(event.path, channelId, state);
    }
  });

  print('Watching $chatDir for outbox changes');
}

Future<void> _processOutbox(
    String outboxPath, String channelId, ServerState state) async {
  try {
    await Future.delayed(const Duration(milliseconds: 100));
    final file = File(outboxPath);
    if (!await file.exists()) return;

    final content = await file.readAsString();
    if (content.trim().isEmpty) return;

    final data = jsonDecode(content) as Map<String, dynamic>;
    final messages = (data['messages'] as List<dynamic>? ?? []);

    if (messages.isEmpty) return;

    for (final msg in messages) {
      final msgMap = msg as Map<String, dynamic>;
      final id = msgMap['id'] as String? ?? _uuid.v4();

      // Check if already processed
      final existing = state.db.query(
        'messages',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isNotEmpty) continue;

      final timestamp = msgMap['timestamp'] != null
          ? DateTime.parse(msgMap['timestamp'] as String)
          : DateTime.now();

      state.db.insert('messages', {
        'id': id,
        'channel_id': channelId,
        'from': msgMap['from'],
        'to': msgMap['to'],
        'content': msgMap['content'],
        'timestamp': timestamp.millisecondsSinceEpoch,
        'thread_id': msgMap['threadId'],
      });

      final message = {
        'id': id,
        'channelId': channelId,
        'from': msgMap['from'],
        'to': msgMap['to'],
        'content': msgMap['content'],
        'timestamp': timestamp.toIso8601String(),
        'threadId': msgMap['threadId'],
      };

      state.broadcast(jsonEncode({'type': 'message', 'data': message}));
      print('Processed outbox message from ${msgMap['from']}: ${msgMap['content']}');
    }

    // Clear the outbox after processing
    await file.writeAsString(jsonEncode({'messages': []}));
  } catch (e) {
    print('Error processing outbox: $e');
  }
}
