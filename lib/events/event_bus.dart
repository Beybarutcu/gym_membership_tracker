// Create a simple event bus for communication between screens
class EventBus {
  // Singleton pattern
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();
  
  // Callback for member list refresh
  Function? onMembersRefresh;
  
  // Method to trigger member list refresh
  void refreshMembers() {
    if (onMembersRefresh != null) {
      onMembersRefresh!();
    }
  }
}

// Global instance for easy access
final eventBus = EventBus();