import 'package:flutter/material.dart';
import '../models/member.dart';

class MemberListTile extends StatelessWidget {
  final Member member;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCheckIn;
  
  const MemberListTile({
    Key? key,
    required this.member,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onCheckIn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isExpired = member.statusText.contains('Expired') || 
                      member.statusText.contains('No sessions');
    
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isExpired ? Colors.red.shade300 : Colors.green.shade300,
                    ),
                  ),
                  child: Text(
                    member.statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpired ? Colors.red.shade800 : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: isExpired ? Colors.red.shade200 : Theme.of(context).colorScheme.primary,
          child: Text(
            member.name.isNotEmpty ? member.name[0] : '?',
            style: TextStyle(
              color: isExpired ? Colors.red.shade900 : Colors.white,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit' && onEdit != null) {
              onEdit!();
            } else if (value == 'delete' && onDelete != null) {
              onDelete!();
            } else if (value == 'checkin' && onCheckIn != null) {
              onCheckIn!();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'checkin',
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline),
                  SizedBox(width: 8),
                  Text('Check-in'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
