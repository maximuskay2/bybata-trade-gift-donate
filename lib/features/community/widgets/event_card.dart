import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Widget for displaying a community event
class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onTap;
  final VoidCallback? onRegister;
  final bool isRegistered;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.onRegister,
    this.isRegistered = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = event['title'] ?? 'Untitled Event';
    final description = event['description'] ?? '';
    final startDate = event['startDate'] is String
        ? DateTime.tryParse(event['startDate'])
        : event['startDate'] as DateTime?;
    final endDate = event['endDate'] is String
        ? DateTime.tryParse(event['endDate'])
        : event['endDate'] as DateTime?;
    final location = event['location'] ?? '';
    final isOnline = event['isOnline'] ?? false;
    final onlineLink = event['onlineLink'];
    final maxAttendees = event['maxAttendees'];
    final attendeeCount = event['attendeeCount'] ?? event['_count']?['attendees'] ?? 0;
    final status = event['status'] ?? 'UPCOMING';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatStatus(status),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  if (isRegistered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Registered',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Date & Time
                  if (startDate != null)
                    _buildInfoRow(
                      Icons.calendar_today,
                      _formatEventDate(startDate, endDate),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Location
                  if (isOnline && onlineLink != null)
                    _buildInfoRow(
                      Icons.video_call,
                      'Online Event',
                    )
                  else if (location.isNotEmpty)
                    _buildInfoRow(
                      Icons.location_on,
                      location,
                    ),
                  
                  // Attendees
                  if (maxAttendees != null || attendeeCount > 0) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.people,
                      maxAttendees != null
                          ? '$attendeeCount / $maxAttendees attendees'
                          : '$attendeeCount attendees',
                    ),
                  ],
                ],
              ),
            ),
            
            // Action Button
            if (onRegister != null && status == 'UPCOMING')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isRegistered ? null : onRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRegistered ? Colors.grey : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isRegistered ? 'Registered' : 'Register'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'UPCOMING':
        return AppColors.primary;
      case 'ONGOING':
        return Colors.green;
      case 'COMPLETED':
        return Colors.grey;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status.toUpperCase()) {
      case 'UPCOMING':
        return 'Upcoming';
      case 'ONGOING':
        return 'Ongoing';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatEventDate(DateTime startDate, DateTime? endDate) {
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');
    
    if (endDate != null && endDate.day != startDate.day) {
      return '${dateFormat.format(startDate)} ${timeFormat.format(startDate)} - ${dateFormat.format(endDate)} ${timeFormat.format(endDate)}';
    } else if (endDate != null) {
      return '${dateFormat.format(startDate)} ${timeFormat.format(startDate)} - ${timeFormat.format(endDate)}';
    } else {
      return '${dateFormat.format(startDate)} ${timeFormat.format(startDate)}';
    }
  }
}

