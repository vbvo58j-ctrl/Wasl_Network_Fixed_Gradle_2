import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
class LocalDatabase {
  LocalDatabase._();
  static final instance = LocalDatabase._();
  Database? _database;
  Future<Database> get db async {
    if (_database != null) return _database!;
    _database = await openDatabase(p.join(await getDatabasesPath(),'wasl.db'),version:1,
      onCreate:(db,_) async {
        await db.execute('CREATE TABLE rooms(id TEXT PRIMARY KEY,name TEXT,code TEXT,owner INTEGER,created TEXT)');
        await db.execute('CREATE TABLE devices(id TEXT PRIMARY KEY,name TEXT,address TEXT,room_id TEXT,approved INTEGER,blocked INTEGER,last_seen TEXT)');
        await db.execute('CREATE TABLE messages(id INTEGER PRIMARY KEY AUTOINCREMENT,room_id TEXT,sender TEXT,body TEXT,created TEXT,attachment TEXT)');
      });
    return _database!;
  }
  Future<void> saveRoom(Map<String,Object?> row) async => (await db).insert('rooms',row,conflictAlgorithm:ConflictAlgorithm.replace);
  Future<List<Map<String,Object?>>> rooms() async => (await db).query('rooms',orderBy:'created DESC');
  Future<void> saveMessage(Map<String,Object?> row) async => (await db).insert('messages',row);
  Future<List<Map<String,Object?>>> messages(String id) async => (await db).query('messages',where:'room_id=?',whereArgs:[id],orderBy:'created ASC');
}
