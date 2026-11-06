import 'package:flutter/material.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_utils.dart';
import '../models/app_settings.dart';
import '../models/faq_item.dart';
import '../models/support_ticket.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

// Theme Selector Widget
class ThemeSelector extends StatelessWidget {
  final ThemeProvider themeProvider;

  const ThemeSelector({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose Theme',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...themeProvider.availableThemes.map((themeType) {
            final isSelected = themeProvider.themeModeSetting == themeType;
            return ListTile(
              leading: Icon(_getThemeIcon(themeType)),
              title: Text(_getThemeDisplayName(themeType)),
              trailing: isSelected
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                HapticUtils.selection();
                themeProvider.setThemeMode(themeType);
                Navigator.pop(context);
              },
            );
          }),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Glass Mode'),
            subtitle: const Text('Enable glassmorphism overlay'),
            value: themeProvider.isGlassModeEnabled,
            onChanged: (_) {
              HapticUtils.selection();
              themeProvider.toggleGlassMode();
            },
          ),
        ],
      ),
    );
  }

  IconData _getThemeIcon(AppThemeMode themeType) {
    switch (themeType) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.settings_suggest;
    }
  }

  String _getThemeDisplayName(AppThemeMode themeType) {
    switch (themeType) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }
}

// Language Selector Widget
class LanguageSelector extends StatelessWidget {
  final String currentLanguage;
  final ValueChanged<String> onLanguageChanged;

  const LanguageSelector({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final languages = {
      'en': 'English',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'pt': 'Português',
      'it': 'Italiano',
      'ja': '日本語',
      'ko': '한국어',
      'zh': '中文',
      'ar': 'العربية',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose Language',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...languages.entries.map((entry) {
            final isSelected = currentLanguage == entry.key;
            return ListTile(
              title: Text(entry.value),
              trailing: isSelected
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                HapticUtils.selection();
                onLanguageChanged(entry.key);
              },
            );
          }),
        ],
      ),
    );
  }
}

// Accessibility Settings Widget
class AccessibilitySettings extends StatelessWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const AccessibilitySettings({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.accessibility,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Accessibility',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('High Contrast'),
              subtitle: const Text('Increase color contrast for better visibility'),
              value: settings.highContrast,
              onChanged: (value) {
                onSettingsChanged(settings.copyWith(highContrast: value));
              },
            ),
            SwitchListTile(
              title: const Text('Reduce Motion'),
              subtitle: const Text('Minimize animations and transitions'),
              value: settings.reduceMotion,
              onChanged: (value) {
                onSettingsChanged(settings.copyWith(reduceMotion: value));
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Text Size'),
              subtitle: Text('Current: ${(settings.textScale * 100).round()}%'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: settings.textScale > 0.8
                        ? () {
                            final newScale = (settings.textScale - 0.1).clamp(0.8, 2.0);
                            onSettingsChanged(settings.copyWith(textScale: newScale));
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    onPressed: settings.textScale < 2.0
                        ? () {
                            final newScale = (settings.textScale + 0.1).clamp(0.8, 2.0);
                            onSettingsChanged(settings.copyWith(textScale: newScale));
                          }
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Contact Method Card Widget
class ContactMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? availability;
  final bool isRecommended;
  final VoidCallback onTap;

  const ContactMethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.availability,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Recommended',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (availability != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        availability!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// FAQ Expansion Tile Widget
class FAQExpansionTile extends StatelessWidget {
  final FAQItem faq;
  final ValueChanged<bool> onHelpful;

  const FAQExpansionTile({
    super.key,
    required this.faq,
    required this.onHelpful,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faq.answer,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Was this helpful?'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => onHelpful(true),
                      icon: const Icon(Icons.thumb_up, size: 16),
                      label: const Text('Yes'),
                    ),
                    TextButton.icon(
                      onPressed: () => onHelpful(false),
                      icon: const Icon(Icons.thumb_down, size: 16),
                      label: const Text('No'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Support Chat Widget (placeholder)
class SupportChatWidget extends StatelessWidget {
  const SupportChatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat, size: 64, color: scheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'Live Chat',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect with our support team for instant help',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const BybataLoadingIndicator(size: BybataLoadingSize.compact),
          const SizedBox(height: 16),
          const Text('Connecting to support...'),
        ],
      ),
    );
  }
}

// Ticket Status Card Widget
class TicketStatusCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;

  const TicketStatusCard({
    super.key,
    required this.ticket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ticket.status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ticket.status.displayName,
                      style: TextStyle(
                        color: ticket.status.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ticket.id,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket.subject,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ticket.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ticket.priority.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ticket.priority.displayName,
                      style: TextStyle(
                        color: ticket.priority.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ticket.category,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(ticket.lastUpdated),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}