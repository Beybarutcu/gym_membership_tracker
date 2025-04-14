import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/member.dart';
import '../../services/member_service.dart';
import '../../services/localization_service.dart';
import '../../events/event_bus.dart';

class EditMemberScreen extends StatefulWidget {
  final Member member;
  final Database database;
  
  const EditMemberScreen({
    Key? key, 
    required this.member,
    required this.database,
  }) : super(key: key);

  @override
  _EditMemberScreenState createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final MemberService _memberService = MemberService();
  
  // Personal info controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  
  // For monthly membership
  bool _hasMonthlyMembership = false;
  DateTime _monthlyStartDate = DateTime.now();
  DateTime _monthlyEndDate = DateTime.now().add(const Duration(days: 30));
  List<String> _monthlyLessons = [];
  List<String> _allLessonTypes = [];
  
  // For package membership
  Map<String, int> _packageSessions = {};
  
  bool _isLoading = true;
  bool _hasChanges = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _nameController = TextEditingController(text: widget.member.name);
    _phoneController = TextEditingController(text: widget.member.phone);
    
    // Initialize membership info
    _hasMonthlyMembership = widget.member.hasMonthlyMembership;
    if (widget.member.startDate != null) {
      _monthlyStartDate = widget.member.startDate;
    }
    if (widget.member.endDate != null) {
      _monthlyEndDate = widget.member.endDate!;
    }
    
    // Load data
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get all available lesson types
      _allLessonTypes = await _memberService.getAllLessonTypes();
      
      // Set monthly lessons
      _monthlyLessons = List.from(widget.member.lessons);
      
      // Set package sessions
      _packageSessions = Map.from(widget.member.lessonSessions);
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: AppBar(
          title: Text('editMember'.tr + ': ${widget.member.name}'),
          actions: [
            TextButton(
              onPressed: _saveMember,
              child: Text('save'.tr, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildForm(),
      ),
    );
  }
  
  Future<bool> _confirmExit() async {
    if (!_hasChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('areYouSure'.tr),
        content: Text('Kaydedilmemiş değişiklikleriniz var. Çıkmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Personal Info Card
          _buildPersonalInfoCard(),
          const SizedBox(height: 16),
          
          // Monthly Membership Card
          _buildMonthlyMembershipCard(),
          const SizedBox(height: 16),
          
          // Package Sessions Card - UPDATED: Always show package sessions
          _buildPackageSessionsCard(),
          const SizedBox(height: 24),
          
          // Save Button
          ElevatedButton(
            onPressed: _saveMember,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'personalInfo'.tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'name'.tr,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) => (value?.isEmpty ?? true) ? 'Lütfen bir isim girin' : null,
              onChanged: (_) => _hasChanges = true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'phone'.tr,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (_) => _hasChanges = true,
            ),
          ],
        ),
      ),
    );
  }
  
  // UPDATED: Monthly membership card - remains enabled regardless of package sessions
  Widget _buildMonthlyMembershipCard() {
    final dateFormat = DateFormat('MMM d, yyyy');
    
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
                  'monthlyMembership'.tr,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: _hasMonthlyMembership,
                  onChanged: (value) {
                    setState(() {
                      _hasMonthlyMembership = value;
                      _hasChanges = true;
                    });
                  },
                ),
              ],
            ),
            if (_hasMonthlyMembership) ...[
              const Divider(),
              // Start date picker
              ListTile(
                title: Text('startDate'.tr),
                subtitle: Text(dateFormat.format(_monthlyStartDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _monthlyStartDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _monthlyStartDate = date;
                      _hasChanges = true;
                    });
                  }
                },
              ),
              // End date picker
              ListTile(
                title: Text('endDate'.tr),
                subtitle: Text(dateFormat.format(_monthlyEndDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _monthlyEndDate,
                    firstDate: _monthlyStartDate,
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _monthlyEndDate = date;
                      _hasChanges = true;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                'availableLessons'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allLessonTypes.map((lesson) {
                  final isSelected = _monthlyLessons.contains(lesson);
                  return FilterChip(
                    label: Text(lesson),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _monthlyLessons.add(lesson);
                        } else {
                          _monthlyLessons.remove(lesson);
                        }
                        _hasChanges = true;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            if (!_hasMonthlyMembership) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Aylık üyelik devre dışı. Tarihleri ve dersleri ayarlamak için etkinleştirin.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // UPDATED: Package sessions card - always shown
  Widget _buildPackageSessionsCard() {
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
                  'packageMembership'.tr,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addPackageSession,
                  icon: const Icon(Icons.add),
                  label: Text('add'.tr),
                ),
              ],
            ),
            const Divider(),
            if (_packageSessions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Paket seans eklenmedi'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _packageSessions.length,
                itemBuilder: (context, index) {
                  final entry = _packageSessions.entries.elementAt(index);
                  return ListTile(
                    title: Text(entry.key),
                    subtitle: Text('${entry.value} ' + 'remainingSessions'.tr),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editPackageSession(entry.key, entry.value),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _packageSessions.remove(entry.key);
                              _hasChanges = true;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Not: Üyeler aynı anda aylık üyelik ve paket seanslarına sahip olabilirler.',
                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // UPDATED: Add package session - improved UI and handling
  void _addPackageSession() async {
    // Find available lesson types (those not already in package sessions)
    final availableLessons = _allLessonTypes
        .where((type) => !_packageSessions.containsKey(type))
        .toList();
    
    if (availableLessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm ders türleri zaten paketlere sahip'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    String? selectedLesson = availableLessons.first;
    int sessions = 10;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('addLesson'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'lessonType'.tr,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.fitness_center),
                ),
                value: selectedLesson,
                items: availableLessons
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedLesson = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'remainingSessions'.tr,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.confirmation_number),
                ),
                keyboardType: TextInputType.number,
                initialValue: sessions.toString(),
                onChanged: (value) {
                  sessions = int.tryParse(value) ?? 10;
                  if (sessions <= 0) sessions = 1; // Ensure at least 1 session
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Not: Üyeler aynı anda aylık ve paket derslere sahip olabilirler.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context, 
                {'lesson': selectedLesson, 'sessions': sessions},
              ),
              child: Text('add'.tr),
            ),
          ],
        ),
      ),
    );
    
    if (result != null && result['lesson'] != null) {
      setState(() {
        _packageSessions[result['lesson']] = result['sessions'];
        _hasChanges = true;
      });
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['sessions']} ${result['lesson']} seansı eklendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  // UPDATED: Edit package session with improved UI
  void _editPackageSession(String lessonType, int currentSessions) async {
    int sessions = currentSessions;
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$lessonType ' + 'edit'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'remainingSessions'.tr,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.confirmation_number),
              ),
              keyboardType: TextInputType.number,
              initialValue: currentSessions.toString(),
              onChanged: (value) {
                sessions = int.tryParse(value) ?? currentSessions;
                if (sessions <= 0) sessions = 1; // Ensure at least 1 session
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, sessions),
            child: Text('save'.tr),
          ),
        ],
      ),
    );
    
    if (result != null) {
      setState(() {
        _packageSessions[lessonType] = result;
        _hasChanges = true;
      });
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$lessonType $result seans olarak güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  // UPDATED: Save member method to better handle both membership types
  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate membership settings
    if (_hasMonthlyMembership && _monthlyLessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen aylık üyelik için en az bir ders seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Check if member has any valid membership option
    if (!_hasMonthlyMembership && _packageSessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen aylık üyeliği etkinleştirin veya en az bir paket ekleyin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Create updated member
      final updatedMember = Member(
        id: widget.member.id,
        name: _nameController.text,
        phone: _phoneController.text,
        // Member can have both types, but we set the primary type for UI display
        membershipType: _hasMonthlyMembership ? 'Monthly' : 'Package',
        hasMonthlyMembership: _hasMonthlyMembership,
        // Monthly dates
        startDate: _monthlyStartDate,
        endDate: _hasMonthlyMembership ? _monthlyEndDate : null,
        // Calculate total sessions for easy reference
        remainingSessions: _packageSessions.isNotEmpty 
            ? _packageSessions.values.reduce((a, b) => a + b) 
            : null,
      );
      
      // Update member in database
      final success = await _memberService.updateMember(
        updatedMember, 
        _monthlyLessons, 
        _packageSessions
      );
      
      if (!mounted) return;
      
      if (success) {
        // Notify the app to refresh member list
        eventBus.refreshMembers();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updatedMember.name} başarıyla güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
        _hasChanges = false;
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Üye güncellenirken hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}