import 'package:flutter/material.dart';
import '../models/support_ticket.dart';

class TicketStatusCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback? onTap;
  final VoidCallback? onUpdate;

  const TicketStatusCard({
    super.key,
    required this.ticket,
    this.onTap,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ticket #${ticket.id}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.subject,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatusChip(context),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildPriorityIndicator(context),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(ticket.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (ticket.lastUpdated != null) ...[
                    Text(
                      'Updated ${_formatDate(ticket.lastUpdated!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (ticket.assignedAgent != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Assigned to ${ticket.assignedAgent}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                      if (ticket.status != SupportTicketStatus.closed &&
                          ticket.status != SupportTicketStatus.resolved) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onUpdate,
                        icon: const Icon(Icons.message, size: 16),
                        label: const Text('Add Response'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (ticket.status) {
      case SupportTicketStatus.open:
        textColor = scheme.primary;
        backgroundColor = textColor.withValues(alpha: 0.1);
        icon = Icons.help_outline;
        break;
      case SupportTicketStatus.inProgress:
        textColor = scheme.secondary;
        backgroundColor = textColor.withValues(alpha: 0.1);
        icon = Icons.pending_actions;
        break;
      case SupportTicketStatus.waiting:
        textColor = scheme.tertiary;
        backgroundColor = textColor.withValues(alpha: 0.1);
        icon = Icons.schedule;
        break;
      case SupportTicketStatus.resolved:
        textColor = scheme.primary;
        backgroundColor = textColor.withValues(alpha: 0.1);
        icon = Icons.check_circle_outline;
        break;
      case SupportTicketStatus.closed:
        textColor = scheme.onSurfaceVariant;
        backgroundColor = textColor.withValues(alpha: 0.1);
        icon = Icons.close;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            ticket.status.displayName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityIndicator(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color;
    IconData icon;
    String label;

    switch (ticket.priority) {
      case SupportTicketPriority.low:
        color = scheme.primary;
        icon = Icons.keyboard_arrow_down;
        label = 'Low';
        break;
      case SupportTicketPriority.medium:
        color = scheme.secondary;
        icon = Icons.remove;
        label = 'Medium';
        break;
      case SupportTicketPriority.high:
        color = scheme.error.withValues(alpha: 0.8);
        icon = Icons.keyboard_arrow_up;
        label = 'High';
        break;
      case SupportTicketPriority.urgent:
        color = scheme.error;
        icon = Icons.priority_high;
        label = 'Urgent';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final weeksDifference = (difference.inDays / 7).floor();
      if (weeksDifference < 4) {
        return '${weeksDifference}w ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    }
  }
}

extension SupportTicketStatusExtension on SupportTicketStatus {
  String get displayName {
    switch (this) {
      case SupportTicketStatus.open:
        return 'Open';
      case SupportTicketStatus.inProgress:
        return 'In Progress';
      case SupportTicketStatus.waiting:
        return 'Waiting';
      case SupportTicketStatus.resolved:
        return 'Resolved';
      case SupportTicketStatus.closed:
        return 'Closed';
    }
  }
}
