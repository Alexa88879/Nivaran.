// lib/widgets/issue_timeline_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/issue_model.dart';

class IssueTimelineWidget extends StatelessWidget {
  final Issue issue;
  final List<Map<String, dynamic>> statusUpdates;

  const IssueTimelineWidget({
    super.key,
    required this.issue,
    required this.statusUpdates,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Resolution Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (statusUpdates.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No status updates available yet.'),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: statusUpdates.length,
            itemBuilder: (context, index) {
              final update = statusUpdates[index];
              final timestamp = update['timestamp'] as Timestamp;
              final status = update['status'] as String;
              final updatedBy = update['updatedBy'] as String? ?? 'System';
              final comments = update['comments'] as String? ?? '';
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (index < statusUpdates.length - 1)
                          Container(
                            width: 2,
                            height: 50,
                            color: Colors.grey[300],
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate()),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          Text('Updated by: $updatedBy'),
                          if (comments.isNotEmpty) ...[  
                            const SizedBox(height: 4),
                            Text(comments),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'reported':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'under review':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
