import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../../models/member.dart';
import '../../services/member_service.dart';
import '../../services/attendance_service.dart';
import '../../services/localization_service.dart';
import '../../events/event_bus.dart';

class CheckInScreen extends StatefulWidget {
  final Database database;
  final int? memberId; // Optional, if coming from member details
  
  const CheckInScreen({
    Key? key, 
    required this.database,
    this.memberId,
  }) : super(key: key);

  @override
  _CheckInScreenState createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final MemberService _memberService = MemberService();
  final AttendanceService _attendanceService = AttendanceService();
  
  final _searchController = TextEditingController();
  List<Member> _members = [];
  Member? _selectedMember;
  String? _selectedLesson;
  bool _isLoading = true;
  
  // Added state to track and show errors/success
  String? _errorMessage;
  bool _showSuccessMessage = false;
  
  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Initialize screen based on whether we have a member ID
  Future<void> _initScreen() async {
    setState(() => _isLoading = true);
    
    try {
      if (widget.memberId != null) {
        // Load specific member
        await _loadMemberById(widget.memberId!);
      } else {
        // Load all members
        await _loadAllMembers();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'error'.tr + ': $e';
        _isLoading = false;
      });
      print("Error initializing check-in screen: $e");
    }
  }
  
  // Load all members
  Future<void> _loadAllMembers() async {
    try {
      final members = await _memberService.getAllMembers();
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'error'.tr + ': $e';
        _isLoading = false;
      });
    }
  }
  
  // Get combined available lessons for a member (monthly + package)
  List<String> _getAvailableLessons(Member member) {
    final List<String> availableLessons = [];
    
    // Add monthly lessons if membership is active
    if (member.isMonthlyMembershipActive()) {
      availableLessons.addAll(member.lessons);
    }
    
    // Add package lessons with remaining sessions
    member.lessonSessions.forEach((lessonType, sessions) {
      if (sessions > 0 && !availableLessons.contains(lessonType)) {
        availableLessons.add(lessonType);
      }
    });
    
    return availableLessons;
  }
  
  // Load member by ID
  Future<void> _loadMemberById(int id) async {
    try {
      final member = await _memberService.getMemberById(id);
      if (member != null) {
        setState(() {
          _selectedMember = member;
          
          // Get available lessons (both monthly and package)
          final availableLessons = _getAvailableLessons(member);
          if (availableLessons.isNotEmpty) {
            _selectedLesson = availableLessons.first;
          } else {
            _loadAvailableLessons();
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'noMembers'.tr;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'error'.tr + ': $e';
        _isLoading = false;
      });
    }
  }
  
  // Search members
  Future<void> _searchMembers(String query) async {
    if (query.isEmpty) {
      _loadAllMembers();
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final members = await _memberService.searchMembers(query);
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'error'.tr + ': $e';
        _isLoading = false;
      });
    }
  }
  
  // Load available lessons
  Future<List<String>> _loadAvailableLessons() async {
    try {
      final lessonTypes = await _memberService.getAllLessonTypes();
      
      if (lessonTypes.isNotEmpty && _selectedLesson == null) {
        setState(() {
          _selectedLesson = lessonTypes.first;
        });
      }
      
      return lessonTypes;
    } catch (e) {
      print("Error loading available lessons: $e");
      return [];
    }
  }
  
  // Process check-in
  Future<void> _processCheckIn() async {
    if (_selectedMember == null || _selectedLesson == null) {
      setState(() {
        _errorMessage = 'Lütfen bir üye ve ders seçin';
      });
      return;
    }
    
    // Reset messages
    setState(() {
      _errorMessage = null;
      _showSuccessMessage = false;
      _isLoading = true;
    });
    
    try {
      // Check if membership is valid for check-in
      bool isValidForLesson = false;
      
      // Check monthly membership
      if (_selectedMember!.isMonthlyMembershipActive() && 
          _selectedMember!.lessons.contains(_selectedLesson)) {
        isValidForLesson = true;
      }
      
      // Check package sessions
      if (!isValidForLesson && 
          _selectedMember!.lessonSessions.containsKey(_selectedLesson) &&
          _selectedMember!.lessonSessions[_selectedLesson]! > 0) {
        isValidForLesson = true;
      }
      
      if (!isValidForLesson) {
        _showInvalidMembershipDialog();
        setState(() => _isLoading = false);
        return;
      }
      
      // Record attendance
      final success = await _attendanceService.recordAttendance(
        _selectedMember!.id!,
        _selectedLesson!,
      );
      
      if (!mounted) return;
      
      if (success) {
        // Trigger event bus to refresh member list
        eventBus.refreshMembers();
        
        setState(() {
          _showSuccessMessage = true;
          _isLoading = false;
        });
        
        // Show success message and auto-close after 2 seconds
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedMember!.name} $_selectedLesson dersine katıldı.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Derse katılım kaydı başarısız oldu. Üyelik bu ders için geçerli olmayabilir.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Hata: $e';
        _isLoading = false;
      });
    }
  }
  
  // Show invalid membership dialog
  void _showInvalidMembershipDialog() {
    String message = '';
    
    // Check monthly membership
    if (_selectedMember!.hasMonthlyMembership) {
      if (_selectedMember!.endDate == null) {
        message = 'invalidMembership'.tr + ': ' + 'Geçersiz üyelik bitiş tarihi yok';
      } else if (_selectedMember!.endDate!.isBefore(DateTime.now())) {
        final formatter = DateFormat('MMM d, yyyy');
        message = 'membershipExpired'.tr + ': ' + formatter.format(_selectedMember!.endDate!);
      } else if (!_selectedMember!.lessons.contains(_selectedLesson)) {
        message = 'lessonNotIncluded'.tr;
      }
    }
    
    // Check package sessions
    if (message.isEmpty) {
      if (!_selectedMember!.lessonSessions.containsKey(_selectedLesson)) {
        message = 'lessonNotIncluded'.tr;
      } else if (_selectedMember!.lessonSessions[_selectedLesson]! <= 0) {
        message = 'noSessionsLeft'.tr;
      }
    }
    
    // Fallback message
    if (message.isEmpty) {
      message = 'invalidMembership'.tr;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('invalidMembership'.tr),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('cancel'.tr),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('checkInAnyway'.tr),
            onPressed: () {
              Navigator.pop(context);
              _forceCheckIn();
            },
          ),
        ],
      ),
    );
  }
  
  // Force check-in (admin override)
  Future<void> _forceCheckIn() async {
    if (_selectedMember == null || _selectedLesson == null) return;
    
    setState(() {
      _errorMessage = null;
      _showSuccessMessage = false;
      _isLoading = true;
    });
    
    try {
      final success = await _attendanceService.forceRecordAttendance(
        _selectedMember!.id!,
        _selectedLesson!,
      );
      
      if (!mounted) return;
      
      if (success) {
        // Trigger event bus to refresh member list
        eventBus.refreshMembers();
        
        setState(() {
          _showSuccessMessage = true;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedMember!.name} $_selectedLesson zorunlu olarak katıldı'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Zorunlu derse katılım başarısız oldu';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'error'.tr + ': $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedMember != null 
            ? 'checkIn'.tr + ': ${_selectedMember!.name}'
            : 'checkIn'.tr),
        actions: [
          if (_selectedMember != null)
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: 'cancel'.tr,
              onPressed: () {
                setState(() {
                  _selectedMember = null;
                  _selectedLesson = null;
                  _errorMessage = null;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      ),
    );
  }
  
  Widget _buildContent() {
    // Show error message if present
    if (_errorMessage != null) {
      return Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
              child: Text('close'.tr),
            ),
          ],
        ),
      );
    }
    
    // Show success message
    if (_showSuccessMessage) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 72.0,
            ),
            const SizedBox(height: 16.0),
            Text(
              'success'.tr,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8.0),
            Text(
              _selectedMember != null 
                  ? '${_selectedMember!.name} - $_selectedLesson'
                  : '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('close'.tr),
            ),
          ],
        ),
      );
    }
    
    // Show member selection or check-in form
    return _selectedMember != null 
        ? _buildCheckInForm() 
        : _buildMemberList();
  }
  
  // Member list view
  Widget _buildMemberList() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'search'.tr,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                        _loadAllMembers();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            onChanged: _searchMembers,
          ),
        ),
        
        // Member count display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '${_members.length} ' + 'members'.tr,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        
        const Divider(),
        
        // Members list
        Expanded(
          child: _members.isEmpty
              ? _buildEmptyMembersView()
              : ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return _buildMemberListItem(member);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyMembersView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'noMembers'.tr
                : '${'noMembers'.tr}: "${_searchController.text}"',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (_searchController.text.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                });
                _loadAllMembers();
              },
              child: Text('resetFilters'.tr),
            ),
        ],
      ),
    );
  }
  
  // Member list item with "Expiring Soon" indicator for low sessions
  Widget _buildMemberListItem(Member member) {
    // Determine if member is expired or has low sessions
    final isExpired = !member.isValid;
    
    // Fixed: Properly check for ANY lesson with low sessions (≤ 3)
    final bool hasLowSessions = member.lessonSessions.values.any((sessions) => sessions > 0 && sessions <= 3);
    
    // Check if monthly is about to expire (7 days or less)
    bool isMonthlyExpiringSoon = false;
    if (member.hasMonthlyMembership && member.endDate != null) {
      final daysLeft = member.endDate!.difference(DateTime.now()).inDays;
      isMonthlyExpiringSoon = daysLeft <= 7 && daysLeft > 0;
    }
    
    // Choose the appropriate status color and text
    Color statusColor;
    String statusText;
    
    if (isExpired) {
      statusColor = Colors.red;
      statusText = 'status'.tr + ': ' + 'expired'.tr;
    } else if (hasLowSessions || isMonthlyExpiringSoon) {
      statusColor = Colors.orange;
      statusText = 'status'.tr + ': ' + 'expiringSoon'.tr;
    } else {
      statusColor = Colors.green;
      statusText = 'status'.tr + ': ' + 'active'.tr;
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
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Show detailed status for low sessions or expiring monthly
            if (hasLowSessions || isMonthlyExpiringSoon)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: _buildDetailedStatusText(member),
              ),
          ],
        ),
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: isExpired 
              ? Colors.red.shade200 
              : (hasLowSessions || isMonthlyExpiringSoon)
                  ? Colors.orange.shade200
                  : Theme.of(context).colorScheme.primary,
          child: Text(
            member.name.isNotEmpty ? member.name[0] : '?',
            style: TextStyle(
              color: isExpired 
                  ? Colors.red.shade900 
                  : (hasLowSessions || isMonthlyExpiringSoon)
                      ? Colors.orange.shade900
                      : Colors.white,
            ),
          ),
        ),
        onTap: () {
          setState(() {
            _selectedMember = member;
            
            // Get available lessons from both membership types
            final availableLessons = _getAvailableLessons(member);
            if (availableLessons.isNotEmpty) {
              _selectedLesson = availableLessons.first;
            } else {
              // If no lessons are assigned, get all available ones
              _loadAvailableLessons();
            }
          });
        },
      ),
    );
  }
  
  // Helper method to show detailed status information
  Widget _buildDetailedStatusText(Member member) {
    List<String> details = [];
    
    // Check package sessions
    member.lessonSessions.forEach((lesson, sessions) {
      if (sessions > 0 && sessions <= 2) {
        details.add('$lesson: $sessions ' + 'sessionsLeft'.tr);
      }
    });
    
    // Check monthly membership
    if (member.hasMonthlyMembership && member.endDate != null) {
      final daysLeft = member.endDate!.difference(DateTime.now()).inDays;
      if (daysLeft <= 7 && daysLeft > 0) {
        details.add('Monthly'.tr + ': $daysLeft ' + 'daysLeft'.tr);
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details.map((detail) => 
        Text(
          detail,
          style: const TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        )
      ).toList(),
    );
  }
  
  // Check-in form with improved expiring indicators
  Widget _buildCheckInForm() {
    final isExpired = !_selectedMember!.isValid;
    
    // Fixed: Properly check for ANY lesson with low sessions
    final bool hasLowSessions = _selectedMember!.lessonSessions.values.any((sessions) => sessions > 0 && sessions <= 3);
    
    // Check if monthly is about to expire
    bool isMonthlyExpiringSoon = false;
    if (_selectedMember!.hasMonthlyMembership && _selectedMember!.endDate != null) {
      final daysLeft = _selectedMember!.endDate!.difference(DateTime.now()).inDays;
      isMonthlyExpiringSoon = daysLeft <= 7 && daysLeft > 0;
    }
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Member info card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isExpired 
                              ? Colors.red.shade200 
                              : (hasLowSessions || isMonthlyExpiringSoon)
                                  ? Colors.orange.shade200
                                  : Theme.of(context).colorScheme.primary,
                          radius: 30,
                          child: Text(
                            _selectedMember!.name.isNotEmpty ? _selectedMember!.name[0] : '?',
                            style: TextStyle(
                              fontSize: 24,
                              color: isExpired 
                                  ? Colors.red.shade900 
                                  : (hasLowSessions || isMonthlyExpiringSoon)
                                      ? Colors.orange.shade900
                                      : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedMember!.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _selectedMember!.phone,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    
                    // Membership type indicator
                    Row(
                      children: [
                        const Icon(Icons.card_membership),
                        const SizedBox(width: 8),
                        Text(
                          _selectedMember!.membershipType == 'Monthly' ? 'monthlyMembership'.tr : 'packageMembership'.tr,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Status indicator
                    Row(
                      children: [
                        Icon(
                          isExpired 
                              ? Icons.error 
                              : (hasLowSessions || isMonthlyExpiringSoon)
                                  ? Icons.warning
                                  : Icons.check_circle,
                          color: isExpired 
                              ? Colors.red 
                              : (hasLowSessions || isMonthlyExpiringSoon)
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isExpired 
                              ? 'status'.tr + ': ' + 'expired'.tr
                              : (hasLowSessions || isMonthlyExpiringSoon)
                                  ? 'status'.tr + ': ' + 'expiringSoon'.tr
                                  : 'status'.tr + ': ' + 'active'.tr,
                          style: TextStyle(
                            fontSize: 16,
                            color: isExpired 
                                ? Colors.red 
                                : (hasLowSessions || isMonthlyExpiringSoon)
                                    ? Colors.orange
                                    : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    
                    // Show detailed status info when needed
                    if (hasLowSessions || isMonthlyExpiringSoon)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildExpiringDetails(),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Lesson selection card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'selectLesson'.tr,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildLessonDropdown(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Warning for expired membership
            if (isExpired)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'invalidMembership'.tr,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Warning for expiring membership
            if (hasLowSessions || isMonthlyExpiringSoon)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'expiringSoon'.tr,
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedMember = null;
                        _selectedLesson = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('cancel'.tr),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _processCheckIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('checkIn'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to display expiring membership details
  Widget _buildExpiringDetails() {
    List<Widget> details = [];
    
    // Check package sessions
    _selectedMember!.lessonSessions.forEach((lesson, sessions) {
      if (sessions > 0 && sessions <= 2) {
        details.add(
          Container(
            margin: const EdgeInsets.only(top: 4.0),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              '$lesson: $sessions ' + 'sessionsLeft'.tr,
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
              ),
            ),
          )
        );
      }
    });
    
    // Check monthly membership
    if (_selectedMember!.hasMonthlyMembership && _selectedMember!.endDate != null) {
      final daysLeft = _selectedMember!.endDate!.difference(DateTime.now()).inDays;
      if (daysLeft <= 7 && daysLeft > 0) {
        details.add(
          Container(
            margin: const EdgeInsets.only(top: 4.0),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              'monthlyMembership'.tr + ': $daysLeft ' + 'daysLeft'.tr,
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
              ),
            ),
          )
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    );
  }
  
  // Lesson dropdown - simplified but handles both monthly and package
  Widget _buildLessonDropdown() {
    // Get available lessons from both membership types
    List<String> displayLessons = [];
    
    if (_selectedMember != null) {
      displayLessons = _getAvailableLessons(_selectedMember!);
    }
    
    // If no available lessons, check if a lesson is already selected
    if (displayLessons.isEmpty && _selectedLesson != null) {
      displayLessons = [_selectedLesson!];
    }
    
    if (displayLessons.isEmpty) {
      return Text('noLessons'.tr);
    }
    
    return DropdownButtonFormField<String>(
      value: _selectedLesson,
      decoration: InputDecoration(
        labelText: 'lessonType'.tr,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.fitness_center),
      ),
      items: displayLessons.map((lesson) {
        // Add indicator for package lessons
        String displayText = lesson;
        
        // Show package session count if applicable
        if (_selectedMember != null && 
            _selectedMember!.lessonSessions.containsKey(lesson) && 
            _selectedMember!.lessonSessions[lesson]! > 0) {
          int sessions = _selectedMember!.lessonSessions[lesson] ?? 0;
          displayText = "$lesson (${'packageMembership'.tr}: $sessions ${'sessionsLeft'.tr})";
        }
        // Show if it's a monthly lesson
        else if (_selectedMember != null && 
                 _selectedMember!.hasMonthlyMembership && 
                 _selectedMember!.isMonthlyMembershipActive() &&
                 _selectedMember!.lessons.contains(lesson)) {
          displayText = "$lesson (${'monthlyMembership'.tr})";
        }
        
        return DropdownMenuItem<String>(
          value: lesson,
          child: Text(displayText),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedLesson = value;
        });
      },
    );
  }
}