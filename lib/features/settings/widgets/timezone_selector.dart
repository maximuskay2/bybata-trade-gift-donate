import 'package:flutter/material.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

class TimezoneSelector extends StatefulWidget {
  final String? selectedTimezone;
  final Function(String) onTimezoneSelected;

  const TimezoneSelector({
    super.key,
    this.selectedTimezone,
    required this.onTimezoneSelected,
  });

  @override
  State<TimezoneSelector> createState() => _TimezoneSelectorState();
}

class _TimezoneSelectorState extends State<TimezoneSelector> {
  List<String> _timezones = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimezones();
  }

  void _loadTimezones() {
    setState(() {
      _isLoading = true;
    });
    
    // Load timezones asynchronously
    Future.microtask(() {
      // Use a comprehensive list of common timezones
      final commonTimezones = [
        'UTC',
        'America/New_York',
        'America/Chicago',
        'America/Denver',
        'America/Los_Angeles',
        'America/Phoenix',
        'America/Anchorage',
        'America/Honolulu',
        'America/Toronto',
        'America/Vancouver',
        'America/Mexico_City',
        'America/Sao_Paulo',
        'America/Buenos_Aires',
        'Europe/London',
        'Europe/Paris',
        'Europe/Berlin',
        'Europe/Rome',
        'Europe/Madrid',
        'Europe/Amsterdam',
        'Europe/Stockholm',
        'Europe/Moscow',
        'Asia/Dubai',
        'Asia/Karachi',
        'Asia/Kolkata',
        'Asia/Bangkok',
        'Asia/Hong_Kong',
        'Asia/Shanghai',
        'Asia/Tokyo',
        'Asia/Seoul',
        'Asia/Singapore',
        'Australia/Sydney',
        'Australia/Melbourne',
        'Australia/Perth',
        'Pacific/Auckland',
        'Africa/Cairo',
        'Africa/Johannesburg',
        'Africa/Lagos',
        'Africa/Nairobi',
      ];
      
      if (mounted) {
        setState(() {
          _timezones = commonTimezones;
          _isLoading = false;
        });
      }
    });
  }

  List<String> get _filteredTimezones {
    if (_searchQuery.isEmpty) {
      return _timezones;
    }
    final query = _searchQuery.toLowerCase();
    return _timezones.where((tz) {
      return tz.toLowerCase().contains(query) ||
          tz.replaceAll('_', ' ').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Select Timezone',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: BorderlessInputDecoration.search(
                  hintText: 'Search timezone...',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const BybataLoader()
                  : _filteredTimezones.isEmpty
                      ? const Center(
                          child: Text('No timezones found'),
                        )
                      : ListView.builder(
                          itemCount: _filteredTimezones.length,
                          itemBuilder: (context, index) {
                            final tzName = _filteredTimezones[index];
                            final isSelected = tzName == widget.selectedTimezone;
                            return ListTile(
                              title: Text(
                                tzName.replaceAll('_', ' '),
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: Theme.of(context).colorScheme.primary,
                                    )
                                  : null,
                              selected: isSelected,
                              onTap: () {
                                widget.onTimezoneSelected(tzName);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

