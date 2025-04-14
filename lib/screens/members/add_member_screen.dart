import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/member.dart';
import '../../services/member_service.dart';
import '../../services/localization_service.dart';
import '../../events/event_bus.dart';

class AddMemberScreen extends StatefulWidget {
  final Database database;
  
  const AddMemberScreen({Key? key, required this.database}) : super(key: key);

  @override
  _AddMemberScreenState createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final MemberService _memberService = MemberService();
  
  // Personal info controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Available lesson types
  List<String> _lessonTypes = [];
  
  // Membership selection
  bool _hasMonthlyMembership = true;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  List<String> _selectedMonthlyLessons = [];
  
  // Package sessions
  Map<String, int> _packageSessions = {};
  
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadLessonTypes();
  }
  
  Future<void> _loadLessonTypes() async {
    setState(() => _isLoading = true);
    
    try {
      _lessonTypes = await _memberService.getAllLessonTypes();
    } catch (e) {
      _showErrorSnackBar('error'.tr + ': $e');
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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('addMember'.tr),
        actions: [
          TextButton(
            onPressed: _saveMember,
            child: Text(
              'save'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }
  
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Personal info card
          _buildPersonalInfoCard(),
          const SizedBox(height: 16),
          
          // Monthly membership card - UPDATED: Always shown
          _buildMonthlyMembershipCard(),
          const SizedBox(height: 16),
          
          // Package sessions card - UPDATED: Always shown
          _buildPackageSessionsCard(),
          
          const SizedBox(height: 24),
          
          // Save button
          ElevatedButton(
            onPressed: _saveMember,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'lütfen bir isim giriniz';
                }
                return null;
              },
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
            ),
          ],
        ),
      ),
    );
  }
  
  // UPDATED: Monthly membership card with toggle
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
                subtitle: Text(dateFormat.format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                      // Update end date to be one month after start date
                      _endDate = DateTime(date.year, date.month + 1, date.day);
                    });
                  }
                },
              ),
              
              // End date picker
              ListTile(
                title: Text('endDate'.tr),
                subtitle: Text(dateFormat.format(_endDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: _startDate,
                    lastDate: DateTime(2030),
                  );
                  
                  if (date != null) {
                    setState(() {
                      _endDate = date;
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
              
              // Lesson selection chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _lessonTypes.map((lesson) {
                  final isSelected = _selectedMonthlyLessons.contains(lesson);
                  return FilterChip(
                    label: Text(lesson),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedMonthlyLessons.add(lesson);
                        } else {
                          _selectedMonthlyLessons.remove(lesson);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            
            if (!_hasMonthlyMembership) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Aylık üyelik devre dışı. Tarihleri ve dersleri ayarlamak için etkinleştirin.',
                  style: TextStyle(color: Colors.grey),
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
                'Not: Üyeler aynı anda paket seans ve aylık üyelik alabilirler.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // UPDATED: Add package session with improved UI
  void _addPackageSession() async {
    // Find available lesson types (those not already in package sessions)
    final availableLessons = _lessonTypes
        .where((lesson) => !_packageSessions.containsKey(lesson))
        .toList();
    
    if (availableLessons.isEmpty) {
      _showErrorSnackBar('Tüm ders türleri zaten paketlere sahip');
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
                  labelText: 'lessonName'.tr,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.fitness_center),
                ),
                value: selectedLesson,
                items: availableLessons
                    .map((lesson) => DropdownMenuItem(value: lesson, child: Text(lesson)))
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
                {'ders': selectedLesson, 'seans': sessions},
              ),
              child: Text('add'.tr),
            ),
          ],
        ),
      ),
    );
    
    if (result != null && result['ders'] != null) {
      setState(() {
        _packageSessions[result['ders']] = result['seans'];
      });
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['seans']} ${result['ders']} seansı eklendi'),
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
  
  // UPDATED: Save member method to handle both membership types
  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate membership options
    if (!_hasMonthlyMembership && _packageSessions.isEmpty) {
      _showErrorSnackBar('Lütfen en az bir paket seansı ekleyin veya aylık üyeliği etkinleştirin');
      return;
    }
    
    if (_hasMonthlyMembership && _selectedMonthlyLessons.isEmpty) {
      _showErrorSnackBar('Lütfen aylık üyelik için en az bir ders seçin');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Create the member object
      final member = Member(
        name: _nameController.text,
        phone: _phoneController.text,
        // Primary membership type for display (can have both)
        membershipType: _hasMonthlyMembership ? 'Monthly' : 'Package',
        hasMonthlyMembership: _hasMonthlyMembership,
        startDate: _startDate,
        endDate: _hasMonthlyMembership ? _endDate : null,
        // Calculate total sessions for reference
        remainingSessions: _packageSessions.isNotEmpty 
            ? _packageSessions.values.reduce((a, b) => a + b) 
            : null,
      );
      
      // Save to database
      final memberId = await _memberService.addMember(
        member, 
        _selectedMonthlyLessons, 
        _packageSessions,
      );
      
      if (!mounted) return;
      
      if (memberId > 0) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} başarıyla eklendi'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Trigger a refresh of the members list
        eventBus.refreshMembers();
        
        // Navigate back
        Navigator.pop(context);
      } else {
        _showErrorSnackBar('Üye eklenirken hata oluştu');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Hata: $e');
      setState(() => _isLoading = false);
    }
  }
}