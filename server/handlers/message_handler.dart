import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import '../server_state.dart';

final _uuid = Uuid();

Handler messageHandler(ServerState state) {
  return (Request request) async {
    if (request.method == 'POST') {
      return _handlePostMessage(request, state);
    } else if (request.method == 'GET') {
      return _handleGetMessages(request, state);
    }
    return Response.notFound('Not found');
  };
}

Future<Response> _handlePostMessage(Request request, ServerState state) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final channelId = data['channelId'] as String;
    final from = data['from'] as String;
    final content = data['content'] as String;
    final to = data['to'] as String?;
    final threadId = data['threadId'] as String?;

    final now = DateTime.now();
    final message = {
      'id': _uuid.v4(),
      'channelId': channelId,
      'from': from,
      'to': to,
      'content': content,
      'timestamp': now.toIso8601String(),
      'threadId': threadId,
    };

    // Save to DB
    state.db.insert('messages', {
      'id': message['id'],
      'channel_id': channelId,
      'from': from,
      'to': to,
      'content': content,
      'timestamp': now.millisecondsSinceEpoch,
      'thread_id': threadId,
    });

    // Write to agent inbox if there's a mention
    await _writeToInbox(channelId, message, state);

    // Broadcast via WebSocket
    state.broadcast(jsonEncode({'type': 'message', 'data': message}));

    return Response.ok(
      jsonEncode(message),
      headers: {'content-type': 'application/json'},
    );
  } catch (e, st) {
    print('Error: $e\n$st');
    return Response.internalServerError(body: 'Error: $e');
  }
}

Future<Response> _handleGetMessages(Request request, ServerState state) async {
  final channelId = request.url.queryParameters['channelId'];
  if (channelId == null) {
    return Response.badRequest(body: 'channelId required');
  }

  final rows = state.db.query(
    'messages',
    where: 'channel_id = ?',
    whereArgs: [channelId],
    orderBy: 'timestamp ASC',
  );

  final messages = rows
      .map((r) => {
            'id': r['id'],
            'channelId': r['channel_id'],
            'from': r['from'],
            'to': r['to'],
            'content': r['content'],
            'timestamp': DateTime.fromMillisecondsSinceEpoch(r['timestamp'] as int)
                .toIso8601String(),
            'threadId': r['thread_id'],
          })
      .toList();

  return Response.ok(
    jsonEncode(messages),
    headers: {'content-type': 'application/json'},
  );
}

Future<void> _writeToInbox(
    String channelId, Map<String, dynamic> message, ServerState state) async {
  final content = message['content'] as String;
  final mentionRegex = RegExp(r'@(\w+)');
  final mentions = mentionRegex.allMatches(content).map((m) => m.group(1)!);

  for (final agentName in mentions) {
    final agents = state.db.query(
      'agents',
      where: 'name = ? AND channel_id = ?',
      whereArgs: [agentName, channelId],
    );

    for (final agent in agents) {
      final chatDir = _getChannelChatDir(channelId, state);
      if (chatDir == null) continue;

      final inboxFile = File('$chatDir/$agentName/inbox.json');
      await inboxFile.parent.create(recursive: true);

      Map<String, dynamic> inbox = {'pending': []};
      if (await inboxFile.exists()) {
        try {
          inbox = jsonDecode(await inboxFile.readAsString());
        } catch (_) {}
      }

      final pending = inbox['pending'] as List<dynamic>;
      pending.add({
        'id': message['id'],
        'from': message['from'],
        'content': content,
        'timestamp': message['timestamp'],
      });

      await inboxFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(inbox));

      // Update agent status to active
      state.db.update(
        'agents',
        {'status': 'active'},
        where: 'id = ?',
        whereArgs: [agent['id']],
      );
      state.broadcast(jsonEncode({
        'type': 'agentStatus',
        'data': {'id': agent['id'], 'status': 'active'},
      }));
    }
  }
}

String? _getChannelChatDir(String channelId, ServerState state) {
  final rows = state.db.query('channels', where: 'id = ?', whereArgs: [channelId]);
  if (rows.isEmpty) return null;
  return rows.first['chat_dir'] as String?;
}
