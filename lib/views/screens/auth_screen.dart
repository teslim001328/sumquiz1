import 'package:flutter/material.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthMode { login, signUp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _referralCodeController = TextEditingController();
  AuthMode _authMode = AuthMode.login;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _switchAuthMode() {
    setState(() {
      _authMode =
          _authMode == AuthMode.login ? AuthMode.signUp : AuthMode.login;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (_authMode == AuthMode.login) {
        await authService.signInWithEmailAndPassword(
          context,
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await authService.signUpWithEmailAndPassword(
          context,
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _fullNameController.text.trim(),
          _referralCodeController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Authentication failed. Please try again.';

      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'weak-password':
          errorMessage =
              'Password is too weak. Please use a stronger password.';
          break;
        case 'network-request-failed':
          errorMessage =
              'Network error. Please check your connection and try again.';
          break;
        default:
          errorMessage = 'Authentication failed. Please try again later.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      // Check if this is a referral-related error
      String errorMessage = 'Authentication Failed: ${e.toString()}';
      if (e.toString().contains('referral')) {
        errorMessage =
            'Referral code error: ${e.toString().replaceAll('Exception:', '').trim()}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _googleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Add a small delay to ensure UI updates before starting the flow
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithGoogle(context,
          referralCode: _referralCodeController.text.trim());
    } catch (e) {
      String errorMessage = 'Google Sign-In failed. Please try again.';

      // Check for specific error types
      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('cancelled')) {
        // Don't show an error message if the user cancelled the sign-in
        errorMessage = '';
      } else if (e.toString().contains('account disabled')) {
        errorMessage =
            'This account has been disabled. Please contact support.';
      } else if (e.toString().contains('malformed') ||
          e.toString().contains('expired')) {
        errorMessage = 'Authentication token is invalid. Please try again.';
      } else if (e.toString().contains('Google Sign-In is disabled')) {
        errorMessage =
            'Google Sign-In is currently disabled. Please try again later.';
      } else if (e.toString().contains('referral')) {
        // Handle referral-related errors
        errorMessage =
            'Referral code error: ${e.toString().replaceAll('Exception:', '').trim()}';
      } else {
        // Use the actual error message from the exception
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
        if (errorMessage.isEmpty) {
          errorMessage = 'Google Sign-In failed. Please try again.';
        }
      }

      if (mounted && errorMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _authMode == AuthMode.login
                    ? _buildLoginForm(theme)
                    : _buildSignUpForm(theme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('loginForm'),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue your learning journey.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 48),
          _buildTextField(
            theme: theme,
            controller: _emailController,
            labelText: 'Email Address',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || !value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            theme: theme,
            controller: _passwordController,
            labelText: 'Password',
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          _buildAuthButton('Sign In', _submit, theme),
          const SizedBox(height: 24),
          _buildGoogleButton(theme),
          const SizedBox(height: 24),
          _buildSwitchAuthModeButton(
            theme,
            'Don\'t have an account? ',
            'Sign Up',
            _switchAuthMode,
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('signUpForm'),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Account',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Start your learning adventure with us.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 48),
          _buildTextField(
            theme: theme,
            controller: _fullNameController,
            labelText: 'Full Name',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            theme: theme,
            controller: _emailController,
            labelText: 'Email Address',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || !value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            theme: theme,
            controller: _passwordController,
            labelText: 'Password',
            obscureText: true,
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            theme: theme,
            controller: _referralCodeController,
            labelText: 'Referral Code (Optional)',
            validator: null, // Optional field
          ),
          const SizedBox(height: 32),
          _buildAuthButton('Sign Up', _submit, theme),
          const SizedBox(height: 24),
          _buildGoogleButton(theme),
          const SizedBox(height: 24),
          _buildSwitchAuthModeButton(
            theme,
            'Already have an account? ',
            'Sign In',
            _switchAuthMode,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required ThemeData theme,
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Color.fromRGBO(theme.colorScheme.onSurface.red, theme.colorScheme.onSurface.green, theme.colorScheme.onSurface.blue, 0.6)),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildAuthButton(String text, VoidCallback onPressed, ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                    strokeWidth: 3))
            : Text(
                text,
              ),
      ),
    );
  }

  Widget _buildGoogleButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: SvgPicture.asset('assets/icons/google_logo.svg', height: 20),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Color.fromRGBO(theme.colorScheme.onSurface.red, theme.colorScheme.onSurface.green, theme.colorScheme.onSurface.blue, 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        onPressed: _isLoading ? null : _googleSignIn,
        label: Text(
          'Continue with Google',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchAuthModeButton(
      ThemeData theme, String text, String buttonText, VoidCallback onPressed) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: RichText(
          text: TextSpan(
            text: text,
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(
                text: buttonText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
