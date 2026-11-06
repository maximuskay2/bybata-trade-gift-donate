import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/chat_provider.dart';
import '../../settings/widgets/settings_section.dart';
import '../../settings/widgets/settings_tile.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  static const _kNotifications = 'chat_settings_notifications';
  static const _kPreview = 'chat_settings_preview';
  static const _kSounds = 'chat_settings_sounds';
  static const _kVibrate = 'chat_settings_vibrate';
  static const _kReadReceipts = 'chat_settings_read_receipts';
  static const _kTypingIndicators = 'chat_settings_typing_indicators';

  bool _isLoading = true;
  bool _notifications = true;
  bool _preview = true;
  bool _sounds = true;
  bool _vibrate = true;
  bool _readReceipts = true;
  bool _typingIndicators = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifications = prefs.getBool(_kNotifications) ?? true;
      _preview = prefs.getBool(_kPreview) ?? true;
      _sounds = prefs.getBool(_kSounds) ?? true;
      _vibrate = prefs.getBool(_kVibrate) ?? true;
      _readReceipts = prefs.getBool(_kReadReceipts) ?? true;
      _typingIndicators = prefs.getBool(_kTypingIndicators) ?? true;
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(String key, bool value, ValueSetter<bool> apply) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() => apply(value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chat Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const BybataLoader()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSection(
                  title: 'Notifications',
                  icon: Icons.notifications_outlined,
                  children: [
                    SettingsTile.switchTile(
                      title: 'Chat notifications',
                      subtitle: 'Get notified about new messages',
                      value: _notifications,
                      onChanged: (v) => _updateSetting(
                        _kNotifications,
                        v,
                        (value) => _notifications = value,
                      ),
                    ),
                    SettingsTile.switchTile(
                      title: 'Message preview',
                      subtitle: 'Show message content in notifications',
                      value: _preview,
                      onChanged: _notifications
                          ? (v) => _updateSetting(
                                _kPreview,
                                v,
                                (value) => _preview = value,
                              )
                          : null,
                      enabled: _notifications,
                    ),
                    SettingsTile.switchTile(
                      title: 'Sound',
                      subtitle: 'Play sound for new messages',
                      value: _sounds,
                      onChanged: _notifications
                          ? (v) => _updateSetting(
                                _kSounds,
                                v,
                                (value) => _sounds = value,
                              )
                          : null,
                      enabled: _notifications,
                    ),
                    SettingsTile.switchTile(
                      title: 'Vibrate',
                      subtitle: 'Vibrate on new messages',
                      value: _vibrate,
                      onChanged: _notifications
                          ? (v) => _updateSetting(
                                _kVibrate,
                                v,
                                (value) => _vibrate = value,
                              )
                          : null,
                      enabled: _notifications,
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Privacy',
                  icon: Icons.lock_outline,
                  children: [
                    SettingsTile.switchTile(
                      title: 'Read receipts',
                      subtitle: 'Let others know when you read messages',
                      value: _readReceipts,
                      onChanged: (v) => _updateSetting(
                        _kReadReceipts,
                        v,
                        (value) => _readReceipts = value,
                      ),
                    ),
                    SettingsTile.switchTile(
                      title: 'Typing indicators',
                      subtitle: 'Show when you are typing',
                      value: _typingIndicators,
                      onChanged: (v) => _updateSetting(
                        _kTypingIndicators,
                        v,
                        (value) => _typingIndicators = value,
                      ),
                    ),
                    Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        return Column(
                          children: [
                            SettingsTile.switchTile(
                              title: 'Show online status',
                              subtitle:
                                  'Show the green dot and "online" text in chat screens',
                              value: chatProvider.showOnlineStatus,
                              onChanged: (v) =>
                                  chatProvider.setShowOnlineStatus(v),
                            ),
                            SettingsTile.switchTile(
                              title: 'Show last seen',
                              subtitle:
                                  'Show "last seen" text for offline users',
                              value: chatProvider.showLastSeen,
                              onChanged: chatProvider.showOnlineStatus
                                  ? (v) => chatProvider.setShowLastSeen(v)
                                  : null,
                              enabled: chatProvider.showOnlineStatus,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
