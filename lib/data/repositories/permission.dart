import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppPermission { camera, photos, microphone, location }

extension AppPermissionX on AppPermission {
  String get label {
    switch (this) {
      case AppPermission.camera:
        return 'Camera';
      case AppPermission.photos:
        return Platform.isAndroid ? 'Storage / Media' : 'Photos';
      case AppPermission.microphone:
        return 'Microphone';
      case AppPermission.location:
        return 'Location';
    }
  }

  String get rationale {
    switch (this) {
      case AppPermission.camera:
        return 'Needed to capture photos or videos.';
      case AppPermission.photos:
        return 'Needed to read/save captured media.';
      case AppPermission.microphone:
        return 'Needed to record audio with video.';
      case AppPermission.location:
        return 'Needed to tag your report with position.';
    }
  }
}

class PermissionService {
  PermissionService._();
  static final instance = PermissionService._();

  bool _lock = false;

  Future<Map<AppPermission, PermissionStatus>> request(
    Set<AppPermission> perms,
  ) async {
    final map = <AppPermission, PermissionStatus>{};
    if (kIsWeb) {
      // Browsers handle permissions ad‑hoc; treat all as granted.
      for (final p in perms) {
        map[p] = PermissionStatus.granted;
      }
      return map;
    }

    for (final p in perms) {
      switch (p) {
        case AppPermission.camera:
          map[p] = await _ensureStatus(Permission.camera);
          break;
        case AppPermission.photos:
          if (Platform.isIOS) {
            map[p] = await _ensureStatus(Permission.photos);
          } else {
            // Android: storage; optional future: READ_MEDIA_IMAGES for SDK 33+
            map[p] = await _ensureStatus(Permission.storage);
          }
          break;
        case AppPermission.microphone:
          map[p] = await _ensureStatus(Permission.microphone);
          break;
        case AppPermission.location:
          // Use Geolocator for user-facing location permissions (fused)
          final status = await _geolocatorStatus();
          map[p] = status;
          break;
      }
    }
    return map;
  }

  /// Request only camera (+ microphone if video). Use for camera capture flows.
  Future<Map<AppPermission, PermissionStatus>> requestForCamera({
    required bool video,
  }) async {
    final needed = <AppPermission>{
      AppPermission.camera,
      if (video) AppPermission.microphone,
    };
    return request(needed);
  }

  Future<PermissionStatus> _ensureStatus(Permission permission) async {
    final current = await permission.status;
    if (current.isGranted || current.isPermanentlyDenied) return current;
    final requested = await permission.request();
    return requested;
  }

  Future<PermissionStatus> _geolocatorStatus() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PermissionStatus.denied;
    }
    LocationPermission lp = await Geolocator.checkPermission();
    if (lp == LocationPermission.denied) {
      lp = await Geolocator.requestPermission();
    }
    if (lp == LocationPermission.deniedForever) {
      return PermissionStatus.permanentlyDenied;
    }
    return (lp == LocationPermission.always ||
            lp == LocationPermission.whileInUse)
        ? PermissionStatus.granted
        : PermissionStatus.denied;
  }

  Future<Map<AppPermission, PermissionStatus>> requestMediaCapture({
    required bool video,
  }) async {
    final needed = {
      AppPermission.camera,
      AppPermission.photos,
      if (video) AppPermission.microphone,
    };
    return request(needed);
  }

  Future<Map<AppPermission, PermissionStatus>> requestLocation() async {
    return request({AppPermission.location});
  }

  bool allGranted(Map<AppPermission, PermissionStatus> statuses) =>
      statuses.values.every((s) => s.isGranted);

  bool anyPermanentlyDenied(Map<AppPermission, PermissionStatus> statuses) =>
      statuses.values.any((s) => s.isPermanentlyDenied);

  /// Show a pre-permission rationale dialog explaining why the app needs
  /// location.  The dialog is shown at most once (tracked via SharedPreferences).
  /// Returns `true` if the user agreed or the rationale was already shown.
  static Future<bool> showLocationRationale(BuildContext context) async {
    if (kIsWeb) return true;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('location_rationale_shown') == true) return true;

    if (!context.mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Location Access'),
        content: const Text(
          'To show your position on the map and tag incident reports with '
          'the correct barangay, VCRoad needs access to your device\'s location.\n\n'
          'Your location is used only while the app is open and is never '
          'shared outside the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (agreed == true) {
      await prefs.setBool('location_rationale_shown', true);
    }
    return agreed ?? false;
  }

  /// Prevent overlapping permission flows
  Future<Map<AppPermission, PermissionStatus>> guardedRequest(
    Set<AppPermission> perms,
  ) async {
    if (_lock) return {};
    _lock = true;
    try {
      return await request(perms);
    } finally {
      _lock = false;
    }
  }
}
