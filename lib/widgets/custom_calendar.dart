import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/calendar_event.dart';

class CustomCalendar extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(DateTime) onPageChanged;
  final Map<DateTime, List<CalendarEvent>> events;
  final CalendarFormat calendarFormat;
  final Function(CalendarFormat) onFormatChanged;
  
  const CustomCalendar({
    Key? key,
    required this.focusedDay,
    this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.events,
    required this.calendarFormat,
    required this.onFormatChanged,
  }) : super(key: key);

  @override
  _CustomCalendarState createState() => _CustomCalendarState();
}

class _CustomCalendarState extends State<CustomCalendar> {
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final eventDay = DateTime(day.year, day.month, day.day);
    return widget.events[eventDay] ?? [];
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: widget.focusedDay,
          calendarFormat: widget.calendarFormat,
          eventLoader: _getEventsForDay,
          selectedDayPredicate: (day) {
            return widget.selectedDay != null && isSameDay(widget.selectedDay!, day);
          },
          onDaySelected: widget.onDaySelected,
          onFormatChanged: widget.onFormatChanged,
          onPageChanged: widget.onPageChanged,
          calendarStyle: CalendarStyle(
            markersMaxCount: 3,
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonShowsNext: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
