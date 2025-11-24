import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SessionService {
  SessionService._();
  static final instance = SessionService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? currentSessionId;
  String? _cachedDeviceInfo;
  int _lastWriteMs = 0;
  static const _minWriteIntervalMs = 600; // throttle small bursts

  /// Generate a unique session ID (exposed)
  String newSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_auth.currentUser?.uid}';
  }

  /// Get device information (cached)
  Future<String> _getDeviceInfo() async {
    if (_cachedDeviceInfo != null) return _cachedDeviceInfo!;
    final deviceInfo = DeviceInfoPlugin();
    String value;
    if (kIsWeb) {
      final web = await deviceInfo.webBrowserInfo;
      value = '${web.browserName} on ${web.platform}';
    } else if (Platform.isAndroid) {
      final a = await deviceInfo.androidInfo;
      value = '${a.brand} ${a.model} (Android ${a.version.release})';
    } else if (Platform.isIOS) {
      final i = await deviceInfo.iosInfo;
      value = '${i.name} ${i.model} (iOS ${i.systemVersion})';
    } else if (Platform.isWindows) {
      final w = await deviceInfo.windowsInfo;
      value = 'Windows ${w.computerName}';
    } else if (Platform.isMacOS) {
      final m = await deviceInfo.macOsInfo;
      value = 'macOS ${m.computerName}';
    } else if (Platform.isLinux) {
      final l = await deviceInfo.linuxInfo;
      value = 'Linux ${l.name}';
    } else {
      value = 'Unknown Device';
    }
    _cachedDeviceInfo = value;
    return value;
  }

  DocumentReference<Map<String, dynamic>> _sessionRef(String uid) =>
      _firestore.doc('sessions/$uid');

  Future<void> _writeSession(String uid, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (uid.isEmpty || user == null || user.uid != uid) return;

    // Throttle
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastWriteMs < _minWriteIntervalMs) return;
    _lastWriteMs = now;

    try {
      await _sessionRef(uid).set(data, SetOptions(merge: true));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Session write skipped: $e\n$st');
      }
      // swallow – session metadata is non-critical
    }
  }

  Future<void> setActiveSession(String uid, String sessionId) async {
    // Idempotent: avoid extra writes.
    if (currentSessionId == sessionId) return;

    await _writeSession(uid, {
      'activeSessionId': sessionId,
      'device': await _getDeviceInfo(),
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    currentSessionId = sessionId;
  }

  Future<String> createSession(String uid) async {
    final sid = newSessionId();
    await setActiveSession(uid, sid);
    return sid;
  }

  Future<Map<String, dynamic>?> checkActiveSession(
    String uid,
    String proposedSessionId,
  ) async {
    final snap = await _sessionRef(uid).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    final active = data['activeSessionId'] as String?;
    if (active != null && active != proposedSessionId) {
      return {
        'sessionId': active,
        'deviceInfo': data['device'] as String?,
        'startedAt': (data['startedAt'] as Timestamp?)?.toDate(),
      };
    }
    return null;
  }

  Future<void> forceLogoutOtherDevices(String uid, String sessionId) async {
    await setActiveSession(uid, sessionId);
  }

  Future<void> clearSession(String uid) async {
    await _writeSession(uid, {
      'activeSessionId': null,
      'device': null,
      'startedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    currentSessionId = null;
  }

  Stream<Map<String, dynamic>?> watchSession(String uid, String currentSid) {
    return _sessionRef(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      final active = data['activeSessionId'] as String?;
      if (active != null && active != currentSid) {
        return {
          'sessionId': active,
          'deviceInfo': data['device'],
          'startedAt': (data['startedAt'] as Timestamp?)?.toDate(),
        };
      }
      return null;
    });
  }
}
