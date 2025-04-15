import 'dart:io';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

// For desktop platforms
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    // Open the database
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gym_membership.db');
    
    // REMOVED: Delete existing database line
    // This was causing all your data to be lost on restart
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create members table with the new has_monthly_membership column
    await db.execute('''
      CREATE TABLE members(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        phone TEXT,
        membership_type TEXT,
        has_monthly_membership INTEGER,
        start_date TEXT,
        monthly_start_date TEXT,
        end_date TEXT,
        monthly_end_date TEXT,
        remaining_sessions INTEGER
      )
    ''');
    
    // Create lesson_types table
    await db.execute('''
      CREATE TABLE lesson_types(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT UNIQUE
      )
    ''');
    
    // Create lesson_sessions table
    await db.execute('''
      CREATE TABLE lesson_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER,
        lesson_type TEXT,
        remaining_sessions INTEGER,
        FOREIGN KEY (member_id) REFERENCES members(id),
        UNIQUE(member_id, lesson_type)
      )
    ''');
    
    // Create member_lessons table
    await db.execute('''
      CREATE TABLE member_lessons(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER,
        lesson_type TEXT,
        FOREIGN KEY (member_id) REFERENCES members (id)
      )
    ''');
    
    // Create attendance table
    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER,
        lesson_type TEXT,
        date TEXT,
        FOREIGN KEY (member_id) REFERENCES members (id)
      )
    ''');
    
    // Add sample data
    await _addSampleData(db);
  }
  
  Future<void> _addSampleData(Database db) async {
    // Insert default lesson types
    final defaultLessons = [
      'Zumba',
      'Pilates',
      'Fitness',
      'Karma',
      'Bungee',
      'Yoga',
      'Reformer'
    ];
    
    for (var lesson in defaultLessons) {
      await db.insert('lesson_types', {'type': lesson});
    }
    
    // Get current date and next month date
    final now = DateTime.now();
    final nextMonth = now.add(const Duration(days: 30));
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    // Insert sample members
    final member1Id = await db.insert('members', {
      'name': 'Ayşe Yılmaz',
      'phone': '555-1234',
      'membership_type': 'Monthly',
      'has_monthly_membership': 1,
      'start_date': dateFormat.format(now),
      'monthly_start_date': dateFormat.format(now),
      'end_date': dateFormat.format(nextMonth),
      'monthly_end_date': dateFormat.format(nextMonth),
      'remaining_sessions': null,
    });
    
    final member2Id = await db.insert('members', {
      'name': 'Mehmet Demir',
      'phone': '555-5678',
      'membership_type': 'Package',
      'has_monthly_membership': 0,
      'start_date': dateFormat.format(now),
      'monthly_start_date': null,
      'end_date': null,
      'monthly_end_date': null,
      'remaining_sessions': 10,
    });
    
    final member3Id = await db.insert('members', {
      'name': 'Zeynep Kaya',
      'phone': '555-9012',
      'membership_type': 'Monthly',
      'has_monthly_membership': 1,
      'start_date': dateFormat.format(now),
      'monthly_start_date': dateFormat.format(now),
      'end_date': dateFormat.format(nextMonth),
      'monthly_end_date': dateFormat.format(nextMonth),
      'remaining_sessions': null,
    });
    
    // Insert sample lessons
    await db.insert('member_lessons', {
      'member_id': member1Id,
      'lesson_type': 'Yoga',
    });
    
    await db.insert('member_lessons', {
      'member_id': member1Id,
      'lesson_type': 'Pilates',
    });
    
    await db.insert('member_lessons', {
      'member_id': member2Id,
      'lesson_type': 'Fitness',
    });
    
    await db.insert('member_lessons', {
      'member_id': member2Id,
      'lesson_type': 'Bungee',
    });
    
    await db.insert('member_lessons', {
      'member_id': member3Id,
      'lesson_type': 'Yoga',
    });
    
    await db.insert('member_lessons', {
      'member_id': member3Id,
      'lesson_type': 'Zumba',
    });
    
    // Insert sample lesson sessions
    await db.insert('lesson_sessions', {
      'member_id': member1Id,
      'lesson_type': 'Zumba',
      'remaining_sessions': 5,
    });
    
    await db.insert('lesson_sessions', {
      'member_id': member2Id,
      'lesson_type': 'Fitness',
      'remaining_sessions': 10,
    });
    
    await db.insert('lesson_sessions', {
      'member_id': member2Id,
      'lesson_type': 'Pilates',
      'remaining_sessions': 8,
    });
    
    await db.insert('lesson_sessions', {
      'member_id': member3Id,
      'lesson_type': 'Yoga',
      'remaining_sessions': 3,
    });
    
    // Insert sample attendance
    final yesterday = dateFormat.format(now.subtract(const Duration(days: 1)));
    await db.insert('attendance', {
      'member_id': member1Id,
      'lesson_type': 'Yoga',
      'date': '$yesterday 18:30:00',
    });
  }
}