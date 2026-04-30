import 'package:drift/drift.dart';
import '../database/database.dart';
import '../models/message.dart' as model;

class MessageRepository {
  final AppDatabase _db;

  MessageRepository(this._db);

  Stream<List<model.Message>> watchMessagesForChannel(String channelId) {
    return _db
        .watchMessagesForChannel(channelId)
        .map((rows) => rows.map(_toModel).toList());
  }

  Future<List<model.Message>> getMessagesForChannel(String channelId) async {
    final rows = await _db.getMessagesForChannel(channelId);
    return rows.map(_toModel).toList();
  }

  Future<void> saveMessage(model.Message message) async {
    await _db.insertMessage(MessagesCompanion.insert(
      id: message.id,
      channelId: message.channelId,
      from: message.from,
      to: Value(message.to),
      content: message.content,
      timestamp: message.timestamp,
      threadId: Value(message.threadId),
    ));
  }

  model.Message _toModel(Message row) {
    return model.Message(
      id: row.id,
      channelId: row.channelId,
      from: row.from,
      to: row.to,
      content: row.content,
      timestamp: row.timestamp,
      threadId: row.threadId,
    );
  }
}
