import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/attendance_service.dart';
import '../../services/member_service.dart';
import '../../models/lesson.dart';

class LessonsScreen extends StatefulWidget {
  final Database database;
  
  const LessonsScreen({Key? key, required this.database}) : super(key: key);

  @override
  _LessonsScreenState createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MemberService _memberService = MemberService();
  
  List<String> _allLessonTypes = [];
  Map<String, int> _attendanceCounts = {};
  bool _isLoading = true;
  
  // Text controller for adding new lessons
  final TextEditingController _lessonNameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _lessonNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load lesson types and attendance counts in parallel
      await Future.wait([
        _loadLessonTypes(),
        _loadAttendanceCounts(),
      ]);
    } catch (e) {
      _showErrorMessage('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadLessonTypes() async {
    try {
      _allLessonTypes = await _memberService.getAllLessonTypes();
    } catch (e) {
      print('Error loading lesson types: $e');
      rethrow;
    }
  }
  
  Future<void> _loadAttendanceCounts() async {
    try {
      _attendanceCounts = await _attendanceService.getAttendanceCountByLessonType();
    } catch (e) {
      print('Error loading attendance counts: $e');
      rethrow;
    }
  }
  
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // Add a new lesson type
  Future<void> _addLessonType() async {
    _lessonNameController.clear();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Ders Ekle'),
        content: TextField(
          controller: _lessonNameController,
          decoration: const InputDecoration(
            labelText: 'Ders Adı',
            hintText: 'Yeni ders adı girin',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _lessonNameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      // Check if lesson type already exists
      if (_allLessonTypes.contains(result)) {
        _showErrorMessage('"$result" dersi zaten mevcut');
        return;
      }
      
      setState(() => _isLoading = true);
      
      try {
        // Add the new lesson type
        await _memberService.addLessonType(result);
        _showSuccessMessage('"$result" dersi başarıyla eklendi ');
        
        // Reload data
        await _loadLessonTypes();
      } catch (e) {
        _showErrorMessage('Error adding lesson type: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Remove a lesson type
  Future<void> _removeLessonType(String lessonType) async {
    // Check if the lesson type is in use (has attendance records)
    final count = _attendanceCounts[lessonType] ?? 0;
    
    // Ask for confirmation, with warning if the lesson is in use
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${lessonType} adlı dersi kaldır?'),
        content: count > 0
            ? Text('Bu dersin $count adet derse katılım kaydı var. Kaldırmak üye verilerine zarar verebilir. Kaldırmak istediğinize emin misiniz?')
            : const Text('Bu dersi kaldırmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      try {
        // Remove the lesson type
        await _memberService.removeLessonType(lessonType);
        _showSuccessMessage('"$lessonType" adlı ders başarıyla kaldırıldı');
        
        // Reload data
        await Future.wait([
          _loadLessonTypes(),
          _loadAttendanceCounts(),
        ]);
      } catch (e) {
        _showErrorMessage('Error removing lesson type: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Edit a lesson type name
  Future<void> _editLessonType(String oldName) async {
    _lessonNameController.text = oldName;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ders Adını Düzenle'),
        content: TextField(
          controller: _lessonNameController,
          decoration: const InputDecoration(
            labelText: 'Ders Adı',
            hintText: 'Ders için yeni ad girin',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _lessonNameController.text.trim();
              if (name.isNotEmpty && name != oldName) {
                Navigator.pop(context, name);
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty && result != oldName) {
      // Check if lesson type already exists
      if (_allLessonTypes.contains(result)) {
        _showErrorMessage('"$result" adlı ders halihazırda mevcut');
        return;
      }
      
      setState(() => _isLoading = true);
      
      try {
        // Update the lesson type
        await _memberService.updateLessonType(oldName, result);
        _showSuccessMessage('Dersin adı "$result" adına başarıyla değiştirildi');
        
        // Reload data
        await Future.wait([
          _loadLessonTypes(),
          _loadAttendanceCounts(),
        ]);
      } catch (e) {
        _showErrorMessage('Error updating lesson type: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildLessonStatisticsCard(),
                  const SizedBox(height: 16),
                  _buildLessonListCard(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLessonType,
        tooltip: 'Ders Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildLessonStatisticsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ders İstatistikleri',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            SizedBox(
              height: 250,
              child: _buildLessonChart(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLessonChart() {
    // Get the data for the bar chart
    final List<LessonAttendance> data = _allLessonTypes.map((lessonType) {
      return LessonAttendance(
        lessonType,
        _attendanceCounts[lessonType] ?? 0,
      );
    }).toList();
    
    // Sort the data by count (highest to lowest)
    data.sort((a, b) => b.count.compareTo(a.count));
    
    // Get the maximum value for scaling
    final maxCount = data.isNotEmpty 
        ? data.map((e) => e.count).reduce((a, b) => a > b ? a : b) 
        : 0;
    
    // Create a default placeholder text if there's no data
    if (data.isEmpty || maxCount == 0) {
      return const Center(
        child: Text(
          'Katılım verisi yok',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount * 1.2, // Add some space above the highest bar
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${data[groupIndex].lessonType}: ${data[groupIndex].count}',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= data.length) return const Text('');
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      data[value.toInt()].lessonType,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                reservedSize: 42,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: false,
          ),
          barGroups: List.generate(data.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data[index].count.toDouble(),
                  color: Theme.of(context).colorScheme.primary,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
  
  Widget _buildLessonListCard() {
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
                  'Mevcut Dersler',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: _addLessonType,
                  icon: const Icon(Icons.add),
                  label: const Text('Ders Ekle'),
                ),
              ],
            ),
            const Divider(),
            if (_allLessonTypes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Mevcut ders yok. İlk dersinizi ekleyin',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _allLessonTypes.length,
                itemBuilder: (context, index) {
                  final lessonType = _allLessonTypes[index];
                  final attendanceCount = _attendanceCounts[lessonType] ?? 0;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.fitness_center),
                    ),
                    title: Text(lessonType),
                    subtitle: Text('$attendanceCount adet derse katılım kaydı'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Ders adını düzenle',
                          onPressed: () => _editLessonType(lessonType),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Ders adını kaldır',
                          onPressed: () => _removeLessonType(lessonType),
                        ),
                      ],
                    ),
                    onTap: () => _showLessonDetails(lessonType, attendanceCount),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  void _showLessonDetails(String lessonType, int attendanceCount) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.fitness_center),
                ),
                const SizedBox(width: 16),
                Text(
                  lessonType,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Toplam Derse Katılım'),
              trailing: Text(
                '$attendanceCount',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _editLessonType(lessonType),
                  icon: const Icon(Icons.edit),
                  label: const Text('Düzenle'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Kapat'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _removeLessonType(lessonType);
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Kaldır'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LessonAttendance {
  final String lessonType;
  final int count;
  
  LessonAttendance(this.lessonType, this.count);
}