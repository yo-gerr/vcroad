import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:vcroad/presentation/shared/dialogs/something_went_wrong.dart';

class PendingDeletionException implements Exception {
  final DateTime scheduledForDeletionAt;
  PendingDeletionException(this.scheduledForDeletionAt);

  @override
  String toString() =>
      'Account is pending deletion until $scheduledForDeletionAt';
}

typedef AsyncCallback = Future<void> Function();

Future<void> trycatch({
  required BuildContext context,
  required AsyncCallback task,
  required VoidCallback onRetry,
  VoidCallback? onBeforeCatch,
  bool dismissDialog = true,
}) async {
  try {
    await task();

    // ✅ Automatically dismiss loading dialog on success
    if (dismissDialog && context.mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  } catch (e) {
    // ✅ Let pending-deletion bubble to caller so it can show its own dialog
    if (e is PendingDeletionException) {
      onBeforeCatch?.call();
      if (dismissDialog && context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      rethrow;
    }

    if (!context.mounted) return;

    onBeforeCatch?.call();

    // ✅ Automatically dismiss loading dialog on error
    if (dismissDialog && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }

    final message = _resolveFirebaseMessage(e);

    await showSomethingWentWrongDialog(
      context: context,
      message: message,
      onRetry: onRetry,
    );
  }
}

String _resolveFirebaseMessage(dynamic e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return "The email address is invalid. Please check and try again.";
      case 'user-disabled':
        return "Your account has been banned. Please contact support if you believe this is a mistake.";
      case 'user-not-found':
        return "No account found with this email. Please register first.";
      case 'wrong-password':
        return "Incorrect password. Please try again.";
      case 'email-already-in-use':
        return "This email is already registered. Try logging in instead.";
      case 'weak-password':
        return "The password is too weak. Please choose a stronger one.";
      case 'operation-not-allowed':
        return "This sign-in method is not enabled. Contact support.";
      case 'network-request-failed':
        return "Network error. Please check your internet connection.";
      case 'too-many-requests':
        // Use detailed server message if available, otherwise fallback
        return e.message ?? "Too many login attempts. Please try again later.";
      case 'invalid-credential':
        return "Invalid email or password. Please try again.";
      default:
        return "Invalid credentials. Please check your email and password.";
    }
  }

  if (e is FirebaseException) {
    switch (e.code) {
      case 'unavailable':
      case 'network-request-failed':
        return "Unable to fetch data. You might be offline.";
      case 'permission-denied':
        return "Access denied. You don't have permission to perform this action.";
      case 'not-found':
        return "Requested data not found.";
      default:
        return "A data error occurred. Please try again.";
    }
  }

  // Commented out: FirebaseFunctionsException handling (cloud_functions dependency removed)
  // if (e is FirebaseFunctionsException) {
  //   switch (e.code) {
  //     case 'unauthenticated':
  //       return "You must be signed in to perform this action.";
  //     case 'permission-denied':
  //       return "You don't have permission to do this action.";
  //     case 'invalid-argument':
  //       return "Some details you entered are invalid. Please review and try again.";
  //     case 'already-exists':
  //       return "This resource already exists. Try again with different details.";
  //     case 'not-found':
  //       return "The requested resource was not found.";
  //     case 'failed-precondition':
  //       return "This request could not be completed due to invalid state.";
  //     case 'unavailable':
  //       return "The server is currently unavailable. Please try again later.";
  //     case 'internal':
  //       return "Something went wrong on the server. Please try again.";
  //     case 'resource-exhausted':
  //       return "Quota exceeded. Please try again later.";
  //     default:
  //       return e.message ?? "A server error occurred. Please try again.";
  //   }
  // }

  return "An unexpected error occurred. Please try again.";
}
