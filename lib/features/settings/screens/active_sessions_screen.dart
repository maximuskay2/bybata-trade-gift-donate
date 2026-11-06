import 'package:flutter/material.dart';
import 'package:bybata/features/profile/services/users_api.dart';
import 'package:intl/intl.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  final UsersApi _usersApi = UsersApi();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions = await _usersApi.getActiveSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load sessions: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Session'),
        content: const Text('Are you sure you want to revoke this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _usersApi.revokeSession(sessionId);
      if (mounted) {
        AppToast.show(context, 'Session revoked successfully');
        _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to revoke session: $e');
      }
    }
  }

  Future<void> _revokeAllSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke All Sessions'),
        content: const Text(
          'This will log you out from all devices except this one. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _usersApi.revokeAllSessions();
      if (mounted) {
        AppToast.show(context, 'All sessions revoked successfully');
        _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to revoke sessions: $e');
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getDeviceInfo(Map<String, dynamic> session) {
    // Try to extract device info from metadata if available
    final userAgent = session['userAgent'] as String?;
    if (userAgent != null) {
      if (userAgent.contains('iPhone') || userAgent.contains('iOS')) {
        return 'iPhone';
      } else if (userAgent.contains('Android')) {
        return 'Android';
      } else if (userAgent.contains('Windows')) {
        return 'Windows';
      } else if (userAgent.contains('Mac')) {
        return 'Mac';
      } else if (userAgent.contains('Linux')) {
        return 'Linux';
      }
    }
    return 'Unknown Device';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Sessions'),
        actions: [
          if (_sessions.length > 1)
            TextButton(
              onPressed: _revokeAllSessions,
              child: const Text(
                'Revoke All',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const BybataLoader()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSessions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _sessions.isEmpty
                  ? const Center(
                      child: Text('No active sessions found'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        itemCount: _sessions.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final sessionId = session['id'] as String;
                          final createdAt = session['createdAt'] as String?;
                          final expiresAt = session['expiresAt'] as String?;
                          final isActive = session['isActive'] as bool? ?? true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActive
                                    ? Colors.green
                                    : Colors.grey,
                                child: Icon(
                                  Icons.devices,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(_getDeviceInfo(session)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (createdAt != null)
                                    Text('Created: ${_formatDate(createdAt)}'),
                                  if (expiresAt != null)
                                    Text('Expires: ${_formatDate(expiresAt)}'),
                                  Text(
                                    isActive ? 'Active' : 'Expired',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.green
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isActive
                                  ? IconButton(
                                      icon: const Icon(Icons.logout,
                                          color: Colors.red),
                                      onPressed: () => _revokeSession(sessionId),
                                      tooltip: 'Revoke session',
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

