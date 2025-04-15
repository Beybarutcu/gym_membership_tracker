import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../services/member_service.dart';
import '../../services/attendance_service.dart';
import '../../services/localization_service.dart';
import '../../models/member.dart';

class ReportsScreen extends StatefulWidget {
  final Database database;
  
  const ReportsScreen({Key? key, required this.database}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final MemberService _memberService = MemberService();
  final AttendanceService _attendanceService = AttendanceService();
  
  bool _isLoading = false;
  
  // Report statistics
  int _totalMembers = 0;
  int _monthlyMembers = 0;
  int _packageMembers = 0;
  int _expiringMembers = 0;
  int _totalAttendance = 0;
  
  // Date range for filtering
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _loadReportData();
  }
  
  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get member statistics
      final allMembers = await _memberService.getAllMembers();
      _totalMembers = allMembers.length;
      
      _monthlyMembers = allMembers.where((m) => m.membershipType == 'Monthly').length;
      _packageMembers = allMembers.where((m) => m.membershipType == 'Package').length;
      
      // Get expiring memberships (within next 7 days)
      final expiringMembers = await _memberService.getExpiringMemberships(7);
      
      // Get members with low package sessions
      final lowSessionMembers = await _memberService.getMembersWithLowSessions(3);
      
      // Combine both lists (avoiding duplicates by using member IDs as keys)
      final Map<int, Member> combinedExpiringMembers = {};
      
      for (var member in expiringMembers) {
        if (member.id != null) {
          combinedExpiringMembers[member.id!] = member;
        }
      }
      
      for (var member in lowSessionMembers) {
        if (member.id != null && !combinedExpiringMembers.containsKey(member.id)) {
          combinedExpiringMembers[member.id!] = member;
        }
      }
      
      _expiringMembers = combinedExpiringMembers.length;
      
      // Get attendance data for date range
      final attendanceData = await _attendanceService.getAllAttendanceWithMemberInfo();
      _totalAttendance = attendanceData.length;
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading report data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReportData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildDateFilterCard(),
                  const SizedBox(height: 16),
                  _buildMembershipSummaryCard(),
                  const SizedBox(height: 16),
                  _buildAttendanceSummaryCard(),
                  const SizedBox(height: 16),
                  _buildExpiringMembershipsCard(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildDateFilterCard() {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'dateRange'.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text('startDate'.tr),
                    subtitle: Text(dateFormat.format(_startDate)),
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: _endDate,
                      );
                      
                      if (selectedDate != null) {
                        setState(() {
                          _startDate = selectedDate;
                        });
                        _loadReportData();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text('endDate'.tr),
                    subtitle: Text(dateFormat.format(_endDate)),
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now(),
                      );
                      
                      if (selectedDate != null) {
                        setState(() {
                          _endDate = selectedDate;
                        });
                        _loadReportData();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _startDate = DateTime.now().subtract(const Duration(days: 30));
                      _endDate = DateTime.now();
                    });
                    _loadReportData();
                  },
                  child: Text('last30Days'.tr),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _startDate = DateTime.now().subtract(const Duration(days: 90));
                      _endDate = DateTime.now();
                    });
                    _loadReportData();
                  },
                  child: Text('last90Days'.tr),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMembershipSummaryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'membershipSummary'.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildSummaryItem(
              icon: Icons.people,
              title: 'totalMembers'.tr,
              value: _totalMembers.toString(),
              color: Colors.blue,
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.calendar_today,
                    title: 'monthly'.tr,
                    value: _monthlyMembers.toString(),
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.confirmation_number,
                    title: 'package'.tr,
                    value: _packageMembers.toString(),
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttendanceSummaryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'attendanceSummary'.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildSummaryItem(
              icon: Icons.check_circle_outline,
              title: 'totalCheckIns'.tr,
              value: _totalAttendance.toString(),
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpiringMembershipsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'expiringMemberships'.tr,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Chip(
                  label: Text(
                    _expiringMembers.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                ),
              ],
            ),
            const Divider(),
            _buildSummaryItem(
              icon: Icons.warning_amber_rounded,
              title: 'expiringIn7Days'.tr,
              value: _expiringMembers.toString(),
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showExpiringMembershipsDetails,
              icon: const Icon(Icons.visibility),
              label: Text('viewDetails'.tr),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  // New method to show a detailed view of expiring memberships
  Future<void> _showExpiringMembershipsDetails() async {
    setState(() => _isLoading = true);
    
    try {
      // Load both types of expiring memberships
      final expiringMonthlyMembers = await _memberService.getExpiringMemberships(7);
      final lowSessionMembers = await _memberService.getMembersWithLowSessions(3);
      
      // Map to prevent duplicates
      final Map<int, Member> combinedExpiringMembers = {};
      
      for (var member in expiringMonthlyMembers) {
        if (member.id != null) {
          combinedExpiringMembers[member.id!] = member;
        }
      }
      
      for (var member in lowSessionMembers) {
        if (member.id != null) {
          // If already exists, we merge the data (keep package sessions info)
          if (combinedExpiringMembers.containsKey(member.id)) {
            // Keep the existing member, nothing to do
          } else {
            combinedExpiringMembers[member.id!] = member;
          }
        }
      }
      
      // Convert to list and sort
      final expiringMembers = combinedExpiringMembers.values.toList();
      
      // Sort: First by member type (monthly first), then by days left/sessions left
      expiringMembers.sort((a, b) {
        // First sort by membership type (monthly first)
        if (a.hasMonthlyMembership && !b.hasMonthlyMembership) return -1;
        if (!a.hasMonthlyMembership && b.hasMonthlyMembership) return 1;
        
        // If both are monthly, sort by days left
        if (a.hasMonthlyMembership && b.hasMonthlyMembership) {
          final aDaysLeft = a.endDate?.difference(DateTime.now()).inDays ?? 0;
          final bDaysLeft = b.endDate?.difference(DateTime.now()).inDays ?? 0;
          return aDaysLeft.compareTo(bDaysLeft);
        }
        
        // If neither are monthly, sort by lowest session count
        final aMinSessions = a.lessonSessions.values.isEmpty ? 
            999 : a.lessonSessions.values.reduce((min, value) => 
                min < value && min > 0 ? min : (value > 0 ? value : min));
        
        final bMinSessions = b.lessonSessions.values.isEmpty ? 
            999 : b.lessonSessions.values.reduce((min, value) => 
                min < value && min > 0 ? min : (value > 0 ? value : min));
        
        return aMinSessions.compareTo(bMinSessions);
      });
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      // Show the detailed view
      _navigateToExpiringMembersDetail(expiringMembers);
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'error'.tr}: $e')),
      );
    }
  }
  
  void _navigateToExpiringMembersDetail(List<Member> expiringMembers) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpiringMembershipsDetailScreen(members: expiringMembers),
      ),
    );
  }
}

// New screen to show expiring memberships details
class ExpiringMembershipsDetailScreen extends StatelessWidget {
  final List<Member> members;
  
  const ExpiringMembershipsDetailScreen({Key? key, required this.members}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('expiringMemberships'.tr),
      ),
      body: members.isEmpty
          ? Center(child: Text('noExpiringMemberships'.tr))
          : ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return _buildMemberExpirationCard(context, member);
              },
            ),
    );
  }
  
  Widget _buildMemberExpirationCard(BuildContext context, Member member) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  radius: 24,
                  child: Text(
                    member.name.isNotEmpty ? member.name[0] : '?',
                    style: TextStyle(
                      fontSize: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(member.phone),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Monthly membership info (if applicable)
            if (member.hasMonthlyMembership && member.endDate != null) ...[
              _buildExpirationInfo(
                context, 
                title: 'monthlyMembership'.tr,
                icon: Icons.calendar_today,
                color: Colors.blue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${'endDate'.tr}: ${dateFormat.format(member.endDate!)}'),
                    Text(
                      '${'daysLeft'.tr}: ${member.endDate!.difference(DateTime.now()).inDays}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${'availableLessons'.tr}:'),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: member.lessons.isEmpty
                          ? [Chip(label: Text('noLessons'.tr))]
                          : member.lessons.map((lesson) => Chip(
                              label: Text(lesson),
                              backgroundColor: Colors.blue.shade100,
                            )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Package sessions info (if applicable)
            if (member.lessonSessions.isNotEmpty) ...[
              _buildExpirationInfo(
                context, 
                title: 'packageMembership'.tr,
                icon: Icons.fitness_center,
                color: Colors.orange,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: member.lessonSessions.entries.map((entry) {
                    final isLow = entry.value <= 3 && entry.value > 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLow ? Colors.red.shade300 : Colors.green.shade300,
                              ),
                            ),
                            child: Text(
                              '${entry.value} ${'sessionsLeft'.tr}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isLow ? Colors.red.shade800 : Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpirationInfo(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }
}