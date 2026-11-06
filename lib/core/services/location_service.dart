import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config/env_config.dart';

/// Centralized location permission + position helper.
///
/// Why this exists: previously every widget that wanted location
/// (LocationChip on Home, create-trade / create-gift / create-campaign,
/// community discovery, etc.) called `Geolocator.checkPermission()` +
/// `Geolocator.requestPermission()` directly. That made the OS surface
/// the system dialog every single time the app re-launched, because
/// `LocationChip.initState` would re-request unconditionally whenever
/// the cached state was `denied`. iOS behaves the same way: once a user
/// declines, `requestPermission()` silently returns `denied` and there's
/// no way to ask again unless the user re-enables it in Settings.
///
/// This service consolidates the policy:
///
/// * [ensureForBackground] — passive, ambient flows (e.g. the location
///   chip on Home). Asks ONCE on first ever launch (tracked in
///   SharedPreferences), then never auto-prompts again. Subsequent app
///   launches read the persisted decision instead of re-prompting.
///
/// * [ensureForFunction] — explicit user actions (e.g. "use my current
///   location" on Create Trade). Re-prompts the OS dialog if the user
///   previously declined. If the OS reports `deniedForever` (iOS once
///   the user said no, or Android after a permanent denial), surfaces
///   an in-app dialog directing the user to system settings via
///   `Geolocator.openAppSettings()`.
///
/// * [getCurrentPosition] — fetches a fresh fix, with a short-lived
///   in-memory cache so repeated reads on the same screen don't hammer
///   the GPS. Persists the last known fix to disk so the chip can show
///   a label immediately on cold-start without forcing a fresh GPS read.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // --- prefs keys ---
  static const _kPromptShown = 'location_prompt_shown_v1';
  static const _kLastLat = 'location_last_lat';
  static const _kLastLng = 'location_last_lng';
  static const _kLastPlace = 'location_last_place';
  static const _kLastTs = 'location_last_ts';

  // In-memory cache TTL — short enough that "Near you" stays accurate as
  // the user moves, long enough that a single screen visit doesn't fire
  // multiple GPS reads in a row.
  static const _cacheTtl = Duration(minutes: 10);

  Position? _cachedPosition;
  String? _cachedPlacemark;
  DateTime? _cachedAt;

  // ---------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------

  Future<bool> hasPromptedBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPromptShown) ?? false;
  }

  Future<void> _markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPromptShown, true);
  }

  Future<({double lat, double lng, String? place, DateTime ts})?>
      _readDiskCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLastLat);
    final lng = prefs.getDouble(_kLastLng);
    if (lat == null || lng == null) return null;
    final tsMs = prefs.getInt(_kLastTs);
    return (
      lat: lat,
      lng: lng,
      place: prefs.getString(_kLastPlace),
      ts: tsMs != null
          ? DateTime.fromMillisecondsSinceEpoch(tsMs)
          : DateTime.now(),
    );
  }

  Future<void> _writeDiskCache(Position p, String? placemark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLastLat, p.latitude);
    await prefs.setDouble(_kLastLng, p.longitude);
    if (placemark != null) {
      await prefs.setString(_kLastPlace, placemark);
    }
    await prefs.setInt(_kLastTs, DateTime.now().millisecondsSinceEpoch);
    // Best-effort sync so the API can notify this user about nearby listings.
    unawaited(_syncLocationToServer(p.latitude, p.longitude));
  }

  Future<void> _syncLocationToServer(double lat, double lng) async {
    try {
      const storage = FlutterSecureStorage();
      final access = await storage.read(key: 'access');
      if (access == null || access.isEmpty) return;
      final baseUrl = await EnvConfig.getBaseUrl();
      final client = ApiClient(baseUrl, storage);
      await client.dio.post('/v1/users/me/location', data: {
        'latitude': lat,
        'longitude': lng,
      });
    } catch (_) {
      // Non-blocking — nearby alerts simply skip users without a recent fix.
    }
  }

  // ---------------------------------------------------------------------
  // Permission flows
  // ---------------------------------------------------------------------

  /// Returns the OS permission status without ever prompting.
  Future<LocationPermission> currentStatus() => Geolocator.checkPermission();

  /// Returns true once the OS reports any "granted" variant.
  Future<bool> isGranted() async {
    final status = await Geolocator.checkPermission();
    return status == LocationPermission.always ||
        status == LocationPermission.whileInUse;
  }

  /// Ambient/background prompt — used by widgets that surface location
  /// passively (e.g. [LocationChip] on the Home / Browse Home screen).
  ///
  /// Asks the OS exactly once across the lifetime of the install. If the
  /// user has already been prompted (regardless of accept/decline), this
  /// returns the current status without showing the dialog again — so a
  /// previously-declined user is not re-pestered on every app launch.
  Future<LocationPermission> ensureForBackground() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermission.denied;

    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      final asked = await hasPromptedBefore();
      if (!asked) {
        status = await Geolocator.requestPermission();
        await _markPrompted();
      }
    } else {
      // If we already have a real grant on cold-start, treat that as
      // implicit "we've prompted" so future ambient calls are no-ops.
      await _markPrompted();
    }
    return status;
  }

  /// Function-triggered prompt — used by features that explicitly need
  /// location (Create Trade, Create Gift, Create Campaign, community
  /// discovery, etc.).
  ///
  /// * If the OS status is `denied`, re-prompts the system dialog.
  /// * If the OS status is `deniedForever`, surfaces an in-app dialog
  ///   that takes the user to App Settings (this is the only way to
  ///   recover a permanent decline on iOS).
  /// * If location services are disabled at the OS level, prompts the
  ///   user to enable them.
  Future<LocationPermission> ensureForFunction(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) await _showServiceDisabledDialog(context);
      return LocationPermission.denied;
    }

    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      status = await Geolocator.requestPermission();
      await _markPrompted();
    }
    if (status == LocationPermission.deniedForever && context.mounted) {
      await _showOpenSettingsDialog(context);
    }
    return status;
  }

  // ---------------------------------------------------------------------
  // Position helpers
  // ---------------------------------------------------------------------

  /// Returns a fresh GPS position. Falls back to the last-known fix if
  /// the live read times out, and ultimately to the disk-cached fix if
  /// the OS has nothing to offer. Returns `null` when permission is
  /// missing AND no cached fix exists.
  Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedPosition != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedPosition;
    }

    final granted = await isGranted();
    if (!granted) {
      return _positionFromDisk();
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      _cachedPosition = position;
      _cachedAt = DateTime.now();
      // Persist the raw fix so a future cold-start has something to
      // show before the first GPS read finishes.
      await _writeDiskCache(position, _cachedPlacemark);
      return position;
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _cachedPosition = last;
          _cachedAt = DateTime.now();
          await _writeDiskCache(last, _cachedPlacemark);
          return last;
        }
      } catch (_) {/* ignore */}
      return _positionFromDisk();
    }
  }

  Future<Position?> _positionFromDisk() async {
    final disk = await _readDiskCache();
    if (disk == null) return null;
    return Position(
      latitude: disk.lat,
      longitude: disk.lng,
      timestamp: disk.ts,
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  /// Reverse-geocodes a position into a "City, Region, Country" label
  /// and caches the result alongside the raw fix on disk.
  Future<String?> resolvePlacemark(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5), onTimeout: () => []);
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final parts = [place.locality, place.administrativeArea, place.country]
          .where((e) => e != null && e.isNotEmpty)
          .toList();
      final label = parts.isNotEmpty ? parts.join(', ') : null;
      _cachedPlacemark = label;
      await _writeDiskCache(position, label);
      return label;
    } catch (_) {
      return null;
    }
  }

  /// Last known coordinates without triggering a fresh GPS read.
  Future<Position?> getCachedPositionOnly() async {
    if (_cachedPosition != null) return _cachedPosition;
    return _positionFromDisk();
  }

  /// Returns the most recent placemark label we have on hand — in-memory
  /// first, then from disk. Used by [LocationChip] to render a label on
  /// cold-start without waiting for a fresh reverse-geocode.
  Future<String?> getCachedPlacemark() async {
    if (_cachedPlacemark != null) return _cachedPlacemark;
    final disk = await _readDiskCache();
    _cachedPlacemark = disk?.place;
    return _cachedPlacemark;
  }

  // ---------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------

  Future<void> _showServiceDisabledDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location services are off'),
        content: const Text(
          'Please turn on location services in your device settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOpenSettingsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location permission needed'),
        content: const Text(
          'You previously declined location access. Please enable it in Settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
