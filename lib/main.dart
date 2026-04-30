import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/server_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.load();
  runApp(const LocalChatApp());
}

class LocalChatApp extends StatelessWidget {
  const LocalChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F0E40)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
