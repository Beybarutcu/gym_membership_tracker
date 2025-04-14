import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import 'database_service.dart';

class MemberService {
  final DatabaseService _databaseService = DatabaseService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  
  // Get all members
  Future<List<Member>> getAllMembers() async {
    try {
      final db = await _databaseService.database;
      final maps = await db.query('members');
      
      return _processMembers(maps);
    } catch (e) {
      print('Error getting all members: $e');
      return [];
    }
  }
  
  // Get a single member by ID
  Future<Member?> getMemberById(int id) async {
    try {
      final db = await _databaseService.database;
      final maps = await db.query(
        'members',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isEmpty) return null;
      
      final member = Member.fromMap(maps.first);
      await _loadMemberLessons(member);
      await _loadMemberLessonSessions(member);
      
      return member;
    } catch (e) {
      print('Error getting member by ID: $e');
      return null;
    }
  }
  
  // Search members by name or phone
  Future<List<Member>> searchMembers(String query) async {
    try {
      final db = await _databaseService.database;
      final maps = await db.query(
        'members',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
      );
      
      return _processMembers(maps);
    } catch (e) {
      print('Error searching members: $e');
      return [];
    }
  }
  
  // Add a new member
  Future<int> addMember(Member member, List<String> selectedLessons, Map<String, int> lessonSessions) async {
    try {
      final db = await _databaseService.database;
      
      // Transaction to ensure all operations succeed or fail together
      return await db.transaction((txn) async {
        // Insert member
        final memberId = await txn.insert('members', member.toMap());
        
        // Insert lessons
        for (var lesson in selectedLessons) {
          await txn.insert('member_lessons', {
            'member_id': memberId,
            'lesson_type': lesson,
          });
        }
        
        // Insert lesson sessions
        for (var entry in lessonSessions.entries) {
          if (entry.value > 0) {
            await txn.insert('lesson_sessions', {
              'member_id': memberId,
              'lesson_type': entry.key,
              'remaining_sessions': entry.value,
            });
          }
        }
        
        return memberId;
      });
    } catch (e) {
      print('Error adding member: $e');
      return -1;
    }
  }
  
  // Update an existing member
  Future<bool> updateMember(Member member, List<String> selectedLessons, Map<String, int> lessonSessions) async {
    try {
      final db = await _databaseService.database;
      
      // Transaction to ensure all operations succeed or fail together
      await db.transaction((txn) async {
        // Update member info
        await txn.update(
          'members',
          member.toMap(),
          where: 'id = ?',
          whereArgs: [member.id],
        );
        
        // Delete existing lessons
        await txn.delete(
          'member_lessons',
          where: 'member_id = ?',
          whereArgs: [member.id],
        );
        
        // Insert new lessons
        for (var lesson in selectedLessons) {
          await txn.insert('member_lessons', {
            'member_id': member.id,
            'lesson_type': lesson,
          });
        }
        
        // Update lesson sessions
        for (var entry in lessonSessions.entries) {
          // First try to update existing sessions
          final count = await txn.update(
            'lesson_sessions',
            {'remaining_sessions': entry.value},
            where: 'member_id = ? AND lesson_type = ?',
            whereArgs: [member.id, entry.key],
          );
          
          // If no rows updated, insert new session
          if (count == 0 && entry.value > 0) {
            await txn.insert('lesson_sessions', {
              'member_id': member.id,
              'lesson_type': entry.key,
              'remaining_sessions': entry.value,
            });
          } else if (entry.value <= 0) {
            // If sessions <= 0, delete the record
            await txn.delete(
              'lesson_sessions',
              where: 'member_id = ? AND lesson_type = ?',
              whereArgs: [member.id, entry.key],
            );
          }
        }
      });
      
      return true;
    } catch (e) {
      print('Error updating member: $e');
      return false;
    }
  }
  
  // Delete a member and all associated data
  Future<bool> deleteMember(int id) async {
    try {
      final db = await _databaseService.database;
      
      // Transaction to ensure all operations succeed or fail together
      await db.transaction((txn) async {
        // Delete attendance records
        await txn.delete(
          'attendance',
          where: 'member_id = ?',
          whereArgs: [id],
        );
        
        // Delete lesson sessions
        await txn.delete(
          'lesson_sessions',
          where: 'member_id = ?',
          whereArgs: [id],
        );
        
        // Delete member lessons
        await txn.delete(
          'member_lessons',
          where: 'member_id = ?',
          whereArgs: [id],
        );
        
        // Delete member
        await txn.delete(
          'members',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      
      return true;
    } catch (e) {
      print('Error deleting member: $e');
      return false;
    }
  }
  
  // Decrease remaining sessions for a specific lesson type
  Future<bool> decreaseRemainingSessions(int memberId, String lessonType) async {
    try {
      final db = await _databaseService.database;
      
      // Get current sessions first
      final sessions = await db.query(
        'lesson_sessions',
        where: 'member_id = ? AND lesson_type = ?',
        whereArgs: [memberId, lessonType],
      );
      
      if (sessions.isEmpty) return false;
      
      final currentSessions = sessions.first['remaining_sessions'] as int;
      if (currentSessions <= 0) return false;
      
      // Decrease sessions by 1
      await db.update(
        'lesson_sessions',
        {'remaining_sessions': currentSessions - 1},
        where: 'member_id = ? AND lesson_type = ?',
        whereArgs: [memberId, lessonType],
      );
      
      return true;
    } catch (e) {
      print('Error decreasing sessions: $e');
      return false;
    }
  }
  
  // Get members with soon-to-expire memberships
  Future<List<Member>> getExpiringMemberships(int daysThreshold) async {
    try {
      final db = await _databaseService.database;
      
      final now = DateTime.now();
      final threshold = now.add(Duration(days: daysThreshold));
      
      final nowStr = _dateFormat.format(now);
      final thresholdStr = _dateFormat.format(threshold);
      
      final maps = await db.rawQuery('''
        SELECT * FROM members 
        WHERE end_date IS NOT NULL 
        AND end_date BETWEEN ? AND ? 
        AND (membership_type = 'Monthly' OR has_monthly_membership = 1)
      ''', [nowStr, thresholdStr]);
      
      return _processMembers(maps);
    } catch (e) {
      print('Error getting expiring memberships: $e');
      return [];
    }
  }
  
  // Get members with low session counts
  Future<List<Member>> getMembersWithLowSessions(int threshold) async {
    try {
      final db = await _databaseService.database;
      
      final maps = await db.rawQuery('''
        SELECT DISTINCT m.* FROM members m
        JOIN lesson_sessions ls ON m.id = ls.member_id
        WHERE ls.remaining_sessions <= ? AND ls.remaining_sessions > 0
      ''', [threshold]);
      
      return _processMembers(maps);
    } catch (e) {
      print('Error getting members with low sessions: $e');
      return [];
    }
  }
  
  // Get all available lesson types
  Future<List<String>> getAllLessonTypes() async {
    try {
      final db = await _databaseService.database;
      
      // Check if the lesson_types table exists
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='lesson_types'");
      
      if (tables.isEmpty) {
        // Table doesn't exist, create it and add default lessons
        await db.execute('''
          CREATE TABLE lesson_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT UNIQUE
          )
        ''');
        
        // Add default lesson types
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
        
        return defaultLessons;
      }
      
      // Get lesson types from the database
      final results = await db.query('lesson_types', columns: ['type']);
      return results.map((e) => e['type'] as String).toList();
    } catch (e) {
      print('Error getting lesson types: $e');
      
      // Return default lesson types as fallback
      return [
        'Zumba',
        'Pilates',
        'Fitness',
        'Karma',
        'Bungee',
        'Yoga',
        'Reformer'
      ];
    }
  }
  
  // Add a new lesson type
  Future<bool> addLessonType(String lessonType) async {
    try {
      // Get a reference to the database
      final db = await _databaseService.database;
      
      // Check if the lesson_types table exists
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='lesson_types'");
      
      if (tables.isEmpty) {
        // Table doesn't exist, create it
        await db.execute('''
          CREATE TABLE lesson_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT UNIQUE
          )
        ''');
      }
      
      // Check if the lesson already exists
      final existing = await db.query(
        'lesson_types',
        where: 'type = ?',
        whereArgs: [lessonType],
      );
      
      if (existing.isNotEmpty) {
        return false; // Lesson type already exists
      }
      
      // Insert the new lesson type
      await db.insert('lesson_types', {'type': lessonType});
      
      return true;
    } catch (e) {
      print('Error adding lesson type: $e');
      return false;
    }
  }
  
  // Remove a lesson type
  Future<bool> removeLessonType(String lessonType) async {
    try {
      // Get a reference to the database
      final db = await _databaseService.database;
      
      // Check if the lesson_types table exists
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='lesson_types'");
      if (tables.isEmpty) {
        // Table doesn't exist, so we can't remove anything
        return false;
      }
      
      // Start a transaction to ensure all operations succeed or fail together
      await db.transaction((txn) async {
        // Delete from lesson_types table
        await txn.delete(
          'lesson_types',
          where: 'type = ?',
          whereArgs: [lessonType],
        );
        
        // Delete from member_lessons table
        await txn.delete(
          'member_lessons',
          where: 'lesson_type = ?',
          whereArgs: [lessonType],
        );
        
        // Delete from lesson_sessions table
        await txn.delete(
          'lesson_sessions',
          where: 'lesson_type = ?',
          whereArgs: [lessonType],
        );
        
        // Note: We're not deleting attendance records to preserve history
        // If you want to delete them too, uncomment the following:
        /*
        await txn.delete(
          'attendance',
          where: 'lesson_type = ?',
          whereArgs: [lessonType],
        );
        */
      });
      
      return true;
    } catch (e) {
      print('Error removing lesson type: $e');
      return false;
    }
  }
  
  // Update a lesson type name
  Future<bool> updateLessonType(String oldName, String newName) async {
    try {
      // Get a reference to the database
      final db = await _databaseService.database;
      
      // Check if the lesson_types table exists
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='lesson_types'");
      if (tables.isEmpty) {
        // Table doesn't exist, so we can't update anything
        return false;
      }
      
      // Check if the new name already exists
      final existing = await db.query(
        'lesson_types',
        where: 'type = ?',
        whereArgs: [newName],
      );
      
      if (existing.isNotEmpty) {
        return false; // New name already exists
      }
      
      // Start a transaction to ensure all operations succeed or fail together
      await db.transaction((txn) async {
        // Update the lesson type in lesson_types table
        await txn.update(
          'lesson_types',
          {'type': newName},
          where: 'type = ?',
          whereArgs: [oldName],
        );
        
        // Update references in member_lessons table
        await txn.update(
          'member_lessons',
          {'lesson_type': newName},
          where: 'lesson_type = ?',
          whereArgs: [oldName],
        );
        
        // Update references in lesson_sessions table
        await txn.update(
          'lesson_sessions',
          {'lesson_type': newName},
          where: 'lesson_type = ?',
          whereArgs: [oldName],
        );
        
        // Update references in attendance table
        await txn.update(
          'attendance',
          {'lesson_type': newName},
          where: 'lesson_type = ?',
          whereArgs: [oldName],
        );
      });
      
      return true;
    } catch (e) {
      print('Error updating lesson type: $e');
      return false;
    }
  }
  
  // Helper method to process multiple members
  Future<List<Member>> _processMembers(List<Map<String, dynamic>> maps) async {
    final members = List.generate(maps.length, (i) => Member.fromMap(maps[i]));
    
    for (var member in members) {
      await _loadMemberLessons(member);
      await _loadMemberLessonSessions(member);
    }
    
    return members;
  }
  
  // Load lessons for a member
  Future<void> _loadMemberLessons(Member member) async {
    try {
      final db = await _databaseService.database;
      
      final lessonMaps = await db.query(
        'member_lessons',
        where: 'member_id = ?',
        whereArgs: [member.id],
      );
      
      member.lessons = List.generate(
        lessonMaps.length, 
        (i) => lessonMaps[i]['lesson_type'] as String
      );
    } catch (e) {
      print('Error loading member lessons: $e');
      member.lessons = [];
    }
  }
  
  // Load lesson sessions for a member
  Future<void> _loadMemberLessonSessions(Member member) async {
    try {
      final db = await _databaseService.database;
      
      final sessionMaps = await db.query(
        'lesson_sessions',
        where: 'member_id = ?',
        whereArgs: [member.id],
      );
      
      member.lessonSessions.clear();
      for (var map in sessionMaps) {
        final lessonType = map['lesson_type'] as String;
        final sessions = map['remaining_sessions'] as int;
        member.lessonSessions[lessonType] = sessions;
      }
    } catch (e) {
      print('Error loading member lesson sessions: $e');
      member.lessonSessions.clear();
    }
  }
}