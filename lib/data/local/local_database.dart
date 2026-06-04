import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/server_profile.dart';
import '../../domain/repositories/server_repository.dart';
import '../../domain/repositories/settings_repository.dart';

class LocalDatabase implements ServerRepository, SettingsRepository {
  LocalDatabase._(this._db);

  final Database _db;

  static Future<LocalDatabase> open() async {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'host_connect.sqlite');
    final db = sqlite3.open(dbPath);
    final database = LocalDatabase._(db);
    database._migrate();
    return database;
  }

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS server_profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    final guidRow = _db.select(
      'SELECT value FROM app_settings WHERE key = ? LIMIT 1',
      <Object?>['local_server_guid'],
    );

    if (guidRow.isEmpty) {
      _db.execute(
        'INSERT INTO app_settings (key, value) VALUES (?, ?)',
        <Object?>['local_server_guid', _randomGuid().toString()],
      );
    }

    final languageRow = _db.select(
      'SELECT value FROM app_settings WHERE key = ? LIMIT 1',
      <Object?>['language_code'],
    );

    if (languageRow.isEmpty) {
      _db.execute(
        'INSERT INTO app_settings (key, value) VALUES (?, ?)',
        <Object?>['language_code', 'de'],
      );
    }
  }

  @override
  Future<ServerProfile?> getProfile(String id) async {
    final rows = _db.select(
      '''
      SELECT id, name, host, port, is_favorite
      FROM server_profiles
      WHERE id = ?
      LIMIT 1
      ''',
      <Object?>[id],
    );

    if (rows.isEmpty) {
      return null;
    }
    return _profileFromRow(rows.first);
  }

  @override
  Future<List<ServerProfile>> listProfiles() async {
    final rows = _db.select('''
      SELECT id, name, host, port, is_favorite
      FROM server_profiles
      ORDER BY is_favorite DESC, lower(name) ASC
    ''');

    return rows.map(_profileFromRow).toList(growable: false);
  }

  @override
  Future<void> saveProfile(ServerProfile profile) async {
    _db.execute(
      '''
      INSERT INTO server_profiles (id, name, host, port, is_favorite)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        host = excluded.host,
        port = excluded.port,
        is_favorite = excluded.is_favorite
      ''',
      <Object?>[
        profile.id,
        profile.name,
        profile.host,
        profile.port,
        profile.isFavorite ? 1 : 0,
      ],
    );
  }

  @override
  Future<void> deleteProfile(String id) async {
    _db.execute(
      'DELETE FROM server_profiles WHERE id = ?',
      <Object?>[id],
    );
  }

  @override
  Future<AppSettings> loadSettings() async {
    final language = _readSetting('language_code') ?? 'de';
    final guidText = _readSetting('local_server_guid');
    final guid = int.tryParse(guidText ?? '') ?? _randomGuid();
    return AppSettings(languageCode: language, localServerGuid: guid);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _writeSetting('language_code', settings.languageCode);
    _writeSetting('local_server_guid', settings.localServerGuid.toString());
  }

  void close() {
    _db.dispose();
  }

  String? _readSetting(String key) {
    final rows = _db.select(
      'SELECT value FROM app_settings WHERE key = ? LIMIT 1',
      <Object?>[key],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String;
  }

  void _writeSetting(String key, String value) {
    _db.execute(
      '''
      INSERT INTO app_settings (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      <Object?>[key, value],
    );
  }

  ServerProfile _profileFromRow(Row row) {
    return ServerProfile(
      id: row['id'] as String,
      name: row['name'] as String,
      host: row['host'] as String,
      port: row['port'] as int,
      isFavorite: (row['is_favorite'] as int) == 1,
    );
  }

  static int _randomGuid() {
    final random = Random.secure();
    final high = random.nextInt(0x7fffffff);
    final low = random.nextInt(0xffffffff);
    return (high << 32) | low;
  }
}
