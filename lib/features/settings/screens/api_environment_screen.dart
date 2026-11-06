import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bybata/core/api/api_client.dart';
import 'package:bybata/core/api/health_service.dart';
import 'package:bybata/core/config/env_config.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/utils/media_utils.dart';

class ApiEnvironmentScreen extends StatefulWidget {
  const ApiEnvironmentScreen({super.key});

  @override
  State<ApiEnvironmentScreen> createState() => _ApiEnvironmentScreenState();
}

class _ApiEnvironmentScreenState extends State<ApiEnvironmentScreen> {
  String _selected = EnvConfig.defaultBaseUrl;
  String _status = '';
  bool _loading = false;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await EnvConfig.getBaseUrl();
    setState(() {
      _selected = url;
      _customController.text = url;
    });
  }

  Future<void> _ping() async {
    setState(() {
      _loading = true;
      _status = '';
    });
    try {
      // Use ApiClient to be consistent
      final client = ApiClient(_selected, const FlutterSecureStorage());
      final health = HealthService(client.dio);
      final res = await health.getHealth();
      setState(() {
        _status = 'OK: ${res['status']} at ${res['timestamp']}';
      });
    } catch (e) {
      setState(() {
        _status = 'ERROR: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    await EnvConfig.setBaseUrl(_selected);
    MediaResolver.invalidateBaseUrl();
    if (mounted) {
      AppToast.show(context, 'API base URL saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = EnvConfig.profiles();
    return Scaffold(
      appBar: AppBar(title: const Text('API Environment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Select environment'),
          const SizedBox(height: 8),
          ...profiles.map((p) => RadioListTile<String>(
                title: Text('${p.name} (${p.url})'),
                value: p.url,
                groupValue: _selected,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selected = v;
                    _customController.text = v;
                  });
                },
              )),
          const Divider(height: 32),
          const Text('Custom base URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _customController,
            decoration: const InputDecoration(
              hintText: 'https://api.example.com',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _selected = v,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : _ping,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Ping /health'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _save,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_status.isNotEmpty)
            Text(
              _status,
              style: TextStyle(
                color: _status.startsWith('OK') ? Colors.green : Colors.red,
              ),
            ),
        ],
      ),
    );
  }
}