import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

/// Compact location chip for the app bar. Fetches and displays user's current location.
class LocationChip extends StatefulWidget {
  final bool isGlassTheme;

  const LocationChip({super.key, this.isGlassTheme = false});

  @override
  State<LocationChip> createState() => _LocationChipState();
}

class _LocationChipState extends State<LocationChip> {
  String _currentLocation = 'Loading...';
  bool _isLocationLoading = false;

  @override
  void initState() {
    super.initState();
    // Passive boot: paint a cached label immediately if we have one,
    // then ask the OS for permission ONCE across the lifetime of the
    // install (handled by [LocationService.ensureForBackground]). This
    // is what removes the "prompted on every app launch" behavior —
    // a previously-declined user is no longer re-pestered when they
    // reopen Home; they opt back in by tapping the chip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapFromCache();
      _refresh(activeRequest: false);
    });
  }

  /// Paints whatever we have on disk before any GPS / permission work
  /// happens, so the chip never flashes "Loading…" on cold-start when
  /// the user has already granted permission in a past session.
  Future<void> _bootstrapFromCache() async {
    final cached = await LocationService.instance.getCachedPlacemark();
    if (!mounted || cached == null || cached.isEmpty) return;
    setState(() {
      _currentLocation = cached;
    });
  }

  /// Fetches a fresh fix and updates the label.
  ///
  /// [activeRequest] = true when this is triggered by a tap. The chip
  /// will then route through [LocationService.ensureForFunction] which
  /// re-prompts after a previous decline and offers a Settings shortcut
  /// when the OS reports `deniedForever`.
  Future<void> _refresh({required bool activeRequest}) async {
    if (_isLocationLoading) return;
    setState(() {
      _isLocationLoading = true;
    });
    try {
      final LocationPermission status;
      if (activeRequest) {
        // ignore: use_build_context_synchronously
        status = await LocationService.instance.ensureForFunction(context);
      } else {
        status = await LocationService.instance.ensureForBackground();
      }

      final granted = status == LocationPermission.always ||
          status == LocationPermission.whileInUse;
      if (!granted) {
        if (!mounted) return;
        // Don't overwrite a previously-resolved label with "Tap to
        // enable" — once we have a cached city, keep showing it even
        // when the user has revoked permission for this session.
        setState(() {
          if (_currentLocation == 'Loading...') {
            _currentLocation = 'Tap to enable';
          }
          _isLocationLoading = false;
        });
        return;
      }

      final position = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      if (position == null) {
        setState(() {
          if (_currentLocation == 'Loading...') {
            _currentLocation = 'Tap to retry';
          }
          _isLocationLoading = false;
        });
        return;
      }

      final label =
          await LocationService.instance.resolvePlacemark(position) ??
              '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
      if (!mounted) return;
      setState(() {
        _currentLocation = label;
        _isLocationLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_currentLocation == 'Loading...') {
          _currentLocation = 'Tap to retry';
        }
        _isLocationLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _refresh(activeRequest: true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isGlassTheme
              ? scheme.surface.withValues(alpha: 0.5)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            _isLocationLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: scheme.primary,
                  ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _currentLocation,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
