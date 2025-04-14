import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../models/calendar_event.dart';
import 'database_service.dart';
import 'member_service.dart';

class AttendanceService {
  final DatabaseService _databaseService = DatabaseService();
  final MemberService _memberService = MemberService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  // UPDATED: Modified to check both monthly and package lessons
  Future<bool> recordAttendance(int memberId, String lessonType) async {
    // First check if the member exists
    final member = await _memberService.getMemberById(memberId);
    if (member == null) {
      return false;
    }
    
    final db = await _databaseService.database;
    
    // Check if the member can attend this lesson
    bool canAttend = false;
    bool usePackage = false;
    
    // First check monthly membership
    if (member.isMonthlyMembershipActive() && member.lessons.contains(lessonType)) {
      canAttend = true;
      usePackage = false;
    } 
    // If not available through monthly, check package lessons
    else if (member.hasActivePackageForLesson(lessonType)) {
      canAttend = true;
      usePackage = true;
    }
    
    if (!canAttend) {
      return false;
    }
    
    // If using a package, decrease the session count
    if (usePackage) {
      bool success = await _memberService.decreaseRemainingSessions(memberId, lessonType);
      if (!success) {
        return false;
      }
    }
    
    // Record attendance
    final Attendance attendance = Attendance(
      memberId: memberId,
      lessonType: lessonType,
      dateTime: DateTime.now(),
    );
    
    await db.insert('attendance', attendance.toMap());
    
    return true;
  }
  
  // Force record attendance (admin override)
  Future<bool> forceRecordAttendance(int memberId, String lessonType) async {
    // This function allows recording attendance regardless of membership status
    final member = await _memberService.getMemberById(memberId);
    if (member == null) {
      return false;
    }
    
    final db = await _databaseService.database;
    
    // Record attendance
    final Attendance attendance = Attendance(
      memberId: memberId,
      lessonType: lessonType,
      dateTime: DateTime.now(),
    );
    
    await db.insert('attendance', attendance.toMap());
    
    return true;
  }
  
  // Get attendance records for a specific member
  Future<List<Attendance>> getMemberAttendance(int memberId) async {
    final db = await _databaseService.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'member_id = ?',
      whereArgs: [memberId],
      orderBy: 'date DESC',
    );
    
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }
  
  // Get attendance records for a specific date
  Future<List<CalendarEvent>> getAttendanceByDate(DateTime date) async {
    final db = await _databaseService.database;
    
    // Format date range (start of day to end of day)
    final startDate = _dateFormat.format(DateTime(date.year, date.month, date.day));
    final endDate = _dateFormat.format(DateTime(date.year, date.month, date.day, 23, 59, 59));
    
    // Query with join to get member names
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT a.id, a.member_id, a.lesson_type, a.date, m.name
      FROM attendance a
      JOIN members m ON a.member_id = m.id
      WHERE a.date BETWEEN '$startDate 00:00:00' AND '$endDate 23:59:59'
      ORDER BY a.date
    ''');
    
    return List.generate(maps.length, (i) => CalendarEvent.fromAttendance(maps[i]));
  }
  
  // Get all attendance records with member information
  Future<List<Map<String, dynamic>>> getAllAttendanceWithMemberInfo() async {
    final db = await _databaseService.database;
    
    return await db.rawQuery('''
      SELECT a.id, a.member_id, a.lesson_type, a.date, m.name
      FROM attendance a
      JOIN members m ON a.member_id = m.id
      ORDER BY a.date DESC
    ''');
  }
  
  // Delete an attendance record
  Future<void> deleteAttendance(int id) async {
    final db = await _databaseService.database;
    
    await db.delete(
      'attendance',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // Get attendance count by lesson type
  Future<Map<String, int>> getAttendanceCountByLessonType() async {
    final db = await _databaseService.database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT lesson_type, COUNT(*) as count
      FROM attendance
      GROUP BY lesson_type
      ORDER BY count DESC
    ''');
    
    final Map<String, int> result = {};
    for (var map in maps) {
      result[map['lesson_type']] = map['count'];
    }
    
    return result;
  }
  
  // Get attendance statistics for a specific period
  Future<Map<String, dynamic>> getAttendanceStats(DateTime startDate, DateTime endDate) async {
    final db = await _databaseService.database;
    
    // Format dates for SQLite
    final startStr = _dateFormat.format(startDate);
    final endStr = _dateFormat.format(endDate);
    
    // Get total attendance count
    final countResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM attendance
      WHERE date BETWEEN '$startStr 00:00:00' AND '$endStr 23:59:59'
    ''');
    
    final int totalCount = Sqflite.firstIntValue(countResult) ?? 0;
    
    // Get unique member count
    final uniqueResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT member_id) as count FROM attendance
      WHERE date BETWEEN '$startStr 00:00:00' AND '$endStr 23:59:59'
    ''');
    
    final int uniqueMembers = Sqflite.firstIntValue(uniqueResult) ?? 0;
    
    // Get counts by lesson type
    final lessonResult = await db.rawQuery('''
      SELECT lesson_type, COUNT(*) as count FROM attendance
      WHERE date BETWEEN '$startStr 00:00:00' AND '$endStr 23:59:59'
      GROUP BY lesson_type
      ORDER BY count DESC
    ''');
    
    return {
      'totalAttendance': totalCount,
      'uniqueMembers': uniqueMembers,
      'byLessonType': lessonResult,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}