import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/providers/sync_provider.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/referral_service.dart';
import 'package:sumquiz/services/user_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sumquiz/services/sync_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final ReferralService _referralService = ReferralService();
  final UserService _userService = UserService();
  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userDisplayNameKey = 'user_display_name';
  static const String _userEmailKey = 'user_email';

  AuthService(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Save user authentication state locally for offline access
  Future<void> _saveAuthState(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, user.uid);
      await prefs.setString(_userDisplayNameKey, user.displayName ?? '');
      await prefs.setString(_userEmailKey, user.email ?? '');

      // Save token if available
      final token = await user.getIdToken();
      if (token != null) {
        await prefs.setString(_authTokenKey, token);
      }

      developer.log('Authentication state saved locally for user: ${user.uid}');
    } catch (e) {
      developer.log('Failed to save authentication state', error: e);
    }
  }

  /// Clear saved authentication state
  Future<void> _clearAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userDisplayNameKey);
      await prefs.remove(_userEmailKey);
      developer.log('Authentication state cleared');
    } catch (e) {
      developer.log('Failed to clear authentication state', error: e);
    }
  }

  /// Restore authentication state when app starts
  Future<bool> restoreAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      final userId = prefs.getString(_userIdKey);

      // If we have a token and user ID, try to restore the session
      if (token != null &&
          userId != null &&
          token.isNotEmpty &&
          userId.isNotEmpty) {
        // Note: In a real implementation, you would validate the token
        // For now, we'll just log that we have saved state
        developer.log('Found saved authentication state for user: $userId');
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Failed to restore authentication state', error: e);
      return false;
    }
  }

  Stream<UserModel?> get user {
    return _auth.authStateChanges().switchMap((user) {
      if (user == null) {
        return Stream.value(null);
      }
      return _firestoreService.streamUser(user.uid);
    });
  }

  Future<void> signInWithGoogle(BuildContext context, {String? referralCode}) async {
    try {
      developer.log('Starting Google Sign-In flow');

      // Disconnect any existing sessions to ensure fresh sign-in
      await _googleSignIn.disconnect();

      // Trigger the authentication flow
      final GoogleSignInAccount googleUser =
          await _googleSignIn.attemptLightweightAuthentication() ??
              await _googleSignIn.authenticate();

      developer.log('Google Sign-In response received');

      developer.log('Google user authenticated: ${googleUser.email}');

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      developer.log('Google authentication obtained');

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential result =
          await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user != null) {
        developer.log('Firebase user signed in: ${user.uid}');

        // Save authentication state for offline access
        await _saveAuthState(user);

        // Check and reset weekly uploads if needed
        await _userService.checkAndResetWeeklyUploads(user.uid);

        // Use the SyncProvider to trigger the sync
        await Provider.of<SyncProvider>(context, listen: false).syncData();

        final isNewUser = result.additionalUserInfo?.isNewUser ?? false;
        if (isNewUser) {
          developer.log('New user signed in with Google: ${user.uid}');
          UserModel newUser = UserModel(
            uid: user.uid,
            displayName: user.displayName ?? '',
            email: user.email ?? '',
          );
          await _firestoreService.saveUserData(newUser);

          if (referralCode != null && referralCode.isNotEmpty) {
            try {
              await _referralService.applyReferralCode(referralCode, user.uid);
            } catch (e, s) {
              developer.log(
                  'Error applying referral code during Google Sign-In',
                  error: e,
                  stackTrace: s);
              // Don't fail the entire sign-in process if referral code fails
              // Just log the error and continue
            }
          }
        } else {
          developer.log('Existing user signed in with Google: ${user.uid}');
        }
      }
    } on FirebaseAuthException catch (e, s) {
      developer.log('Firebase Auth error during Google Sign-In',
          error: e, stackTrace: s);

      // Handle specific error cases
      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw Exception(
              'An account already exists with the same email address but different sign-in credentials. Please use the original sign-in method.');
        case 'invalid-credential':
          throw Exception(
              'The supplied auth credential is malformed or has expired.');
        case 'operation-not-allowed':
          throw Exception(
              'Google Sign-In is disabled. Please contact support.');
        case 'user-disabled':
          throw Exception(
              'This account has been disabled. Please contact support.');
        case 'user-not-found':
          throw Exception('No user found with these credentials.');
        case 'wrong-password':
          throw Exception('Incorrect password.');
        case 'network-request-failed':
          throw Exception(
              'Network error. Please check your connection and try again.');
        default:
          throw Exception('Authentication failed. Please try again later.');
      }
    } on GoogleSignInException catch (e, s) {
      developer.log('Google Sign-In error', error: e, stackTrace: s);

      // Handle specific Google Sign-In errors
      final errorMessage = e.toString();
      if (errorMessage.contains('network error')) {
        throw Exception(
            'Network error during Google Sign-In. Please check your connection and try again.');
      } else {
        throw Exception('Google Sign-In failed: $errorMessage');
      }
    } catch (e, s) {
      developer.log('An unexpected error occurred during Google Sign-In',
          error: e, stackTrace: s);
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<void> signInWithEmailAndPassword(BuildContext context, String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save authentication state for offline access
      if (result.user != null) {
        await _saveAuthState(result.user!);
        // Use the SyncProvider to trigger the sync
        await Provider.of<SyncProvider>(context, listen: false).syncData();
      }
    } on FirebaseAuthException catch (e, s) {
      developer.log('Error signing in with email', error: e, stackTrace:s);
      rethrow;
    }
  }

  Future<void> signUpWithEmailAndPassword(BuildContext context, String email, String password,
      String fullName, String? referralCode) async {
    try {
      // CRITICAL FIX C5: Use Cloud Function for atomic signup + referral
      // This prevents partial failures (user created but referral not applied)
      final callable =
          FirebaseFunctions.instance.httpsCallable('signUpWithReferral');
      final cloudFunctionResult = await callable.call({
        'email': email,
        'password': password,
        'displayName': fullName,
        'referralCode': referralCode,
      });

      developer.log(
          'User created via Cloud Function: ${cloudFunctionResult.data['uid']}');

      // Sign in the newly created user
      final authResult = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save authentication state for offline access
      if (authResult.user != null) {
        await _saveAuthState(authResult.user!);
        // Use the SyncProvider to trigger the sync
        await Provider.of<SyncProvider>(context, listen: false).syncData();
      }

      // HIGH PRIORITY FIX H1: Send email verification
      // Prevent fake account abuse by requiring verification
      try {
        await _auth.currentUser?.sendEmailVerification();
        developer.log('Verification email sent to $email');
      } catch (e) {
        developer.log('Failed to send verification email', error: e);
        // Don't block signup, user can resend later
      }
    } on FirebaseFunctionsException catch (e, s) {
      developer.log('Cloud Function signup failed', error: e, stackTrace: s);
      rethrow;
    } on FirebaseAuthException catch (e, s) {
      developer.log('Error signing in after signup', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      // Clear saved authentication state
      await _clearAuthState();
    } catch (e, s) {
      developer.log('Error signing out', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // HIGH PRIORITY FIX H2: Rate Limiting (Password Reset)
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendPasswordResetEmail');
      await callable.call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      developer.log('Error sending password reset email via Cloud Function',
          error: e);
      rethrow;
    } catch (e, s) {
      developer.log('Unexpected error sending password reset email',
          error: e, stackTrace: s);
      rethrow;
    }
  }

  User? get currentUser => _auth.currentUser;

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        developer.log('Verification email resent to ${user.email}');
      } catch (e) {
        developer.log('Failed to resend verification email', error: e);
        rethrow;
      }
    }
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
}
