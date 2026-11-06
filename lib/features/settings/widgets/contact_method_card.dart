import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class ContactMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String value;
  final VoidCallback? onTap;
  final Color? color;

  const ContactMethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap ?? () => _launchContact(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (color ?? Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color ?? Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: color ?? Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.launch,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchContact(BuildContext context) async {
    Uri? uri;
    
    try {
      if (title.toLowerCase().contains('email')) {
        uri = Uri(scheme: 'mailto', path: value);
      } else if (title.toLowerCase().contains('phone')) {
        uri = Uri(scheme: 'tel', path: value);
      } else if (title.toLowerCase().contains('website') || 
                 title.toLowerCase().contains('help center')) {
        uri = Uri.parse(value.startsWith('http') ? value : 'https://$value');
      }

      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showErrorSnackBar(context);
      }
    } catch (e) {
      _showErrorSnackBar(context);
    }
  }

  void _showErrorSnackBar(BuildContext context) {
    AppToast.error(context, 'Could not launch $title');
  }
}

// Factory constructors for common contact methods
extension ContactMethodCardFactory on ContactMethodCard {
  static ContactMethodCard email({
    required String email,
    VoidCallback? onTap,
  }) {
    return ContactMethodCard(
      icon: Icons.email_outlined,
      title: 'Email Support',
      description: 'Get help via email',
      value: email,
      onTap: onTap,
    );
  }

  static ContactMethodCard phone({
    required String phone,
    VoidCallback? onTap,
  }) {
    return ContactMethodCard(
      icon: Icons.phone_outlined,
      title: 'Phone Support',
      description: 'Call our support team',
      value: phone,
      onTap: onTap,
    );
  }

  static ContactMethodCard website({
    required String url,
    VoidCallback? onTap,
  }) {
    return ContactMethodCard(
      icon: Icons.language_outlined,
      title: 'Help Center',
      description: 'Visit our online help center',
      value: url,
      onTap: onTap,
    );
  }

  static ContactMethodCard chat({
    VoidCallback? onTap,
  }) {
    return ContactMethodCard(
      icon: Icons.chat_outlined,
      title: 'Live Chat',
      description: 'Chat with our support team',
      value: 'Start Chat',
      onTap: onTap,
    );
  }
}