import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/localization_service.dart';
import 'members/members_screen.dart';
import 'lessons/lessons_screen.dart';
import 'calendar/calendar_screen.dart';
import 'reports/reports_screen.dart';
import 'check_in/check_in_screen.dart';
import 'members/add_member_screen.dart';

class MainScreen extends StatefulWidget {
  final Database database;
  
  const MainScreen({Key? key, required this.database}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  late final List<_NavDestination> _destinations;
  
  @override
  void initState() {
    super.initState();
    _destinations = [
      _NavDestination(
        title: 'members'.tr,
        icon: Icons.people,
        screen: MembersScreen(database: widget.database),
        fabIcon: Icons.person_add,
        fabTooltip: 'addMember'.tr,
        fabAction: _navigateToAddMember,
      ),
      _NavDestination(
        title: 'lessons'.tr,
        icon: Icons.fitness_center,
        screen: LessonsScreen(database: widget.database),
        fabIcon: Icons.add_box,
        fabTooltip: 'addLesson'.tr,
        fabAction: null, // Not implemented in original code
      ),
      _NavDestination(
        title: 'calendar'.tr,
        icon: Icons.calendar_today,
        screen: CalendarScreen(database: widget.database),
        fabIcon: Icons.add_task,
        fabTooltip: 'quickCheckIn'.tr,
        fabAction: _navigateToCheckIn,
      ),
      _NavDestination(
        title: 'reports'.tr,
        icon: Icons.bar_chart,
        screen: ReportsScreen(database: widget.database),
        fabIcon: Icons.print,
        fabTooltip: 'reports'.tr,
        fabAction: null, // Not implemented in original code
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentDestination = _destinations[_selectedIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Flowers Fit - ${currentDestination.title}'),
        actions: [
          if (_selectedIndex == 0) // Members screen
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // Search is now handled directly in the members screen
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Show settings dialog
              _showSettingsDialog();
            },
          ),
        ],
      ),
      // Use the current screen directly instead of IndexedStack to avoid Hero conflicts
      body: currentDestination.screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _destinations.map((dest) => 
          NavigationDestination(
            icon: Icon(dest.icon),
            label: dest.title,
          )
        ).toList(),
      ),
      floatingActionButton: currentDestination.fabAction != null
          ? FloatingActionButton(
              // Add a unique heroTag to prevent conflicts
              heroTag: "fab_${currentDestination.title}",
              onPressed: currentDestination.fabAction,
              child: Icon(currentDestination.fabIcon),
              tooltip: currentDestination.fabTooltip,
            )
          : null,
    );
  }
  
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('appInfo'.tr),
              subtitle: Text('appTitle'.tr + ' v1.0'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: Text('theme'.tr),
              subtitle: const Text('System default'),
              onTap: () {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr),
          ),
        ],
      ),
    );
  }
  
  void _refreshCurrentScreen() {
    setState(() {
      // Re-create the current screen to force a refresh
      final index = _selectedIndex;
      _destinations[index] = _NavDestination(
        title: _destinations[index].title,
        icon: _destinations[index].icon,
        screen: _createScreen(index),
        fabIcon: _destinations[index].fabIcon,
        fabTooltip: _destinations[index].fabTooltip,
        fabAction: _destinations[index].fabAction,
      );
    });
  }
  
  Widget _createScreen(int index) {
    switch (index) {
      case 0:
        return MembersScreen(database: widget.database);
      case 1:
        return LessonsScreen(database: widget.database);
      case 2:
        return CalendarScreen(database: widget.database);
      case 3:
        return ReportsScreen(database: widget.database);
      default:
        return MembersScreen(database: widget.database);
    }
  }
  
  void _navigateToAddMember() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/add_member'), // Unique route name
        builder: (context) => AddMemberScreen(database: widget.database),
      ),
    ).then((_) {
      // Refresh the current screen when returning
      _refreshCurrentScreen();
    });
  }
  
  void _navigateToCheckIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/check_in'), // Unique route name
        builder: (context) => CheckInScreen(database: widget.database),
      ),
    ).then((_) {
      // Refresh the current screen when returning
      _refreshCurrentScreen();
    });
  }
}

class _NavDestination {
  final String title;
  final IconData icon;
  final Widget screen;
  final IconData fabIcon;
  final String fabTooltip;
  final VoidCallback? fabAction;
  
  const _NavDestination({
    required this.title,
    required this.icon,
    required this.screen,
    required this.fabIcon,
    required this.fabTooltip,
    this.fabAction,
  });
}