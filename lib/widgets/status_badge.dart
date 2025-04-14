import 'package:flutter/material.dart';

enum BadgeStatus {
  active,
  warning,
  error,
  info,
}

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeStatus status;
  final double fontSize;
  
  const StatusBadge({
    Key? key,
    required this.text,
    required this.status,
    this.fontSize = 12,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _getTextColor(),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Color _getBackgroundColor() {
    switch (status) {
      case BadgeStatus.active:
        return Colors.green.shade50;
      case BadgeStatus.warning:
        return Colors.orange.shade50;
      case BadgeStatus.error:
        return Colors.red.shade50;
      case BadgeStatus.info:
        return Colors.blue.shade50;
    }
  }
  
  Color _getBorderColor() {
    switch (status) {
      case BadgeStatus.active:
        return Colors.green.shade300;
      case BadgeStatus.warning:
        return Colors.orange.shade300;
      case BadgeStatus.error:
        return Colors.red.shade300;
      case BadgeStatus.info:
        return Colors.blue.shade300;
    }
  }
  
  Color _getTextColor() {
    switch (status) {
      case BadgeStatus.active:
        return Colors.green.shade800;
      case BadgeStatus.warning:
        return Colors.orange.shade800;
      case BadgeStatus.error:
        return Colors.red.shade800;
      case BadgeStatus.info:
        return Colors.blue.shade800;
    }
  }
}
