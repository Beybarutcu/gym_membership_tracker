class Lesson {
  final String type;
  final String? description;
  final int? durationMinutes;
  
  Lesson({
    required this.type,
    this.description,
    this.durationMinutes,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'description': description,
      'duration_minutes': durationMinutes,
    };
  }
  
  static Lesson fromMap(Map<String, dynamic> map) {
    return Lesson(
      type: map['type'],
      description: map['description'],
      durationMinutes: map['duration_minutes'],
    );
  }
}
