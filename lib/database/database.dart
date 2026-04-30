import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Channels extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get agentIds => text()(); // JSON encoded list
  TextColumn get chatDir => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get channelId => text()();
  TextColumn get from => text()();
  TextColumn get to => text().nullable()();
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get threadId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Agents extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get channelId => text()();
  TextColumn get status => text()(); // active / idle / sleeping

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Channels, Messages, Agents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Insert default channel
          await into(channels).insertOnConflictUpdate(ChannelsCompanion.insert(
            id: 'general',
            name: 'general',
            description: const Value('General discussion'),
            agentIds: '[]',
            chatDir: '.chat/general',
            createdAt: DateTime.now(),
          ));
        },
      );

  // Channel operations
  Future<List<Channel>> getAllChannels() => select(channels).get();

  Stream<List<Channel>> watchAllChannels() => select(channels).watch();

  Future<Channel?> getChannel(String id) =>
      (select(channels)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertChannel(ChannelsCompanion channel) =>
      into(channels).insertOnConflictUpdate(channel);

  // Message operations
  Future<List<Message>> getMessagesForChannel(String channelId) =>
      (select(messages)
            ..where((t) => t.channelId.equals(channelId))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Stream<List<Message>> watchMessagesForChannel(String channelId) =>
      (select(messages)
            ..where((t) => t.channelId.equals(channelId))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .watch();

  Future<void> insertMessage(MessagesCompanion message) =>
      into(messages).insertOnConflictUpdate(message);

  // Agent operations
  Future<List<Agent>> getAllAgents() => select(agents).get();

  Stream<List<Agent>> watchAllAgents() => select(agents).watch();

  Future<List<Agent>> getAgentsForChannel(String channelId) =>
      (select(agents)..where((t) => t.channelId.equals(channelId))).get();

  Future<void> upsertAgent(AgentsCompanion agent) =>
      into(agents).insertOnConflictUpdate(agent);

  Future<void> updateAgentStatus(String agentId, String status) =>
      (update(agents)..where((t) => t.id.equals(agentId)))
          .write(AgentsCompanion(status: Value(status)));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'local_chat.db'));
    return NativeDatabase.createInBackground(file);
  });
}
