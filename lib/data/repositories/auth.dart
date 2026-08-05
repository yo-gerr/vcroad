import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vcroad/data/models/barangay.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/data/repositories/session.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // NEW: cache for email-in-use checks (session scoped).
  final Map<String, bool> _emailInUseCache = {};

  // Throttle resend interval.
  int _lastResendMs = 0;
  int _lastPasswordResetMs = 0;
  static const int _minResendIntervalMs = 45 * 1000;

  /// Creates a Firebase Auth account with email+password, sends verification,
  /// and creates a minimal pending registration document.
  Future<String> createAccount({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (await isEmailInUse(trimmedEmail)) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'This email is already registered.',
      );
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    final uid = cred.user!.uid;

    await cred.user!.sendEmailVerification();

    await _firestore.collection('pendingRegistrations').doc(uid).set({
      'uid': uid,
      'email': trimmedEmail,
      'emailVerified': false,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return uid;
  }

  // Poll user.emailVerified until true; emits updates; closes when verified.
  Stream<bool> watchEmailVerification() async* {
    User? current = _auth.currentUser;
    if (current == null) {
      yield false;
      return;
    }

    var verified = current.emailVerified;
    yield verified;

    while (!verified) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        await _auth.currentUser?.reload(); // null-safe
        current = _auth.currentUser;
        verified = current?.emailVerified ?? false; // null-safe
        yield verified;
      } catch (_) {
        // ignore transient reload errors
      }
    }
  }

  /// Writes the full user document to Firestore (called after email verification).
  /// Deletes the pending registration document.
  Future<UserDetails> completeRegistration({
    required String uid,
    required Map<String, String?> formValues,
    required Barangay barangay,
    DateTime? agreedToTermsAt,
  }) async {
    var user = _auth.currentUser;
    if (user == null || user.uid != uid) {
      throw StateError('User session mismatch or lost before finalization.');
    }

    final pendingDoc = await _firestore
        .collection('pendingRegistrations')
        .doc(uid)
        .get();

    final now = DateTime.now();
    final details = UserDetails(
      userId: uid,
      firstName: formValues['firstName']!.trim(),
      middleName: (formValues['middleName']?.trim().isEmpty ?? true)
          ? null
          : formValues['middleName']!.trim(),
      lastName: formValues['lastName']!.trim(),
      suffix: (formValues['suffix']?.trim().isEmpty ?? true)
          ? null
          : formValues['suffix']!.trim(),
      email: user.email ?? '',
      phoneNumber: formValues['phoneNumber']!.trim(),
      street: formValues['street']!.trim(),
      houseNumber: formValues['houseNumber']!.trim(),
      barangay: barangay,
      validIdPath: null,
      selfiePath: null,
      isVerified: false,
      verifiedBy: null,
      verifiedAt: null,
      role: UserRole.user,
      isBanned: false,
      banReason: null,
      banBy: null,
      bannedAt: null,
      unbanRequestAt: null,
      unbannedBy: null,
      unbannedAt: null,
      banType: null,
      banDuration: null,
      banExpiresAt: null,
      createdAt: now,
      updatedAt: null,
      deletedAt: null,
      scheduledForDeletionAt: null,
      confirmReactionsCount: 0,
      verifiedReportsCount: 0,
      flaggedReportsCount: 0,
      agreedToTermsAt: agreedToTermsAt,
    );

    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(uid);
    batch.set(userRef, details.toJson());
    if (pendingDoc.exists) batch.delete(pendingDoc.reference);
    await batch.commit();
    return details;
  }

  Future<bool> refreshAndCheckEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Starts a background watcher that polls FirebaseAuth for emailVerified.
  /// Calls onVerified once and updates the pending registration doc.
  Future<StreamSubscription<bool>> startEmailVerificationWatcher({
    required VoidCallback onVerified,
  }) async {
    final sub = watchEmailVerification().listen((verified) async {
      if (!verified) return;
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _updatePendingEmailVerified(uid);
      }
      onVerified();
    });
    return sub;
  }

  Future<void> _updatePendingEmailVerified(String uid) async {
    await _firestore.collection('pendingRegistrations').doc(uid).set({
      'emailVerified': true,
    }, SetOptions(merge: true));
  }

  Future<void> handleEmailVerified(String uid) async {
    await _updatePendingEmailVerified(uid);
  }

  /// Cross-version helper: tries both fetchSignInMethods and fetchSignInMethodsForEmail.
  Future<List<String>> _fetchSignInMethodsCompat(String email) async {
    final e = email.trim();
    final auth = _auth as dynamic; // avoid static errors across versions
    // Try v6 API
    try {
      final result = await auth.fetchSignInMethods(email: e);
      if (result is List<String>) return result;
      if (result is List) return result.map((m) => m.toString()).toList();
    } catch (_) {
      // Fall through to legacy API
    }
    // Try legacy API
    try {
      final result = await auth.fetchSignInMethodsForEmail(e);
      if (result is List<String>) return result;
      if (result is List) return result.map((m) => m.toString()).toList();
    } catch (_) {
      // Ignore; will return empty list
    }
    return const [];
  }

  /// Checks if the email is already in use (works across firebase_auth versions).
  Future<bool> isEmailInUse(String email) async {
    final key = email.trim().toLowerCase();
    if (_emailInUseCache.containsKey(key)) return _emailInUseCache[key]!;
    try {
      final methods = await _fetchSignInMethodsCompat(key);
      final inUse = methods.isNotEmpty;
      _emailInUseCache[key] = inUse;
      return inUse;
    } catch (_) {
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No current user to resend email verification.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - _lastResendMs;
    if (diff < _minResendIntervalMs) {
      final secs = ((_minResendIntervalMs - diff) / 1000).ceil();
      throw FirebaseAuthException(
        code: 'resend-throttled',
        message: 'Please wait $secs second(s) before resending.',
      );
    }
    await user.sendEmailVerification();
    _lastResendMs = now;
  }

  /// Sends a password reset email to the given address. Resends are
  /// rate-limited to prevent Firebase `too-many-requests` throttling.
  Future<void> sendPasswordResetEmail(String email) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - _lastPasswordResetMs;
    if (diff < _minResendIntervalMs) {
      final secs = ((_minResendIntervalMs - diff) / 1000).ceil();
      throw FirebaseAuthException(
        code: 'resend-throttled',
        message:
            'Please wait $secs second(s) before requesting another reset link.',
      );
    }

    final trimmedEmail = email.trim();
    await _auth.sendPasswordResetEmail(email: trimmedEmail);
    _lastPasswordResetMs = now;
  }

  /// Remaining cooldown (in seconds) before another password reset link may be
  /// requested. Returns `0` when a request is allowed.
  int passwordResetCooldown() {
    final diff = DateTime.now().millisecondsSinceEpoch - _lastPasswordResetMs;
    if (diff >= _minResendIntervalMs) return 0;
    return ((_minResendIntervalMs - diff) / 1000).ceil();
  }

  /// Check Firestore-based lockout before attempting login.
  /// Throws [FirebaseAuthException] with code `too-many-requests` if locked.
  Future<void> _checkFirestoreLockout(String email) async {
    try {
      final doc = await _firestore.collection('loginAttempts').doc(email).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final lockedUntilTS = data['lockedUntil'] as Timestamp?;
      if (lockedUntilTS == null) return;

      final lockedUntil = lockedUntilTS.toDate();
      if (DateTime.now().isBefore(lockedUntil)) {
        final remaining = lockedUntil.difference(DateTime.now());
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: 'Account locked. Try again in ${minutes}m ${seconds}s.',
        );
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      // Network / Firestore errors — allow login attempt to proceed
    }
  }

  /// Track a login attempt in Firestore (per-email, cross-device).
  /// Throws [FirebaseAuthException]`too-many-requests` if lockout triggered.
  Future<void> _trackFirestoreAttempt(
    String email, {
    required bool success,
  }) async {
    final docRef = _firestore.collection('loginAttempts').doc(email);

    if (success) {
      await docRef.set({
        'email': email,
        'failedAttempts': 0,
        'lockedUntil': null,
        'lastAttempt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    try {
      final doc = await docRef.get();
      final current = ((doc.data()?['failedAttempts'] as num?) ?? 0).toInt();
      final newAttempts = current + 1;
      const maxAttempts = 5;
      const lockoutMinutes = 15;

      if (newAttempts >= maxAttempts) {
        final lockUntil = Timestamp.fromMillisecondsSinceEpoch(
          DateTime.now()
              .add(const Duration(minutes: lockoutMinutes))
              .millisecondsSinceEpoch,
        );
        await docRef.set({
          'failedAttempts': 0,
          'lockedUntil': lockUntil,
          'lastAttempt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message:
              'Too many failed attempts. Account locked for $lockoutMinutes minutes.',
        );
      }

      await docRef.set({
        'failedAttempts': newAttempts,
        'lockedUntil': null,
        'lastAttempt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      // Silently ignore Firestore write failures so the auth flow
      // is not blocked by a non-critical tracking error.
    }
  }

  /// Login with email and password (with Firestore-based attempt tracking).
  Future<UserDetails> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    try {
      // Check Firestore-based lockout BEFORE attempting sign-in
      await _checkFirestoreLockout(trimmedEmail);

      // Attempt sign-in
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User authentication failed.',
        );
      }

      // Fetch user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw FirebaseAuthException(
          code: 'user-data-not-found',
          message: 'User data not found. Please contact support.',
        );
      }

      // Track successful login in Firestore
      await _trackFirestoreAttempt(trimmedEmail, success: true);

      return UserDetails.fromJson(userDoc.data()!);
    } on FirebaseAuthException catch (e) {
      // Track failed login for credential errors
      if (e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-email' ||
          e.code == 'invalid-credential') {
        try {
          await _trackFirestoreAttempt(trimmedEmail, success: false);
        } catch (trackError) {
          if (trackError is FirebaseAuthException &&
              trackError.code == 'too-many-requests') {
            rethrow;
          }
        }
      }
      rethrow;
    } catch (e) {
      // Track other failures
      try {
        await _trackFirestoreAttempt(trimmedEmail, success: false);
      } catch (_) {}
      rethrow;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await SessionService.instance.clearSession(uid);
    }
    await _auth.signOut();
  }

  /// Check if user is currently signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Get user details from Firestore by user ID
  Future<UserDetails?> getUserDetails(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        return null;
      }

      return UserDetails.fromJson(userDoc.data()!);
    } catch (e) {
      return null;
    }
  }

  /// Request account deletion (soft delete, scheduled for 30 days).
  ///
  /// `deletedAt` is deliberately NOT set here so the "Scheduled deletion"
  /// state stays visible until the account is actually deleted.
  Future<void> requestAccountDeletion(String uid) async {
    final scheduledDate = DateTime.now().add(const Duration(days: 30));
    await _firestore.collection('users').doc(uid).set({
      'scheduledForDeletionAt': Timestamp.fromDate(scheduledDate),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Cancel account deletion (remove scheduledForDeletionAt)
  Future<void> cancelAccountDeletion(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'scheduledForDeletionAt': FieldValue.delete(),
      'deletedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Check if user has pending deletion during login
  Future<DateTime?> checkPendingDeletion(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return null;

    final data = userDoc.data();
    final scheduledTimestamp = data?['scheduledForDeletionAt'] as Timestamp?;
    if (scheduledTimestamp == null) return null;

    return scheduledTimestamp.toDate();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns the pending registration document for [uid], or null if absent.
  /// Also returns a bool indicating whether the registration has expired (>24h).
  Future<Map<String, dynamic>?> getPendingRegistration(String uid) async {
    try {
      final doc = await _firestore
          .collection('pendingRegistrations')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  /// Looks up a pending registration by [email], returning its doc data or
  /// `null` if none exists. Uses a query on `pendingRegistrations.email` so
  /// callers can detect an unfinished registration without knowing its uid.
  Future<Map<String, dynamic>?> getPendingRegistrationByEmail(
    String email,
  ) async {
    try {
      final query = await _firestore
          .collection('pendingRegistrations')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return query.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  /// Deletes the pending registration doc for [uid], signs out, and attempts
  /// to delete the Firebase Auth user. The Auth user deletion may fail with
  /// `requires-recent-login` — this is caught and silently ignored (the orphan
  /// Auth account is harmless on its own).
  Future<void> cancelPendingRegistration(String uid) async {
    try {
      await _firestore.collection('pendingRegistrations').doc(uid).delete();
    } catch (_) {
      // ignore Firestore errors during cancellation
    }
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (_) {
      // requires-recent-login — orphaned Auth account is acceptable
    }
    await signOut();
  }

  void dispose() {
    _emailInUseCache.clear();
  }
}
