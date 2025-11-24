import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vcroad_v2/shared/models/barangay.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/services/image.dart';
import 'package:vcroad_v2/shared/services/session.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // NEW: cache for email-in-use checks (session scoped).
  final Map<String, bool> _emailInUseCache = {};

  // NEW: throttle resend (epoch ms).
  int _lastResendMs = 0;
  static const int _minResendIntervalMs = 45 * 1000; // 45 seconds

  // Generates a strong temporary password (not shown to user)
  String _generateTempPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%^*-_=+';
    final r = Random.secure();
    return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> ensureAnonymousUser() async {
    final user = _auth.currentUser;
    if (user != null) return user.uid;
    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }

  /// Cross-version helper already present: _fetchSignInMethodsCompat
  /// and isEmailInUse(...) are used below.

  // Link anonymous user with a TEMP password so we can call sendEmailVerification now.
  // If the email is already in use, throw and let the UI inform the user.
  Future<void> linkEmailAndSendVerification({required String email}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated (anonymous) user to link.');
    }

    final trimmedEmail = email.trim().toLowerCase();

    // If already linked with same email, just (re)send verification.
    if (user.email == trimmedEmail) {
      await user.sendEmailVerification();
      return;
    }

    // Double-check server-side to avoid race conditions with UI check.
    final inUse = await isEmailInUse(trimmedEmail);
    if (inUse) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The email address is already in use.',
      );
    }

    // Link with a temp password (not shown to user).
    final tempPass = _generateTempPassword();
    final cred = EmailAuthProvider.credential(
      email: trimmedEmail,
      password: tempPass,
    );

    // This will throw if something is wrong; no fallback sign-in with temp pass.
    await user.linkWithCredential(cred);

    // Always send / resend verification email after linking.
    await _auth.currentUser?.sendEmailVerification();
  }

  // ✅ Add this to match existing Register._startEmailVerificationListener usage
  Stream<bool> listenEmailVerified(String uid) {
    return _firestore
        .collection('pendingRegistrations')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['emailVerified'] as bool?) ?? false)
        .distinct();
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

  Future<void> createPendingRegistration({
    required String uid,
    required Map<String, String?> formValues,
    required Barangay? barangay,
  }) async {
    if (barangay == null) {
      throw StateError('Barangay required before pending registration.');
    }
    final doc = _firestore.collection('pendingRegistrations').doc(uid);
    final data = {
      'uid': uid,
      'firstName': formValues['firstName']?.trim(),
      'middleName': formValues['middleName']?.trim(),
      'lastName': formValues['lastName']?.trim(),
      'suffix': formValues['suffix']?.trim(),
      'phoneNumber': formValues['phoneNumber']?.trim(),
      'barangay': {
        'name': barangay.name,
        if (barangay.district != null) 'district': barangay.district,
      },
      'street': formValues['street']?.trim(),
      'houseNumber': formValues['houseNumber']?.trim(),
      'email': formValues['email']?.trim().toLowerCase(),
      'validIdPath': 'valid_ids/$uid/id.jpg',
      'selfiePath': 'selfies/$uid/selfie.jpg',
      'emailVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    };
    await doc.set(data, SetOptions(merge: true));
  }

  Future<void> _createMinimalPending({
    required String uid,
    required String email,
  }) async {
    // Fast, minimal doc so the watcher can safely set emailVerified later.
    await _firestore.collection('pendingRegistrations').doc(uid).set({
      'uid': uid,
      'email': email,
      'emailVerified': false,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _preparePendingInBackground({
    required String uid,
    required Map<String, String?> formValues,
    required Barangay? barangay,
    required Map<String, dynamic> images,
  }) async {
    try {
      // Uploads can be slow; run them here, off the critical path.
      await uploadIdentityImages(uid: uid, images: images);
      await createPendingRegistration(
        uid: uid,
        formValues: formValues,
        barangay: barangay,
      );
    } catch (e) {
      // Optional: log to Crashlytics or analytics
      // debugPrint('Background pending preparation failed: $e');
    }
  }

  // Make this idempotent so it won't fail if the doc isn't fully created yet.
  Future<void> updatePendingEmailVerified(String uid) async {
    await _firestore.collection('pendingRegistrations').doc(uid).set({
      'emailVerified': true,
    }, SetOptions(merge: true));
  }

  Future<void> uploadIdentityImages({
    required String uid,
    required Map<String, dynamic> images,
  }) async {
    if (images['id'] == null || images['selfie'] == null) {
      throw ArgumentError('Both ID and selfie images are required.');
    }
    await ImageService.uploadUserImagesBatch(
      userId: uid,
      images: {'id': images['id'], 'selfie': images['selfie']},
    );
  }

  // Finalize: user already linked & verified. Replace temp password with chosen password.
  Future<UserDetails> finalizeAccount({
    required String email,
    required String newPassword,
    required Map<String, String?> formValues,
    required Barangay barangay,
  }) async {
    var user = _auth.currentUser;
    if (user == null) {
      throw StateError('User session lost before finalization.');
    }

    // Ensure email matches
    if (user.email != email) {
      throw StateError('Linked email does not match provided email.');
    }

    // Update password (will require recent login; still recent because session continuous)
    await user.updatePassword(newPassword);

    final uid = user.uid;
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
      email: email.trim().toLowerCase(),
      phoneNumber: formValues['phoneNumber']!.trim(),
      street: formValues['street']!.trim(),
      houseNumber: formValues['houseNumber']!.trim(),
      barangay: barangay,
      validIdPath: 'valid_ids/$uid/id.jpg',
      selfiePath: 'selfies/$uid/selfie.jpg',
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
      lessonsFinishedCount: 0,
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

  Future<void> handleEmailVerified(String uid) async {
    await updatePendingEmailVerified(uid);
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

  Future<String> handleSendVerification({
    required Map<String, dynamic> images,
    required Map<String, String?> formValues,
    required Barangay? barangay,
  }) async {
    final email = (formValues['email'] ?? '').trim().toLowerCase();
    if (email.isEmpty) throw StateError('Email is required.');

    // Single authoritative (cached) check before any costly work.
    if (await isEmailInUse(email)) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'This email is already registered.',
      );
    }

    // Ensure session and get uid quickly.
    final uid = await ensureAnonymousUser();

    // Create a minimal pending doc fast so the watcher can write safely.
    await _createMinimalPending(uid: uid, email: email);

    // Send verification link immediately (fastest user feedback).
    await linkEmailAndSendVerification(email: email);

    // Heavy work moves to background; don’t block the UI.
    unawaited(
      _preparePendingInBackground(
        uid: uid,
        formValues: formValues,
        barangay: barangay,
        images: images,
      ),
    );

    return uid;
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
        await updatePendingEmailVerified(uid);
      }
      onVerified();
    });
    return sub;
  }

  /// Sends a password reset email to the given address.
  Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    await _auth.sendPasswordResetEmail(email: trimmedEmail);
  }

  /// Check server-side lockout before attempting login
  Future<Map<String, dynamic>?> _checkServerLockout(String email) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'trackLoginAttempt',
      );

      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
        'success': null, // Just checking current status
      });

      return result.data;
    } on FirebaseFunctionsException catch (e) {
      // If account is locked, throw auth exception
      if (e.message?.contains('locked') == true) {
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: e.message ?? 'Account temporarily locked.',
        );
      }
      // For other errors (network, etc), return null to allow login attempt
      return null;
    } catch (_) {
      // Don't block login if server check fails
      return null;
    }
  }

  /// Track login attempt on server
  Future<Map<String, dynamic>?> _trackLoginAttempt(
    String email, {
    required bool success,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'trackLoginAttempt',
      );

      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
        'success': success,
      });

      return result.data;
    } on FirebaseFunctionsException catch (e) {
      // If locked after this attempt, throw auth exception
      if (e.message?.contains('locked') == true) {
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: e.message ?? 'Too many login attempts.',
        );
      }
      // Silently ignore other tracking errors
      return null;
    } catch (_) {
      // Don't block auth flow on tracking errors
      return null;
    }
  }

  /// Login with email and password (with server-side attempt tracking)
  Future<UserDetails> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    try {
      // ✅ Check server-side lockout BEFORE attempting sign-in
      await _checkServerLockout(trimmedEmail);

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

      // ✅ Track successful login on server
      await _trackLoginAttempt(trimmedEmail, success: true);

      return UserDetails.fromJson(userDoc.data()!);
    } on FirebaseAuthException catch (e) {
      // ✅ Track failed login for credential errors
      if (e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-email' ||
          e.code == 'invalid-credential') {
        try {
          await _trackLoginAttempt(trimmedEmail, success: false);
        } catch (trackError) {
          // If tracking throws a lockout error, propagate it
          if (trackError is FirebaseAuthException &&
              trackError.code == 'too-many-requests') {
            rethrow;
          }
          // Otherwise ignore tracking errors
        }
      }
      rethrow;
    } catch (e) {
      // Track other failures
      try {
        await _trackLoginAttempt(trimmedEmail, success: false);
      } catch (_) {
        // Ignore tracking errors
      }
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

  /// Request account deletion (soft delete, scheduled for 30 days)
  Future<void> requestAccountDeletion(String uid) async {
    final scheduledDate = DateTime.now().add(const Duration(days: 30));
    await _firestore.collection('users').doc(uid).set({
      'scheduledForDeletionAt': Timestamp.fromDate(scheduledDate),
      'deletedAt': FieldValue.serverTimestamp(),
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

  /// Calls the applyUserRole cloud function to sync role claims for the current user.
  Future<String?> applyUserRoleClaim() async {
    final callable = FirebaseFunctions.instance.httpsCallable('applyUserRole');
    try {
      final result = await callable();
      final role = result.data['role'] as String?;
      return role;
    } catch (e) {
      // Optionally log error or handle for UI
      return null;
    }
  }

  // Add this getter near other helpers
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  void dispose() {}
}
