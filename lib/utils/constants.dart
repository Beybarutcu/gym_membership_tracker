import 'package:flutter/material.dart';

class AppConstants {
  // Database constants
  static const String databaseName = 'gym_membership.db';
  static const int databaseVersion = 1;
  
  // Table names
  static const String membersTable = 'members';
  static const String memberLessonsTable = 'member_lessons';
  static const String attendanceTable = 'attendance';
  
  // Membership types
  static const String monthlyMembership = 'Monthly';
  static const String packageMembership = 'Package';
  
  // Lesson types
  static const List<String> lessonTypes = [
    'Zumba',
    'Pilates',
    'Fitness',
    'Karma',
    'Bungee',
    'Yoga',
    'Reformer'
  ];
  
  // Report thresholds
  static const int expiringMembershipDays = 7;
  static const int lowSessionThreshold = 2;
  
  // UI constants
  static const double defaultPadding = 16.0;
  static const double cardElevation = 4.0;
  static const double borderRadius = 8.0;
  
  // App info
  static const String appName = 'Flowers Fit Üyelik Takibi';
  static const String appVersion = '1.0.0';
  static const String appCopyright = '© 2025 Flowers Fit';
  
  // Error messages
  static const String errorLoadingData = 'Error loading data. Please try again.';
  static const String errorSavingData = 'Error saving data. Please try again.';
  static const String errorDeletingData = 'Error deleting data. Please try again.';
  
  // Success messages
  static const String memberAddedSuccess = 'Member added successfully';
  static const String memberUpdatedSuccess = 'Member updated successfully';
  static const String memberDeletedSuccess = 'Member deleted successfully';
  static const String checkInSuccess = 'Check-in recorded successfully';
  
  // Theme colors
  static const Color primaryColor = Color(0xFF3F51B5);  // Indigo
  static const Color accentColor = Color(0xFFFF4081);   // Pink
  static const Color backgroundColor = Color(0xFFF5F5F5);
  
  // Status colors
  static const Color activeStatusColor = Color(0xFF4CAF50);  // Green
  static const Color warningStatusColor = Color(0xFFFF9800);  // Orange
  static const Color errorStatusColor = Color(0xFFF44336);  // Red
}