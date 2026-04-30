import 'dart:convert';
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

    state.db.insert('messages', {
      'id': message['id'],
      'channel_id': channelId,
      'from': from,
      'to': to,
      'content': content,
      'timestamp': now.millisecondsSinceEpoch,
      'thread_id': threadId,
    });

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
