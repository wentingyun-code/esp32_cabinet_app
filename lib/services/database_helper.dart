import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/cabinet_data.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cabinet_history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        temperature REAL NOT NULL,
        humidity REAL NOT NULL,
        dewPoint REAL NOT NULL,
        weather TEXT NOT NULL,
        mode TEXT NOT NULL,
        fanStatus INTEGER NOT NULL,
        heaterStatus INTEGER NOT NULL,
        dehumidifierStatus INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE alert_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        type TEXT NOT NULL,
        message TEXT NOT NULL
      )
    ''');
  }

  Future<HistoryRecord> insertHistoryRecord(HistoryRecord record) async {
    final db = await instance.database;
    final id = await db.insert('history_records', record.toMap());
    return HistoryRecord(
      id: id,
      timestamp: record.timestamp,
      temperature: record.temperature,
      humidity: record.humidity,
      dewPoint: record.dewPoint,
      weather: record.weather,
      mode: record.mode,
      fanStatus: record.fanStatus,
      heaterStatus: record.heaterStatus,
      dehumidifierStatus: record.dehumidifierStatus,
    );
  }

  Future<List<HistoryRecord>> getHistoryRecords({int limit = 100}) async {
    final db = await instance.database;
    final result = await db.query(
      'history_records',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((map) => HistoryRecord.fromMap(map)).toList();
  }

  Future<List<HistoryRecord>> getHistoryRecordsByTimeRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'history_records',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => HistoryRecord.fromMap(map)).toList();
  }

  Future<int> deleteHistoryRecord(int id) async {
    final db = await instance.database;
    return await db.delete(
      'history_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllHistoryRecords() async {
    final db = await instance.database;
    return await db.delete('history_records');
  }

  Future<int> getHistoryRecordCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM history_records');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> insertAlertLog(String type, String message) async {
    final db = await instance.database;
    await db.insert('alert_logs', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': type,
      'message': message,
    });
  }

  Future<List<Map<String, dynamic>>> getAlertLogs({int limit = 50}) async {
    final db = await instance.database;
    return await db.query(
      'alert_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  Future<int> clearAllAlertLogs() async {
    final db = await instance.database;
    return await db.delete('alert_logs');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
