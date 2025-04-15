import 'package:intl/intl.dart';

class Member {
  // Core properties
  final int? id;
  final String name;
  final String phone;
  
  // Membership properties
  String membershipType; // 'Monthly' or 'Package'
  DateTime startDate;
  DateTime? endDate;
  int? remainingSessions;
  bool hasMonthlyMembership; // For compatibility with the other schema
  
  // Associated data
  List<String> lessons = [];
  Map<String, int> lessonSessions = {};
  
  Member({
    this.id,
    required this.name,
    required this.phone,
    String? membershipType,
    required this.startDate,
    this.endDate,
    this.remainingSessions,
    bool? hasMonthlyMembership,
  }) : 
    membershipType = membershipType ?? 'Monthly',
    hasMonthlyMembership = hasMonthlyMembership ?? (membershipType == 'Monthly');

  // For fromMap with older schema
  static Member fromMap(Map<String, dynamic> map) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    // Determine membership type
    String membershipType;
    bool hasMonthly = false;
    
    if (map.containsKey('membership_type')) {
      membershipType = map['membership_type'] ?? 'Monthly';
      hasMonthly = membershipType == 'Monthly';
    } else if (map.containsKey('has_monthly_membership')) {
      hasMonthly = map['has_monthly_membership'] == 1;
      membershipType = hasMonthly ? 'Monthly' : 'Package';
    } else {
      // Default
      membershipType = 'Monthly';
      hasMonthly = true;
    }
    
    // Parse dates safely
    DateTime startDate = DateTime.now();
    if (map.containsKey('start_date') && map['start_date'] != null) {
      try {
        startDate = dateFormat.parse(map['start_date']);
      } catch (e) {
        print('Error parsing start_date: $e');
      }
    } else if (map.containsKey('monthly_start_date') && map['monthly_start_date'] != null) {
      try {
        startDate = dateFormat.parse(map['monthly_start_date']);
      } catch (e) {
        print('Error parsing monthly_start_date: $e');
      }
    }
    
    // Parse end date
    DateTime? endDate;
    if (map.containsKey('end_date') && map['end_date'] != null) {
      try {
        endDate = dateFormat.parse(map['end_date']);
      } catch (e) {
        print('Error parsing end_date: $e');
      }
    } else if (map.containsKey('monthly_end_date') && map['monthly_end_date'] != null) {
      try {
        endDate = dateFormat.parse(map['monthly_end_date']);
      } catch (e) {
        print('Error parsing monthly_end_date: $e');
      }
    }
    
    return Member(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      membershipType: membershipType,
      hasMonthlyMembership: hasMonthly,
      startDate: startDate,
      endDate: endDate,
      remainingSessions: map['remaining_sessions'],
    );
  }

  // For toMap with support for both schemas
Map<String, dynamic> toMap() {
  final dateFormat = DateFormat('yyyy-MM-dd');
  
  return {
    'id': id,
    'name': name,
    'phone': phone,
    'membership_type': membershipType,
    'has_monthly_membership': hasMonthlyMembership ? 1 : 0,
    'start_date': dateFormat.format(startDate),
    'monthly_start_date': hasMonthlyMembership ? dateFormat.format(startDate) : null,
    'end_date': endDate != null ? dateFormat.format(endDate!) : null,
    'monthly_end_date': hasMonthlyMembership && endDate != null ? dateFormat.format(endDate!) : null,
    'remaining_sessions': remainingSessions,
  };
}

  // Basic status calculation
  String get statusText {
    if (membershipType == 'Monthly' || hasMonthlyMembership) {
      if (endDate == null) return 'Invalid';
      if (endDate!.isBefore(DateTime.now())) return 'Expired';
      
      final daysLeft = endDate!.difference(DateTime.now()).inDays;
      return 'Active ($daysLeft days left)';
    } else {
      if (remainingSessions == null) return 'Invalid';
      if (remainingSessions! <= 0) return 'No sessions left';
      
      return 'Active ($remainingSessions sessions left)';
    }
  }
  
  // Additional status texts required by check_in_screen.dart
  String get generalStatusText {
    if (hasMonthlyMembership) {
      return monthlyStatusText;
    } else {
      if (remainingSessions == null) return 'Invalid Package';
      if (remainingSessions! <= 0) return 'No sessions left';
      return 'Package ($remainingSessions sessions)';
    }
  }
  
  String get monthlyStatusText {
    if (!hasMonthlyMembership) return 'Not a monthly membership';
    if (endDate == null) return 'Invalid Monthly Membership';
    if (endDate!.isBefore(DateTime.now())) return 'Expired';
    
    final daysLeft = endDate!.difference(DateTime.now()).inDays;
    return 'Monthly ($daysLeft days left)';
  }

  // Validity check
  bool get isValid {
    bool monthlyValid = false;
    bool packageValid = false;
    
    // Check monthly membership validity
    if (hasMonthlyMembership) {
      if (endDate != null && endDate!.isAfter(DateTime.now())) {
        monthlyValid = true;
      }
    }
    
    // Check package validity
    bool hasAnyPackage = lessonSessions.values.any((sessions) => sessions > 0);
    if (hasAnyPackage) {
      packageValid = true;
    }
    
    // Member is valid if either membership type is valid
    return monthlyValid || packageValid;
  }
  
  // Compatibility methods for edit_member_screen.dart
  DateTime? get monthlyStartDate => hasMonthlyMembership ? startDate : null;
  DateTime? get monthlyEndDate => hasMonthlyMembership ? endDate : null;
  
  // UPDATED: Methods for attendance_service.dart
  bool isMonthlyMembershipActive() {
    return hasMonthlyMembership && endDate != null && endDate!.isAfter(DateTime.now());
  }
  
  // UPDATED: Modified to check package regardless of monthly status
  bool hasActivePackageForLesson(String lessonType) {
    final sessions = lessonSessions[lessonType] ?? 0;
    return sessions > 0;
  }
  
  // Additional method required by member_details_screen.dart
  bool hasAnyActivePackage() {
    return lessonSessions.values.any((sessions) => sessions > 0);
  }
  
  // Get all available lessons for check-in (both monthly and package)
  List<String> getAllAvailableLessons() {
    List<String> availableLessons = [];
    
    // Add monthly lessons if membership is active
    if (isMonthlyMembershipActive()) {
      availableLessons.addAll(lessons);
    }
    
    // Add package lessons with remaining sessions
    lessonSessions.forEach((lessonType, sessions) {
      if (sessions > 0 && !availableLessons.contains(lessonType)) {
        availableLessons.add(lessonType);
      }
    });
    
    return availableLessons;
  }
}