import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myapp/models/user_model.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/services/referral_service.dart';
import 'package:rxdart/rxdart.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final ReferralService _referralService = ReferralService();

  AuthService(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<UserModel?> get user {
    return _auth.authStateChanges().switchMap((user) {
      if (user == null) {
        return Stream.value(null);
      }
      return _firestoreService.streamUser(user.uid);
    });
  }

  Future<void> signInWithGoogle({String? referralCode}) async {
    try {
      final googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user != null) {
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
            await _referralService.applyReferralCode(referralCode, user.uid);
          }
        } else {
          developer.log('Existing user signed in with Google: ${user.uid}');
        }
      }
    } on FirebaseAuthException catch (e, s) {
      developer.log('Error signing in with Google', error: e, stackTrace: s);
      rethrow;
    } catch (e, s) {
      developer.log('An unexpected error occurred during Google Sign-In',
          error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e, s) {
      developer.log('Error signing in with email', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password,
      String fullName, String? referralCode) async {
    try {
      // CRITICAL FIX C5: Use Cloud Function for atomic signup + referral
      // This prevents partial failures (user created but referral not applied)
      final callable =
          FirebaseFunctions.instance.httpsCallable('signUpWithReferral');
      final result = await callable.call({
        'email': email,
        'password': password,
        'displayName': fullName,
        'referralCode': referralCode,
      });

      developer.log('User created via Cloud Function: ${result.data['uid']}');

      // Sign in the newly created user
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

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
