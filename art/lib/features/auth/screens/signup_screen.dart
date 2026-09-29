import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/profile_repository.dart';

enum UsernameStatus {
  none,
  tooShort,
  invalid,
  checking,
  available,
  taken,
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Timer? _debounceTimer;
  UsernameStatus _usernameStatus = UsernameStatus.none;
  bool _isCheckingUsername = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    final clean = value.trim().replaceAll('@', '');

    if (clean.isEmpty) {
      setState(() {
        _usernameStatus = UsernameStatus.none;
        _isCheckingUsername = false;
      });
      return;
    }

    if (clean.length < 3) {
      setState(() {
        _usernameStatus = UsernameStatus.tooShort;
        _isCheckingUsername = false;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
      setState(() {
        _usernameStatus = UsernameStatus.invalid;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameStatus = UsernameStatus.checking;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      await _checkUsernameAvailability(clean);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    try {
      final profile = await ProfileRepository().getProfileByUsername(username);
      if (!mounted) return;

      final currentClean = _usernameController.text.trim().replaceAll('@', '');
      if (currentClean != username) return;

      setState(() {
        _isCheckingUsername = false;
        _usernameStatus = (profile == null)
            ? UsernameStatus.available
            : UsernameStatus.taken;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _usernameStatus = UsernameStatus.available;
      });
    }
  }

  Future<void> _handleSignUp() async {
    final rawUsername = _usernameController.text.trim().replaceAll('@', '');

    if (_usernameStatus == UsernameStatus.taken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✕ Username already taken. Please choose another.'),
        ),
      );
      return;
    }

    if (_isCheckingUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking username availability...'),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate() && _agreeToTerms) {
      setState(() => _isLoading = true);
      try {
        await AuthRepository().signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          username: rawUsername,
        );
        if (mounted) {
          context.go('/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign up failed: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Privacy Policy'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;
    final bgColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.colorScheme.surface;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light 
            ? Brightness.dark 
            : Brightness.light,
        statusBarBrightness: theme.brightness == Brightness.light 
            ? Brightness.light 
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    const SizedBox(height: 20),

                    // Logo
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/app_icon/app_icon.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Header
                    Text(
                      'Create Your Account',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: textColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Subtle accent line
                    Container(
                      width: 140,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.4),
                            primaryColor.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join a community of AI artists and collectors.',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: textColor.withOpacity(0.6),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Username Field
                    _buildTextField(
                      controller: _usernameController,
                      hint: 'Username',
                      icon: Icons.person_outline_rounded,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      autofillHint: AutofillHints.newUsername,
                      onChanged: _onUsernameChanged,
                      suffixIcon: _buildUsernameSuffixIcon(primaryColor),
                      validator: (value) {
                        final clean = (value ?? '').trim().replaceAll('@', '');
                        if (clean.isEmpty) {
                          return 'Username is required';
                        }
                        if (clean.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
                          return 'Only letters, numbers, and underscores allowed';
                        }
                        if (_usernameStatus == UsernameStatus.taken) {
                          return 'Username already taken';
                        }
                        return null;
                      },
                    ),
                    _buildUsernameStatusIndicator(textColor),
                    const SizedBox(height: 14),

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      hint: 'Email address',
                      icon: Icons.mail_outline_rounded,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      keyboardType: TextInputType.emailAddress,
                      autofillHint: AutofillHints.email,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password Field
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      obscureText: _obscurePassword,
                      autofillHint: AutofillHints.newPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: textColor.withOpacity(0.45),
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Confirm Password Field
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hint: 'Confirm Password',
                      icon: Icons.lock_outline_rounded,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: textColor.withOpacity(0.45),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Terms and Conditions Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreeToTerms,
                            activeColor: primaryColor,
                            checkColor: bgColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: BorderSide(
                              color: textColor.withOpacity(0.25),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _agreeToTerms = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() => _agreeToTerms = !_agreeToTerms);
                            },
                            child: Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: textColor.withOpacity(0.6),
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Privacy Policy',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Sign Up Button
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          disabledBackgroundColor: primaryColor.withOpacity(
                            0.7,
                          ),
                          foregroundColor: bgColor,
                          elevation: 0,
                          shadowColor: primaryColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isLoading
                              ? SizedBox(
                                  key: const ValueKey('loading'),
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.coral,
                                  ),
                                )
                              : const Text(
                                  'Sign Up',
                                  key: ValueKey('label'),
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),


                    const SizedBox(height: 32),

                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/login'),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 4.0,
                            ),
                            child: Text(
                              'Log In',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildUsernameSuffixIcon(Color primaryColor) {
    if (_isCheckingUsername) {
      return Padding(
        padding: const EdgeInsets.all(14.0),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: primaryColor,
          ),
        ),
      );
    }
    if (_usernameStatus == UsernameStatus.available) {
      return const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF2E7D32),
        size: 22,
      );
    }
    if (_usernameStatus == UsernameStatus.taken) {
      return Icon(
        Icons.cancel_rounded,
        color: Colors.redAccent.shade200,
        size: 22,
      );
    }
    return null;
  }

  Widget _buildUsernameStatusIndicator(Color textColor) {
    final rawInput = _usernameController.text.trim();
    if (rawInput.isEmpty) return const SizedBox.shrink();

    final cleanInput = rawInput.startsWith('@') ? rawInput : '@$rawInput';

    if (_usernameStatus == UsernameStatus.available) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Row(
          children: [
            const Icon(Icons.check, size: 16, color: Color(0xFF2E7D32)),
            const SizedBox(width: 6),
            Text(
              '✓ Username available ($cleanInput)',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else if (_usernameStatus == UsernameStatus.taken) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Row(
          children: [
            Icon(Icons.close, size: 16, color: Colors.redAccent.shade200),
            const SizedBox(width: 6),
            Text(
              '✕ Username already taken ($cleanInput)',
              style: TextStyle(
                color: Colors.redAccent.shade200,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else if (_usernameStatus == UsernameStatus.tooShort) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          'Username must be at least 3 characters',
          style: TextStyle(
            color: textColor.withOpacity(0.55),
            fontSize: 12.5,
          ),
        ),
      );
    } else if (_usernameStatus == UsernameStatus.invalid) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          'Only letters, numbers, and underscores allowed',
          style: TextStyle(
            color: Colors.orangeAccent.shade400,
            fontSize: 12.5,
          ),
        ),
      );
    } else if (_isCheckingUsername) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          'Checking availability...',
          style: TextStyle(
            color: textColor.withOpacity(0.55),
            fontSize: 12.5,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color textColor,
    required Color primaryColor,
    required Color surfaceColor,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? autofillHint,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHint == null ? null : [autofillHint],
      style: TextStyle(color: textColor, fontSize: 15),
      cursorColor: primaryColor,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textColor.withOpacity(0.35), fontSize: 15),
        prefixIcon: Icon(icon, size: 20, color: textColor.withOpacity(0.45)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textColor.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textColor.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.redAccent.shade200),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.redAccent.shade200, width: 1.6),
        ),
        errorStyle: TextStyle(fontSize: 12, color: Colors.redAccent.shade200),
      ),
    );
  }
}
