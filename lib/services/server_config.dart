import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const _hostKey = 'server_host';
  static const _portKey = 'server_port';
  static const defaultHost = 'localhost';
  static const defaultPort = '8080';

  static String _host = defaultHost;
  static String _port = defaultPort;

  static String get baseUrl => 'http://$_host:$_port';
  static String get wsUrl => 'ws://$_host:$_port/ws';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_hostKey) ?? defaultHost;
    _port = prefs.getString(_portKey) ?? defaultPort;
  }

  static Future<void> save(String host, String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
    await prefs.setString(_portKey, port);
    _host = host;
    _port = port;
  }

  static String get host => _host;
  static String get port => _port;
}
