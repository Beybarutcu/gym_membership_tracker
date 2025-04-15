import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class ReportService {
  final DatabaseService _databaseService = DatabaseService();
  
  // Get membership summary
  Future<Map<String, dynamic>> getMembershipSummary() async {
    final db = await _databaseService.database;
    
    // Get total member count
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM members');
    final totalMembers = Sqflite.firstIntValue(totalResult) ?? 0;
    
    // Get monthly members count
    final monthlyResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM members WHERE membership_type = 'Monthly'"
    );
    final monthlyMembers = Sqflite.firstIntValue(monthlyResult) ?? 0;
    
    // Get package members count
    final packageResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM members WHERE membership_type = 'Package'"
    );
    final packageMembers = Sqflite.firstIntValue(packageResult) ?? 0;
    
    return {
      'totalMembers': totalMembers,
      'monthlyMembers': monthlyMembers,
      'packageMembers': packageMembers,
    };
  }
  
  // Get attendance summary
  Future<Map<String, dynamic>> getAttendanceSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _databaseService.database;
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    String whereClause = "";
    List<String> whereArgs = [];
    
    if (startDate != null && endDate != null) {
      whereClause = "WHERE date BETWEEN ? AND ?";
      whereArgs = [
        "${dateFormat.format(startDate)} 00:00:00", 
        "${dateFormat.format(endDate)} 23:59:59"
      ];
    } else if (startDate != null) {
      whereClause = "WHERE date >= ?";
      whereArgs = ["${dateFormat.format(startDate)} 00:00:00"];
    } else if (endDate != null) {
      whereClause = "WHERE date <= ?";
      whereArgs = ["${dateFormat.format(endDate)} 23:59:59"];
    }
    
    // Get total attendance count
    final totalQuery = 'SELECT COUNT(*) as count FROM attendance $whereClause';
    final totalResult = await db.rawQuery(totalQuery, whereArgs);
    final totalAttendance = Sqflite.firstIntValue(totalResult) ?? 0;
    
    // Get attendance by lesson type
    final byLessonQuery = '''
      SELECT lesson_type, COUNT(*) as count 
      FROM attendance 
      $whereClause
      GROUP BY lesson_type 
      ORDER BY count DESC
    ''';
    final lessonResult = await db.rawQuery(byLessonQuery, whereArgs);
    
    // Get unique members who attended
    final uniqueMembersQuery = '''
      SELECT COUNT(DISTINCT member_id) as count 
      FROM attendance 
      $whereClause
    ''';
    final uniqueResult = await db.rawQuery(uniqueMembersQuery, whereArgs);
    final uniqueMembers = Sqflite.firstIntValue(uniqueResult) ?? 0;
    
    return {
      'totalAttendance': totalAttendance,
      'uniqueMembers': uniqueMembers,
      'byLessonType': lessonResult,
    };
  }
  
  // Get expiring memberships report
  // FIXED: Updated to use membership_type and end_date
  Future<List<Map<String, dynamic>>> getExpiringMemberships(int daysThreshold) async {
    final db = await _databaseService.database;
    
    final now = DateTime.now();
    final threshold = now.add(Duration(days: daysThreshold));
    
    // Format dates for SQLite
    final nowStr = now.toIso8601String().split('T')[0];
    final thresholdStr = threshold.toIso8601String().split('T')[0];
    
    // Updated query to use membership_type instead of has_monthly_membership
    return await db.rawQuery('''
      SELECT m.id, m.name, m.phone, m.end_date,
             (julianday(m.end_date) - julianday('$nowStr')) as days_left
      FROM members m
      WHERE m.membership_type = 'Monthly' 
      AND m.end_date BETWEEN ? AND ?
      ORDER BY days_left ASC
    ''', [nowStr, thresholdStr]);
  }
  
  // Get membership expiry trend
  Future<List<Map<String, dynamic>>> getExpiryTrend(int monthsAhead) async {
    final db = await _databaseService.database;
    final now = DateTime.now();
    
    List<Map<String, dynamic>> result = [];
    
    for (int i = 0; i < monthsAhead; i++) {
      final month = now.add(Duration(days: 30 * i));
      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0); // Last day of month
      
      final startStr = monthStart.toIso8601String().split('T')[0];
      final endStr = monthEnd.toIso8601String().split('T')[0];
      
      const expiryQuery = '''
        SELECT COUNT(*) as count
        FROM members
        WHERE membership_type = 'Monthly' 
        AND end_date BETWEEN ? AND ?
      ''';
      
      final expiryResult = await db.rawQuery(expiryQuery, [startStr, endStr]);
      final count = Sqflite.firstIntValue(expiryResult) ?? 0;
      
      result.add({
        'month': DateFormat('MMM yyyy').format(month),
        'count': count,
      });
    }
    
    return result;
  }
  
  // Get low session members (package members with few remaining sessions)
  Future<List<Map<String, dynamic>>> getLowSessionMembers(int threshold) async {
    final db = await _databaseService.database;
    
    return await db.rawQuery('''
      SELECT m.id, m.name, m.phone, m.remaining_sessions
      FROM members m
      WHERE m.membership_type = 'Package' 
      AND m.remaining_sessions <= ?
      AND m.remaining_sessions > 0
      ORDER BY m.remaining_sessions ASC
    ''', [threshold]);
  }
  
  // Get revenue report (if you were tracking payments)
  // This is just a placeholder since the original spec didn't mention payments
  Future<Map<String, dynamic>> getRevenueReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Placeholder for a revenue report
    // Would need to add a payments table to actually implement this
    return {
      'totalRevenue': 0,
      'byMembershipType': [],
      'byMonth': [],
    };
  }
}