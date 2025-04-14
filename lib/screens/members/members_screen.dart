import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import '../../models/member.dart';
import '../../services/member_service.dart';
import '../../services/localization_service.dart';
import '../../events/event_bus.dart';
import 'member_details_screen.dart';
import 'edit_member_screen.dart';
import 'add_member_screen.dart';
import '../check_in/check_in_screen.dart';

class MembersScreen extends StatefulWidget {
  final Database database;
  
  const MembersScreen({Key? key, required this.database}) : super(key: key);

  @override
  _MembersScreenState createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final MemberService _memberService = MemberService();
  final _searchController = TextEditingController();
  
  List<Member> _members = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  
  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Register with event bus for refreshes
    eventBus.onMembersRefresh = _forceReload;
    
    // Initial load
    _loadMembers();
    
    // Set up periodic refresh (every 30 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadMembers(silently: true);
      }
    });
  }
  
  @override
  void dispose() {
    // Clean up resources
    _searchController.dispose();
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    
    // Unregister from event bus
    if (eventBus.onMembersRefresh == _forceReload) {
      eventBus.onMembersRefresh = null;
    }
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app is resumed
    if (state == AppLifecycleState.resumed) {
      _loadMembers(silently: true);
    }
  }
  
  // Force reload the members list
  void _forceReload() {
    if (mounted) {
      setState(() {
        if (_searchController.text.isNotEmpty) {
          _searchController.clear();
        }
      });
      _loadMembers();
    }
  }
  
  // Load members with option to do it silently (without showing loading indicator)
  Future<void> _loadMembers({bool silently = false}) async {
    if (!mounted) return;
    
    if (!silently) {
      setState(() => _isLoading = true);
    }
    
    try {
      if (_searchController.text.isEmpty) {
        final members = await _memberService.getAllMembers();
        
        // Debug output to verify data
        print("Loaded ${members.length} members: ${members.map((m) => '${m.id}: ${m.name}').join(', ')}");
        
        if (mounted) {
          setState(() {
            _members = members;
            if (!silently) _isLoading = false;
          });
        }
      } else {
        final members = await _memberService.searchMembers(_searchController.text);
        if (mounted) {
          setState(() {
            _members = members;
            if (!silently) _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error loading members: $e");
      if (mounted && !silently) {
        _showErrorMessage('error'.tr + ': ' + e.toString());
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _searchMembers(String query) async {
    if (!mounted) return;
    
    if (query.isEmpty) {
      _loadMembers();
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final members = await _memberService.searchMembers(query);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('error'.tr + ': ' + e.toString());
        setState(() => _isLoading = false);
      }
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMembersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // Add a unique hero tag to prevent conflicts
        heroTag: "members_fab",
        onPressed: _addNewMember,
        child: const Icon(Icons.person_add),
        tooltip: 'addMember'.tr,
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'search'.tr + '...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                    _loadMembers();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _forceReload,
                tooltip: 'refresh'.tr,
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
        onChanged: _searchMembers,
      ),
    );
  }
  
  Widget _buildMembersList() {
    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'noMembers'.tr
                  : 'noMembers'.tr + ': "${_searchController.text}"',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _forceReload,
              icon: const Icon(Icons.refresh),
              label: Text('refresh'.tr),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          return _buildMemberListTile(member);
        },
      ),
    );
  }
  
  Widget _buildMemberListTile(Member member) {
  // Determine status color and text
  String statusText;
  Color statusBgColor;
  Color statusTextColor;
  
  if (!member.isValid) {
    // Inactive/Expired - Red
    statusText = "inactive".tr;
    statusBgColor = Colors.red.shade100;
    statusTextColor = Colors.red.shade800;
  } else {
    // Check if any package/membership is about to expire (within 7 days)
    bool isNearExpiry = false;
    
    if (member.hasMonthlyMembership && member.endDate != null) {
      final daysLeft = member.endDate!.difference(DateTime.now()).inDays;
      if (daysLeft <= 7) {
        isNearExpiry = true;
      }
    }
    
    // For package memberships, check if sessions are low (≤ 3)
    bool hasLowSessions = member.lessonSessions.values.any((sessions) => sessions <= 3 && sessions > 0);
    if (hasLowSessions) {
      isNearExpiry = true;
    }
    
    // Active but near expiry - Orange
    if (isNearExpiry) {
      statusText = "expiringSoon".tr;
      statusBgColor = Colors.orange.shade100;
      statusTextColor = Colors.orange.shade800;
    } else {
      // Active - Green
      statusText = "active".tr;
      statusBgColor = Colors.green.shade100;
      statusTextColor = Colors.green.shade800;
    }
  }
  
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member.phone),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusBgColor.withOpacity(0.7)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        leading: CircleAvatar(
          // Add a unique key for the avatar to prevent Hero conflicts
          key: ValueKey("avatar_${member.id}"),
          backgroundColor: statusTextColor.withOpacity(0.2),
          child: Text(
            member.name.isNotEmpty ? member.name[0] : '?',
            style: TextStyle(
              color: statusTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'details':
                _navigateToMemberDetails(member);
                break;
              case 'checkin':
                _navigateToCheckIn(member);
                break;
              case 'edit':
                _navigateToEditMember(member);
                break;
              case 'delete':
                _confirmDeleteMember(member);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Text('viewDetails'.tr),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'checkin',
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  Text('checkIn'.tr),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit),
                  const SizedBox(width: 8),
                  Text('edit'.tr),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('delete'.tr, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _navigateToMemberDetails(member),
      ),
    );
  }
  
  Future<void> _confirmDeleteMember(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirmDelete'.tr),
        content: Text('areYouSure'.tr + ' ${member.name}?'),
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
      // Delete from database
      final success = await _memberService.deleteMember(member.id!);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} ' + 'success'.tr)),
        );
        
        // Reload members list
        _loadMembers();
      } else {
        _showErrorMessage('error'.tr);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('error'.tr + ': $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _navigateToMemberDetails(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // Add unique route settings name
        settings: RouteSettings(name: '/member_details/${member.id}'),
        builder: (context) => MemberDetailScreen(
          member: member,
          database: widget.database,
        ),
      ),
    ).then((_) => _loadMembers());
  }
  
  void _navigateToEditMember(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // Add unique route settings name
        settings: RouteSettings(name: '/edit_member/${member.id}'),
        builder: (context) => EditMemberScreen(
          member: member,
          database: widget.database,
        ),
      ),
    ).then((_) => _loadMembers());
  }
  
  void _navigateToCheckIn(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // Add unique route settings name
        settings: RouteSettings(name: '/check_in/${member.id}'),
        builder: (context) => CheckInScreen(
          database: widget.database,
          memberId: member.id,
        ),
      ),
    ).then((_) => _loadMembers());
  }
  
  void _addNewMember() {
    Navigator.of(context).push(
      MaterialPageRoute(
        // Add unique route settings name
        settings: RouteSettings(name: '/add_member'),
        builder: (context) => AddMemberScreen(database: widget.database),
      ),
    ).then((_) {
      // Always refresh the list when returning from add member screen
      _loadMembers();
      
      // Clear any search text to ensure we see all members including the new one
      if (_searchController.text.isNotEmpty) {
        setState(() {
          _searchController.clear();
        });
      }
    });
  }
}