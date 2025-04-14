class CalendarEvent {
  final int id;
  final int memberId;
  final String memberName;
  final String lessonType;
  final DateTime dateTime;
  
  CalendarEvent({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.lessonType,
    required this.dateTime,
  });
  
  // Create a CalendarEvent from an attendance record
  static CalendarEvent fromAttendance(Map<String, dynamic> attendance) {
    return CalendarEvent(
      id: attendance['id'],
      memberId: attendance['member_id'],
      memberName: attendance['name'] ?? 'Unknown',
      lessonType: attendance['lesson_type'],
      dateTime: DateTime.parse(attendance['date']),
    );
  }
}
