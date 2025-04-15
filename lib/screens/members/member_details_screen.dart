import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/member.dart';
import '../../models/attendance.dart';
import '../../services/member_service.dart';
import '../../services/attendance_service.dart';
import '../../services/localization_service.dart';
import '../check_in/check_in_screen.dart';
import 'edit_member_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  final Member member;
  final Database database;
  
  const MemberDetailScreen({
    Key? key, 
    required this.member,
    required this.database,
  }) : super(key: key);

  @override
  _MemberDetailScreenState createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final MemberService _memberService = MemberService();
  final AttendanceService _attendanceService = AttendanceService();
  Member? _member;
  List<Attendance> _attendanceHistory = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Refresh member data
      final refreshedMember = await _memberService.getMemberById(_member!.id!);
      if (refreshedMember != null) {
        _member = refreshedMember;
      }
      
      // Load attendance history
      _attendanceHistory = await _attendanceService.getMemberAttendance(_member!.id!);
    } catch (e) {
      _showErrorMessage('${'error'.tr}: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_member?.name ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'checkIn'.tr,
            onPressed: _navigateToCheckIn,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'editMember'.tr,
            onPressed: _navigateToEditMember,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }
  
  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMemberInfoCard(),
          const SizedBox(height: 16),
          _buildMembershipDetailsCard(),
          const SizedBox(height: 16),
          _buildAttendanceHistoryCard(),
        ],
      ),
    );
  }
  
  Widget _buildMemberInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  radius: 30,
                  child: Text(
                    _member!.name.isNotEmpty ? _member!.name[0] : '?',
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _member!.name,
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _member!.phone,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            
            // Overall status
            _buildInfoRow(
              'status'.tr,
              _member!.isValid ? 'active'.tr : 'inactive'.tr,
              valueColor: _member!.isValid ? Colors.green : Colors.red,
              valueStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
  
  // UPDATED: Show both monthly and package memberships clearly
  Widget _buildMembershipDetailsCard() {
    final dateFormat = DateFormat('MMM d, yyyy');
    
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
            
            // Monthly membership section if applicable
            if (_member!.hasMonthlyMembership) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'monthlyMembership'.tr,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow('startDate'.tr, 
                      _member!.startDate != null 
                          ? dateFormat.format(_member!.startDate) 
                          : 'Not set'
                    ),
                    if (_member!.endDate != null)
                      _buildInfoRow('endDate'.tr, dateFormat.format(_member!.endDate!)),
                    _buildInfoRow(
                      'status'.tr,
                      _member!.monthlyStatusText,
                      valueColor: _member!.isMonthlyMembershipActive() ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${'availableLessons'.tr}:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _member!.lessons.isEmpty
                        ? [Chip(label: Text('noLessons'.tr))]
                        : _member!.lessons.map((lesson) => Chip(
                            label: Text(lesson),
                            backgroundColor: Colors.blue.shade100,
                          )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Package sessions section if any
            if (_member!.lessonSessions.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'packageMembership'.tr,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    ..._member!.lessonSessions.entries.map((entry) => 
                      _buildInfoRow(
                        entry.key,
                        '${entry.value} ${'remainingSessions'.tr}',
                        valueColor: entry.value > 0 ? Colors.green : Colors.red,
                      ),
                    ).toList(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttendanceHistoryCard() {
    final dateFormat = DateFormat('MMM d, yyyy - h:mm a');
    
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
                  'checkIns'.tr,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Chip(
                  label: Text(
                    _attendanceHistory.length.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const Divider(),
            if (_attendanceHistory.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text('noEvents'.tr),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attendanceHistory.length,
                itemBuilder: (context, index) {
                  final attendance = _attendanceHistory[index];
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.event_available),
                    ),
                    title: Text(attendance.lessonType),
                    subtitle: Text(dateFormat.format(attendance.dateTime)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDeleteAttendance(attendance),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(
    String label, 
    String value, {
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: (valueStyle ?? Theme.of(context).textTheme.bodyLarge!).copyWith(
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _confirmDeleteAttendance(Attendance attendance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete'.tr),
        content: Text(
          '${'areYouSure'.tr} ${attendance.lessonType} ${DateFormat('MMM d, yyyy').format(attendance.dateTime)}?'
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
      // Delete the attendance record
      await _attendanceService.deleteAttendance(attendance.id!);
      
      // Refresh data
      await _loadData();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('success'.tr)),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('${'error'.tr}: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _navigateToEditMember() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMemberScreen(
          member: _member!,
          database: widget.database,
        ),
      ),
    ).then((_) => _loadData());
  }
  
  void _navigateToCheckIn() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckInScreen(
          database: widget.database,
          memberId: _member!.id,
        ),
      ),
    ).then((_) => _loadData());
  }
}