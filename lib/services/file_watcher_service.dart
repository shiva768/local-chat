import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef OutboxCallback = void Function(Map<String, dynamic> message);

class FileWatcherService {
  final Map<String, StreamSubscription> _subscriptions = {};

  void watchChannel(String chatDir, String channelId, OutboxCallback onMessage) {
    if (_subscriptions.containsKey(channelId)) return;

    final dir = Directory(chatDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Poll outbox files every 2 seconds (simpler than watcher for Flutter)
    final timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _checkOutboxFiles(chatDir, channelId, onMessage);
    });

    // Store as a dummy subscription to track
    _subscriptions[channelId] = Stream.periodic(Duration.zero).listen((_) {
      timer.cancel();
    });
  }

  Future<void> _checkOutboxFiles(
      String chatDir, String channelId, OutboxCallback onMessage) async {
    final dir = Directory(chatDir);
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('outbox.json')) {
        await _processOutbox(entity, onMessage);
      }
    }
  }

  Future<void> _processOutbox(File file, OutboxCallback onMessage) async {
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final data = jsonDecode(content) as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>? ?? []);

      if (messages.isEmpty) return;

      for (final msg in messages) {
        onMessage(msg as Map<String, dynamic>);
      }

      // Clear after processing
      await file.writeAsString(jsonEncode({'messages': []}));
    } catch (e) {
      // ignore parse errors
    }
  }

  void unwatchChannel(String channelId) {
    _subscriptions[channelId]?.cancel();
    _subscriptions.remove(channelId);
  }

  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
