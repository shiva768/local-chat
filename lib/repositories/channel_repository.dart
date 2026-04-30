import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../models/channel.dart' as model;

class ChannelRepository {
  final AppDatabase _db;

  ChannelRepository(this._db);

  Stream<List<model.Channel>> watchAllChannels() {
    return _db.watchAllChannels().map((rows) => rows.map(_toModel).toList());
  }

  Future<List<model.Channel>> getAllChannels() async {
    final rows = await _db.getAllChannels();
    return rows.map(_toModel).toList();
  }

  Future<model.Channel?> getChannel(String id) async {
    final row = await _db.getChannel(id);
    return row != null ? _toModel(row) : null;
  }

  Future<void> saveChannel(model.Channel channel) async {
    await _db.upsertChannel(ChannelsCompanion.insert(
      id: channel.id,
      name: channel.name,
      description: Value(channel.description),
      agentIds: jsonEncode(channel.agentIds),
      chatDir: channel.chatDir,
      createdAt: channel.createdAt,
    ));
  }

  model.Channel _toModel(Channel row) {
    return model.Channel(
      id: row.id,
      name: row.name,
      description: row.description,
      agentIds: (jsonDecode(row.agentIds) as List<dynamic>).cast<String>(),
      chatDir: row.chatDir,
      createdAt: row.createdAt,
    );
  }
}
