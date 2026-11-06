import 'package:flutter/material.dart';
import 'package:bybata/core/widgets/bybata_glass_container.dart';
import 'package:bybata/features/profile/services/email_preferences_api.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final EmailPreferencesApi _api = EmailPreferencesApi();
  EmailPreferences _prefs = const EmailPreferences();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await _api.getPreferences();
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppToast.show(context, 'Failed to load preferences: $e');
      }
    }
  }

  Future<void> _updateWeeklyReport(bool value) async {
    final previous = _prefs.weeklyReport;
    setState(() {
      _prefs = _prefs.copyWith(weeklyReport: value);
      _isSaving = true;
    });
    try {
      await _api.updatePreferences(_prefs);
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.show(context, value
                  ? 'Weekly report emails enabled'
                  : 'Weekly report emails disabled',);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _prefs = _prefs.copyWith(weeklyReport: previous);
          _isSaving = false;
        });
        AppToast.show(context, 'Failed to update: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        elevation: 0,
      ),
      backgroundColor: colorScheme.background,
      body: _isLoading
          ? const BybataLoader()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email preferences',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ByBataGlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text('Weekly Report'),
                            subtitle: const Text(
                              'Receive a weekly summary of your activity and stats via email',
                            ),
                            value: _prefs.weeklyReport,
                            onChanged: _isSaving
                                ? null
                                : (value) => _updateWeeklyReport(value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
