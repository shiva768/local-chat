import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'server_state.dart';
import 'handlers/message_handler.dart';
import 'handlers/channel_handler.dart';

void main() async {
  final dbPath = p.join(Directory.current.path, 'local_chat_server.db');
  final state = await ServerState.create(dbPath);

  final router = Router();

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

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Server running on http://0.0.0.0:${server.port}');
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
