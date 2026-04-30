import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsEventType { message, channel, agent, agentStatus, unknown }

class WsEvent {
  final WsEventType type;
  final Map<String, dynamic> data;

  WsEvent({required this.type, required this.data});
}

class WebSocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<WsEvent>.broadcast();
  bool _connected = false;
  Timer? _reconnectTimer;

  Stream<WsEvent> get events => _controller.stream;
  bool get isConnected => _connected;

  void connect({String url = 'ws://localhost:8080/ws'}) {
    _connect(url);
  }

  void _connect(String url) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _connected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final typeStr = json['type'] as String? ?? '';
            final eventData = json['data'] as Map<String, dynamic>? ?? {};

            WsEventType type;
            switch (typeStr) {
              case 'message':
                type = WsEventType.message;
                break;
              case 'channel':
                type = WsEventType.channel;
                break;
              case 'agent':
                type = WsEventType.agent;
                break;
              case 'agentStatus':
                type = WsEventType.agentStatus;
                break;
              default:
                type = WsEventType.unknown;
            }

            _controller.add(WsEvent(type: type, data: eventData));
          } catch (e) {
            print('WS parse error: $e');
          }
        },
        onDone: () {
          _connected = false;
          _scheduleReconnect(url);
        },
        onError: (e) {
          _connected = false;
          _scheduleReconnect(url);
        },
      );
    } catch (e) {
      _connected = false;
      _scheduleReconnect(url);
    }
  }

  void _scheduleReconnect(String url) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () => _connect(url));
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
