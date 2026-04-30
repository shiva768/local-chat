import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import '../server_state.dart';

final _uuid = Uuid();

Handler channelHandler(ServerState state) {
  return (Request request) async {
    if (request.method == 'GET') {
      return _handleGetChannels(request, state);
    } else if (request.method == 'POST') {
      return _handlePostChannel(request, state);
    }
    return Response.notFound('Not found');
  };
}

Handler agentHandler(ServerState state) {
  return (Request request) async {
    if (request.method == 'GET') {
      return _handleGetAgents(request, state);
    } else if (request.method == 'POST') {
      return _handlePostAgent(request, state);
    }
    return Response.notFound('Not found');
  };
}

Response _handleGetChannels(Request request, ServerState state) {
  final rows = state.db.query('channels', orderBy: 'created_at ASC');
  final channels = rows
      .map((r) => {
            'id': r['id'],
            'name': r['name'],
            'description': r['description'],
            'agentIds':
                jsonDecode(r['agent_ids'] as String? ?? '[]'),
            'chatDir': r['chat_dir'],
            'createdAt':
                DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int)
                    .toIso8601String(),
          })
      .toList();

  return Response.ok(
    jsonEncode(channels),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _handlePostChannel(
    Request request, ServerState state) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final name = data['name'] as String;
    final id = data['id'] as String? ?? name;
    final description = data['description'] as String?;
    final chatDir = data['chatDir'] as String? ?? '.chat/$name';

    state.db.insert('channels', {
      'id': id,
      'name': name,
      'description': description,
      'agent_ids': '[]',
      'chat_dir': chatDir,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    final channel = {
      'id': id,
      'name': name,
      'description': description,
      'agentIds': <String>[],
      'chatDir': chatDir,
      'createdAt': DateTime.now().toIso8601String(),
    };

    state.broadcast(jsonEncode({'type': 'channel', 'data': channel}));

    return Response.ok(
      jsonEncode(channel),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(body: 'Error: $e');
  }
}

Response _handleGetAgents(Request request, ServerState state) {
  final channelId = request.url.queryParameters['channelId'];
  List<Map<String, Object?>> rows;
  if (channelId != null) {
    rows = state.db.query(
      'agents',
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
  } else {
    rows = state.db.query('agents');
  }

  final agents = rows
      .map((r) => {
            'id': r['id'],
            'name': r['name'],
            'channelId': r['channel_id'],
            'status': r['status'],
          })
      .toList();

  return Response.ok(
    jsonEncode(agents),
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> _handlePostAgent(Request request, ServerState state) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final id = data['id'] as String? ?? _uuid.v4();
    final name = data['name'] as String;
    final channelId = data['channelId'] as String;
    final status = data['status'] as String? ?? 'idle';

    state.db.insert('agents', {
      'id': id,
      'name': name,
      'channel_id': channelId,
      'status': status,
    });

    // Update channel's agentIds
    final channelRows = state.db.query(
      'channels',
      where: 'id = ?',
      whereArgs: [channelId],
    );
    if (channelRows.isNotEmpty) {
      final existing =
          jsonDecode(channelRows.first['agent_ids'] as String? ?? '[]')
              as List<dynamic>;
      existing.add(id);
      state.db.update(
        'channels',
        {'agent_ids': jsonEncode(existing)},
        where: 'id = ?',
        whereArgs: [channelId],
      );
    }

    final agent = {
      'id': id,
      'name': name,
      'channelId': channelId,
      'status': status,
    };

    state.broadcast(jsonEncode({'type': 'agent', 'data': agent}));

    return Response.ok(
      jsonEncode(agent),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(body: 'Error: $e');
  }
}
