import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/calendar_event.dart';
import '../../services/attendance_service.dart';
import '../../services/member_service.dart';
import '../../services/localization_service.dart';
import '../check_in/check_in_screen.dart';

class CalendarScreen extends StatefulWidget {
  final Database database;
  
  const CalendarScreen({Key? key, required this.database}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MemberService _memberService = MemberService();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  // We'll keep separate maps for different types of events
  Map<DateTime, List<CalendarEvent>> _attendanceEvents = {};
  Map<DateTime, List<ExpiringMembershipEvent>> _expiringEvents = {};
  
  List<Map<String, dynamic>> _expiringMemberships = [];
  List<CalendarEvent> _selectedAttendanceEvents = [];
  List<ExpiringMembershipEvent> _selectedExpiringEvents = [];
  
  bool _isLoading = false;
  
  // Turkish day and month names for calendar
  // Ordered starting with Monday (Pazartesi)
  final List<String> _turkishWeekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  final List<String> _turkishMonthLong = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load events and memberships in parallel
      await Future.wait([
        _loadAttendanceEvents(),
        _loadExpiringMemberships(),
      ]);
    } catch (e) {
      _showErrorMessage('error'.tr + ': $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  Future<void> _loadAttendanceEvents() async {
    try {
      // Clear existing events
      _attendanceEvents = {};
      
      // Get all attendance records with member names
      final results = await _attendanceService.getAllAttendanceWithMemberInfo();
      
      // Process results
      for (var result in results) {
        try {
          final DateTime date = DateTime.parse(result['date']);
          final DateTime eventDay = DateTime(date.year, date.month, date.day);
          
          final event = CalendarEvent.fromAttendance(result);
          
          if (_attendanceEvents[eventDay] != null) {
            _attendanceEvents[eventDay]!.add(event);
          } else {
            _attendanceEvents[eventDay] = [event];
          }
        } catch (e) {
          print('Error parsing event date: $e');
          continue;
        }
      }
      
      // Update selected events
      _updateSelectedEvents();
    } catch (e) {
      print('Error loading events: $e');
      rethrow;
    }
  }
  
  Future<void> _loadExpiringMemberships() async {
    try {
      // Get ALL members with monthly memberships
      final allMembers = await _memberService.getAllMembers();
      final membersWithMonthly = allMembers.where((member) => 
        member.hasMonthlyMembership && member.endDate != null
      ).toList();
      
      // Clear existing expiring events
      _expiringEvents = {};
      
      // Create events for each expiring membership
      for (var member in membersWithMonthly) {
        if (member.endDate != null) {
          final expiryDate = DateTime(
            member.endDate!.year, 
            member.endDate!.month, 
            member.endDate!.day
          );
          
          final event = ExpiringMembershipEvent(
            memberId: member.id!,
            memberName: member.name,
            expiryDate: expiryDate
          );
          
          if (_expiringEvents[expiryDate] != null) {
            _expiringEvents[expiryDate]!.add(event);
          } else {
            _expiringEvents[expiryDate] = [event];
          }
        }
      }
      
      // Save data for the expiring memberships tab
      _expiringMemberships = membersWithMonthly
          .where((member) => member.endDate != null && 
                 member.endDate!.difference(DateTime.now()).inDays <= 7 &&
                 member.endDate!.isAfter(DateTime.now()))
          .map((member) => member.toMap())
          .toList();
      
      // Update selected events
      _updateSelectedEvents();
    } catch (e) {
      print('Error loading expiring memberships: $e');
      rethrow;
    }
  }
  
  void _updateSelectedEvents() {
    final selectedDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    setState(() {
      _selectedAttendanceEvents = _attendanceEvents[selectedDate] ?? [];
      _selectedExpiringEvents = _expiringEvents[selectedDate] ?? [];
    });
  }
  
  List<dynamic> _getEventsForDay(DateTime day) {
    final eventDay = DateTime(day.year, day.month, day.day);
    final attendanceList = _attendanceEvents[eventDay] ?? [];
    final expiringList = _expiringEvents[eventDay] ?? [];
    
    // Combine both types of events
    return [...attendanceList, ...expiringList];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: Column(
              children: [
                _buildCalendar(),
                const Divider(),
                Expanded(
                  child: _buildEventList(),
                ),
              ],
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCheckIn,
        child: const Icon(Icons.add_task),
        tooltip: 'quickCheckIn'.tr,
      ),
    );
  }
  
  Widget _buildCalendar() {
    // Calculate the proper day cell height (adjust based on your UI needs)
    final screenHeight = MediaQuery.of(context).size.height;
    final dayCellHeight = screenHeight * 0.044; // Reduced for tighter spacing
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduced horizontal padding
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        eventLoader: _getEventsForDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        // Set start day to Monday (1)
        startingDayOfWeek: StartingDayOfWeek.monday,
        // Add Turkish localization
        availableCalendarFormats: const {
          CalendarFormat.month: 'Ay',
          CalendarFormat.twoWeeks: '2 Hafta',
          CalendarFormat.week: 'Hafta',
        },
        daysOfWeekHeight: 30, // Reduced height for day names
        rowHeight: dayCellHeight, // Set custom day cell height
        daysOfWeekStyle: DaysOfWeekStyle(
          // Turkish day names, starting with Monday (Pazartesi)
          dowTextFormatter: (date, locale) {
            // Convert to 1-based weekday where 1 is Monday
            int mondayBasedWeekday = date.weekday; // weekday is already 1-7 where 1 is Monday
            return _turkishWeekdayShort[mondayBasedWeekday - 1];
          },
          weekdayStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          weekendStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Same as weekday (no red color)
        ),
        headerStyle: HeaderStyle(
          formatButtonShowsNext: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          // Turkish month and year formatting
          titleTextFormatter: (date, locale) {
            return '${_turkishMonthLong[date.month - 1]} ${date.year}';
          },
          formatButtonTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          formatButtonDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          leftChevronIcon: const Icon(Icons.chevron_left, size: 28),
          rightChevronIcon: const Icon(Icons.chevron_right, size: 28),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _updateSelectedEvents();
          });
        },
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarStyle: CalendarStyle(
          markersMaxCount: 3,
          markerDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          markersAutoAligned: true,
          markersAnchor: 0.7,
          cellMargin: const EdgeInsets.all(1), // Reduced margin around cells
          cellPadding: const EdgeInsets.all(1), // Reduced padding inside cells
          // Text styles for days with larger font sizes
          defaultTextStyle: const TextStyle(fontSize: 18), // Increased from 14 to 18
          weekendTextStyle: const TextStyle(fontSize: 18), // Same as default (no red color)
          selectedTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), // Increased
          todayTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Increased
          // Add outsideTextStyle to make days from other months less visible
          outsideTextStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox();
            
            // Separate events by type
            final attendanceEvents = events.whereType<CalendarEvent>().toList();
            final expiringEvents = events.whereType<ExpiringMembershipEvent>().toList();
            
            return Positioned(
              bottom: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show regular attendance markers
                  if (attendanceEvents.isNotEmpty)
                    Container(
                      width: 6, // Smaller marker
                      height: 6, // Smaller marker
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  // Show orange markers for expiring memberships
                  if (expiringEvents.isNotEmpty)
                    Container(
                      width: 6, // Smaller marker
                      height: 6, // Smaller marker
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildEventList() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'dailyEvents'.tr),
              Tab(text: 'expiringMemberships'.tr),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDailyEvents(),
                _buildExpiringMemberships(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDailyEvents() {
    final hasAttendance = _selectedAttendanceEvents.isNotEmpty;
    final hasExpiring = _selectedExpiringEvents.isNotEmpty;
    
    if (!hasAttendance && !hasExpiring) {
      // Format date in Turkish
      final turkishMonthName = _turkishMonthLong[_selectedDay.month - 1];
      final formattedDate = '${_selectedDay.day} $turkishMonthName ${_selectedDay.year}';
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '$formattedDate için ' + 'noEvents'.tr,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _navigateToCheckIn,
              icon: const Icon(Icons.add),
              label: Text('checkIn'.tr),
            ),
          ],
        ),
      );
    }
    
    return ListView(
      children: [
        // Show expiring memberships first with a header
        if (hasExpiring) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'expiringMemberships'.tr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.orange,
              ),
            ),
          ),
          ...List.generate(_selectedExpiringEvents.length, (index) {
            final event = _selectedExpiringEvents[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.calendar_today, color: Colors.white),
                ),
                title: Text(event.memberName),
                subtitle: Text(
                  'Üyelik bu gün sona erecek',
                  style: const TextStyle(color: Colors.orange),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    // Navigate to member details (would need to be implemented)
                  },
                ),
              ),
            );
          }),
          if (hasAttendance)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'checkIns'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
        
        // Show attendance events
        if (hasAttendance)
          ...List.generate(_selectedAttendanceEvents.length, (index) {
            final event = _selectedAttendanceEvents[index];
            // Format time in Turkish
            final timeFormatter = DateFormat('HH:mm');
            final formattedTime = timeFormatter.format(event.dateTime);
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.fitness_center, color: Colors.white),
                ),
                title: Text(event.memberName),
                subtitle: Text(
                  '${event.lessonType} - $formattedTime',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteEvent(event),
                ),
              ),
            );
          }),
      ],
    );
  }
  
  Widget _buildExpiringMemberships() {
    if (_expiringMemberships.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'noExpiringMemberships'.tr,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _expiringMemberships.length,
      itemBuilder: (context, index) {
        final member = _expiringMemberships[index];
        
        // Parse end date
        DateTime endDate;
        try {
          endDate = DateTime.parse(member['end_date']);
        } catch (e) {
          return const SizedBox.shrink(); // Skip invalid entries
        }
        
        final daysLeft = endDate.difference(DateTime.now()).inDays;
        
        // Format date in Turkish
        final turkishMonthName = _turkishMonthLong[endDate.month - 1];
        final formattedDate = '${endDate.day} $turkishMonthName ${endDate.year}';
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: const Icon(Icons.warning, color: Colors.white),
            ),
            title: Text(member['name'] ?? 'Bilinmeyen Üye'),
            subtitle: Text(
              '$formattedDate ' + 'endDate'.tr,
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Text(
                '$daysLeft ' + 'daysLeft'.tr,
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _navigateToCheckIn() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckInScreen(database: widget.database),
      ),
    ).then((_) => _loadData());
  }
  
  Future<void> _deleteEvent(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete'.tr),
        content: Text(
          'areYouSure'.tr + ' ' + event.memberName + '?'
        ),
        actions: [
          TextButton(
            child: Text('cancel'.tr),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('delete'.tr),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _attendanceService.deleteAttendance(event.id);
      await _loadAttendanceEvents();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('success'.tr)),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('error'.tr + ': $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// New class to represent expiring membership events
class ExpiringMembershipEvent {
  final int memberId;
  final String memberName;
  final DateTime expiryDate;
  
  ExpiringMembershipEvent({
    required this.memberId,
    required this.memberName,
    required this.expiryDate,
  });
}