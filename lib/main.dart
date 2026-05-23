import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/server_config.dart';
import 'utils/url_helper.dart';

void main() async {
  // Flutter の初期化前にハッシュを読み取る（初期化後に消される可能性があるため）
  final initialChannelId = getUrlHash();
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.load();
  runApp(LocalChatApp(initialChannelId: initialChannelId));
}

class LocalChatApp extends StatelessWidget {
  final String initialChannelId;

  const LocalChatApp({super.key, required this.initialChannelId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F0E40)),
        useMaterial3: true,
      ),
      home: HomeScreen(initialChannelId: initialChannelId),
    );
  }
}
