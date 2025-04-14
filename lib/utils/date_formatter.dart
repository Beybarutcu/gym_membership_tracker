import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _defaultDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _displayDateTimeFormat = DateFormat('MMM d, yyyy - h:mm a');
  static final DateFormat _sqliteDateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  
  // Format date for display (e.g., "Jan 1, 2025")
  static String formatDate(DateTime date) {
    return _displayDateFormat.format(date);
  }
  
  // Format date and time for display (e.g., "Jan 1, 2025 - 2:30 PM")
  static String formatDateTime(DateTime dateTime) {
    return _displayDateTimeFormat.format(dateTime);
  }
  
  // Format date for SQLite storage (e.g., "2025-01-01")
  static String formatForStorage(DateTime date) {
    return _defaultDateFormat.format(date);
  }
  
  // Format date and time for SQLite storage (e.g., "2025-01-01 14:30:00")
  static String formatDateTimeForStorage(DateTime dateTime) {
    return _sqliteDateTimeFormat.format(dateTime);
  }
  
  // Parse date from SQLite format
  static DateTime parseDate(String dateString) {
    return _defaultDateFormat.parse(dateString);
  }
  
  // Parse date and time from SQLite format
  static DateTime parseDateTime(String dateTimeString) {
    return _sqliteDateTimeFormat.parse(dateTimeString);
  }
  
  // Get the number of days between two dates
  static int daysBetween(DateTime from, DateTime to) {
    final fromDate = DateTime(from.year, from.month, from.day);
    final toDate = DateTime(to.year, to.month, to.day);
    return toDate.difference(fromDate).inDays;
  }
  
  // Get the first day of the month
  static DateTime firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }
  
  // Get the last day of the month
  static DateTime lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }
  
  // Get a date range as a list of dates
  static List<DateTime> getDateRange(DateTime start, DateTime end) {
    final List<DateTime> days = [];
    for (int i = 0; i <= daysBetween(start, end); i++) {
      days.add(start.add(Duration(days: i)));
    }
    return days;
  }
}
