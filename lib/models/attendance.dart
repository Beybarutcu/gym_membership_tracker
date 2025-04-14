import 'package:intl/intl.dart';

class Attendance {
  final int? id;
  final int memberId;
  final String lessonType;
  final DateTime dateTime;
  String? memberName; // Optional, for display purposes

  Attendance({
    this.id,
    required this.memberId,
    required this.lessonType,
    required this.dateTime,
    this.memberName,
  });

  Map<String, dynamic> toMap() {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return {
      'id': id,
      'member_id': memberId,
      'lesson_type': lessonType,
      'date': dateFormat.format(dateTime),
    };
  }

  static Attendance fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      memberId: map['member_id'],
      lessonType: map['lesson_type'],
      dateTime: DateTime.parse(map['date']),
      memberName: map['name'], // May be null if not joined with members table
    );
  }
}
