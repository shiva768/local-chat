import 'package:sqlite3/sqlite3.dart' as sqlt;

class ServerState {
  final _Database _database;
  final List<void Function(String)> _senders = [];

  ServerState._(this._database);

  static Future<ServerState> create(String dbPath) async {
    final db = _Database(dbPath);
    await db.initialize();
    return ServerState._(db);
  }

  void addSender(void Function(String) send) {
    _senders.add(send);
  }

  void removeSender(void Function(String) send) {
    _senders.remove(send);
  }

  void broadcast(String message) {
    for (final sender in _senders.toList()) {
      try {
        sender(message);
      } catch (_) {
        _senders.remove(sender);
      }
    }
  }

  // ignore: library_private_types_in_public_api
  _Database get db => _database;
}

class _Database {
  final sqlt.Database _sqlite;

  _Database(String path) : _sqlite = sqlt.sqlite3.open(path);

  Future<void> initialize() async {
    _sqlite.execute('''
      CREATE TABLE IF NOT EXISTS channels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        agent_ids TEXT NOT NULL DEFAULT '[]',
        chat_dir TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    _sqlite.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        channel_id TEXT NOT NULL,
        "from" TEXT NOT NULL,
        "to" TEXT,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        thread_id TEXT
      )
    ''');
    _sqlite.execute('''
      CREATE TABLE IF NOT EXISTS agents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'idle'
      )
    ''');

    // Insert default channel if not exists
    final existing = _sqlite.select('SELECT id FROM channels WHERE id = ?', ['general']);
    if (existing.isEmpty) {
      _sqlite.execute(
        'INSERT INTO channels (id, name, description, agent_ids, chat_dir, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        ['general', 'general', 'General discussion', '[]', '.chat/general', DateTime.now().millisecondsSinceEpoch],
      );
    }
  }

  List<Map<String, Object?>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) {
    var sql = 'SELECT * FROM $table';
    if (where != null) sql += ' WHERE $where';
    if (orderBy != null) sql += ' ORDER BY $orderBy';

    final result = _sqlite.select(sql, whereArgs ?? []);
    return result.map((r) => Map<String, Object?>.from(r)).toList();
  }

  void execute(String sql, [List<Object?>? args]) {
    _sqlite.execute(sql, args ?? []);
  }

  void insert(String table, Map<String, Object?> values) {
    final cols = values.keys.map((k) => '"$k"').join(', ');
    final placeholders = values.keys.map((_) => '?').join(', ');
    _sqlite.execute(
      'INSERT OR REPLACE INTO $table ($cols) VALUES ($placeholders)',
      values.values.toList(),
    );
  }

  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    final sets = values.keys.map((k) => '"$k" = ?').join(', ');
    var sql = 'UPDATE $table SET $sets';
    if (where != null) sql += ' WHERE $where';
    _sqlite.execute(sql, [...values.values, ...(whereArgs ?? [])]);
  }
}
