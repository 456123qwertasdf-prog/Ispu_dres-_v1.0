import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:ui';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/onesignal_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();
  final _signupStudentNumberController = TextEditingController();
  final CarouselSliderController _carouselController = CarouselSliderController();
  
  bool _obscurePassword = true;
  bool _obscureSignupPassword = true;
  bool _obscureSignupConfirmPassword = true;
  bool _isLoading = false;
  bool _isSignupLoading = false;
  bool _showLoginForm = false;
  bool _showSignupForm = false;
  int _currentSlide = 0;
  String? _selectedUserType = 'student'; // Default to student
  String _passwordStrength = ''; // Password strength indicator
  final _forgotPasswordEmailController = TextEditingController();
  bool _isForgotPasswordLoading = false;
  /// Clear, highlighted auth error messages (sign-up / login) so user knows exactly why it failed.
  String? _signupErrorMessage;
  String? _loginErrorMessage;
  /// Installed app version only (from PackageInfo). Shows what this APK actually is.
  /// Old builds are blocked by the update check in main.dart before this screen is shown.
  String _appVersion = '';

  // Background slider images
  final List<String> _backgroundImages = [
    'assets/images/slider-1.jpg',
    'assets/images/slider-2.jpg',
    'assets/images/slider-3.jpg',
    'assets/images/slider-4.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  /// Load installed app version only. Version shown here is what you actually installed.
  /// DB min_version is checked in main.dart _UpdateCheckGate; old versions never reach this screen.
  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _signupStudentNumberController.dispose();
    _forgotPasswordEmailController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Sign in with Supabase
      final response = await SupabaseService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Save user info to SharedPreferences for backward compatibility
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', response.user!.id);
        await prefs.setString('user_email', email);
        // Register OneSignal player ID now that user is authenticated (fixes new responders not receiving notifications)
        await OneSignalService().retrySavePlayerIdToSupabase();
        await _navigateAfterLogin(
          userId: response.user!.id,
          metadata: response.user!.userMetadata,
        );
      } else {
        throw Exception('Login failed: No user returned');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Login failed';
        final s = e.toString();
        if (s.contains('Invalid login credentials')) {
          msg = 'Invalid email or password. Please try again.';
        } else if (s.contains('Email not confirmed')) {
          msg = 'Please verify your email before signing in.';
        } else if (s.contains('rate limit') || s.contains('429')) {
          msg = 'Too many attempts. Please wait a minute and try again.';
        } else {
          msg = s.replaceFirst('Exception: ', '').replaceFirst('AuthApiException(message: ', '').replaceAll(RegExp(r', statusCode: \d+, code: \w+\)'), '').trim();
          if (msg.isEmpty) msg = 'Login failed. Please try again.';
        }
        setState(() {
          _loginErrorMessage = msg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateAfterLogin({
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    String destination = '/home';

    try {
      final profile = await SupabaseService.client
          .from('user_profiles')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();

      String? role = (profile?['role'] as String?)?.toLowerCase();

      if (role == null) {
        final responderMatch = await SupabaseService.client
            .from('responder')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (responderMatch != null) {
          role = 'responder';
        } else {
          role = (metadata?['role'] as String?)?.toLowerCase();
        }
      }

      if (role == 'responder' || role == 'admin') {
        destination = '/responder-dashboard';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role ?? 'citizen');
    } catch (_) {
      // Fallback to citizen home on any lookup issue.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(destination);
  }

  // Password strength validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character (!@#\$%^&*...)';
    }
    
    return null;
  }
  
  // Calculate password strength
  void _calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
      });
      return;
    }
    
    int strength = 0;
    String feedback = '';
    
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    
    if (strength <= 2) {
      feedback = 'Weak';
    } else if (strength <= 4) {
      feedback = 'Fair';
    } else if (strength <= 5) {
      feedback = 'Good';
    } else {
      feedback = 'Strong';
    }
    
    setState(() {
      _passwordStrength = feedback;
    });
  }

  void _showForgotPasswordDialogFunc() {
    _forgotPasswordEmailController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? forgotPasswordError;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _forgotPasswordEmailController.clear();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your email address and we\'ll send you a link to reset your password.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (forgotPasswordError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade900, width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                forgotPasswordError!,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _forgotPasswordEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isForgotPasswordLoading
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  _forgotPasswordEmailController.clear();
                                },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isForgotPasswordLoading
                              ? null
                              : () async {
                                  setDialogState(() => forgotPasswordError = null);
                                  await _handleForgotPassword(setDialogState, context, (String msg) {
                                    setDialogState(() => forgotPasswordError = msg);
                                  });
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isForgotPasswordLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Send Reset Link'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleForgotPassword(StateSetter setDialogState, BuildContext dialogContext, void Function(String) setDialogError) async {
    final email = _forgotPasswordEmailController.text.trim();
    
    if (email.isEmpty) {
      setDialogError('Please enter your email address.');
      return;
    }
    
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setDialogError('Please enter a valid email address.');
      return;
    }
    
    setDialogState(() {
      _isForgotPasswordLoading = true;
    });
    
    try {
      await SupabaseService.resetPassword(email: email);
      
      if (mounted) {
        Navigator.of(dialogContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Please check your inbox.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        _forgotPasswordEmailController.clear();
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to send reset email.';
        final s = e.toString();
        if (s.contains('User not found')) {
          msg = 'No account found with this email address.';
        } else if (s.contains('over_email_send_rate_limit') || s.contains('429') || (s.contains('after ') && s.contains(' seconds'))) {
          final match = RegExp(r'after (\d+) seconds').firstMatch(s);
          msg = match != null
              ? 'Too many attempts. Please wait ${match.group(1)} seconds before trying again.'
              : 'Too many attempts. Please wait a minute and try again.';
        } else if (s.isNotEmpty) {
          msg = s.replaceFirst('Exception: ', '').replaceFirst('AuthApiException(message: ', '').replaceAll(RegExp(r', statusCode: \d+, code: \w+\)'), '').trim();
          if (msg.isEmpty) msg = 'Failed to send reset email. Please try again.';
        }
        setDialogError(msg);
      }
    } finally {
      if (mounted) {
        setDialogState(() {
          _isForgotPasswordLoading = false;
        });
      }
    }
  }

  /// Parses auth/sign-up errors into a short, user-friendly message (for highlighted banner).
  String _parseSignUpErrorMessage(dynamic e) {
    final s = e.toString();
    if (s.contains('over_email_send_rate_limit') || s.contains('429') || s.contains('rate limit') || s.contains('after ') && s.contains(' seconds')) {
      final match = RegExp(r'after (\d+) seconds').firstMatch(s);
      final sec = match != null ? match.group(1) : null;
      if (sec != null) {
        return 'Too many sign-up attempts. For security, please wait $sec seconds before trying again.';
      }
      return 'Too many sign-up attempts. Please wait a minute and try again.';
    }
    if (s.contains('User already registered') || s.contains('already registered') || s.contains('already exist')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (s.contains('Invalid email') || s.contains('invalid_email')) {
      return 'Please enter a valid email address.';
    }
    if (s.contains('Password') || s.contains('password')) {
      return 'Password does not meet requirements.';
    }
    return s.replaceFirst('Exception: ', '').replaceFirst('AuthApiException(message: ', '').replaceFirst(RegExp(r', statusCode: \d+, code: \w+\)'), '').trim();
  }

  Future<void> _handleSignUp() async {
    if (!_signupFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _signupErrorMessage = null;
      _isSignupLoading = true;
    });

    try {
      final name = _signupNameController.text.trim();
      final email = _signupEmailController.text.trim();
      final password = _signupPasswordController.text;
      final studentNumber = _signupStudentNumberController.text.trim();

      // Block duplicate ID Number before calling signUp
      final idExists = await SupabaseService.checkStudentNumberExists(studentNumber);
      if (idExists && mounted) {
        setState(() {
          _signupErrorMessage = 'This ID Number is already registered. Please sign in or use a different ID number.';
          _isSignupLoading = false;
        });
        return;
      }

      // Sign up as citizen: ID number and email are required
      final response = await SupabaseService.signUpAsCitizen(
        email: email,
        password: password,
        fullName: name,
        userType: _selectedUserType ?? 'student',
        studentNumber: studentNumber,
      );

      if (response.user != null) {
        // Supabase returns user with empty identities when email already exists (no verification email sent)
        final identities = response.user!.identities;
        if (identities == null || identities.isEmpty) {
          if (mounted) {
            setState(() {
              _signupErrorMessage = 'This email is already registered. Please sign in instead.';
              _isSignupLoading = false;
            });
          }
          return;
        }

        // Create user profile in database (only when sign-up actually created a new user)
        try {
          await SupabaseService.client.from('user_profiles').insert({
            'user_id': response.user!.id,
            'role': 'citizen',
            'name': name,
            'phone': '', // Can be added later
            'student_number': studentNumber.isNotEmpty ? studentNumber : null,
            'user_type': _selectedUserType ?? 'student', // Add user_type to profile
            'is_active': true,
          });
        } catch (e) {
          // Profile might already exist or will be created by trigger
          debugPrint('Profile creation note: $e');
        }

        // Save user info to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', response.user!.id);
        await prefs.setString('user_email', email);

        // Check if email is confirmed
        final isEmailConfirmed = response.user!.emailConfirmedAt != null;

        if (mounted) {
          if (isEmailConfirmed) {
            // Email already confirmed, navigate to home
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              await _navigateAfterLogin(
                userId: response.user!.id,
                metadata: response.user!.userMetadata,
              );
            }
          } else {
            // Email not confirmed, show dialog with resend option
            _showEmailVerificationDialog(email);
          }
        }
      } else {
        throw Exception('Sign up failed: No user returned');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _signupErrorMessage = _parseSignUpErrorMessage(e);
          _isSignupLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSignupLoading = false;
        });
      }
    }
  }

  void _showEmailVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Verify Your Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('We\'ve sent a verification email to:'),
              const SizedBox(height: 8),
              Text(
                email,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please check your email and click the verification link to activate your account.',
              ),
              const SizedBox(height: 8),
              const Text(
                'If you didn\'t receive the email, check your spam folder or click "Resend Email" below.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Close signup form and show login
                setState(() {
                  _showSignupForm = false;
                  _showLoginForm = false;
                });
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await SupabaseService.resendEmailVerification(email: email);
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Verification email sent! Please check your inbox.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to resend email: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              child: const Text('Resend Email'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Slider with Blur and Blue Overlay
          _buildBackgroundSlider(),
          
          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Logo Container
                    _buildLogo(),
                    
                    const SizedBox(height: 32),
                    
                    // Welcome Message
                    _buildWelcomeMessage(),
                    
                    const SizedBox(height: 16),
                    
                    // Instructional Text
                    _buildInstructionText(),
                    
                    const SizedBox(height: 48),
                    
                    // Login Form Card (shown when Sign In is clicked)
                    if (_showLoginForm) _buildLoginForm(),
                    
                    // Sign Up Form Card (shown when Sign Up is clicked)
                    if (_showSignupForm) _buildSignUpForm(),
                    
                    const SizedBox(height: 32),
                    
                    // Sign In and Sign Up Buttons (shown when no form is displayed)
                    if (!_showLoginForm && !_showSignupForm) _buildAuthButtons(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          
          // Slide Indicators
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _backgroundImages.asMap().entries.map((entry) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentSlide == entry.key
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                );
              }).toList(),
            ),
          ),
          // App version at bottom of login screen (above nav bar and dots)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Version ${_appVersion.isNotEmpty ? _appVersion : '—'}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundSlider() {
    return CarouselSlider(
      carouselController: _carouselController,
      options: CarouselOptions(
        height: double.infinity,
        viewportFraction: 1.0,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        autoPlayCurve: Curves.fastOutSlowIn,
        onPageChanged: (index, reason) {
          setState(() {
            _currentSlide = index;
          });
        },
      ),
      items: _backgroundImages.map((imagePath) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              decoration: const BoxDecoration(),
              child: Stack(
                children: [
                  // Background Image
                  Positioned.fill(
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                  
                  // Blurred background effect
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  
                  // Blue overlay
                  Positioned.fill(
                    child: Container(
                      color: Colors.blue.shade900.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/udrrmo-logo.jpg',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return const Text(
      'Welcome Kapiyu!',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInstructionText() {
    return Text(
      'To keep connected with us please login with your personal info',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withOpacity(0.9),
        height: 1.5,
      ),
    );
  }

  Widget _buildAuthButtons() {
    return Column(
      children: [
        // Sign In Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _loginErrorMessage = null;
                _showLoginForm = true;
                _showSignupForm = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.3),
            ),
            child: const Text(
              'SIGN IN',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Sign Up Button 
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _signupErrorMessage = null;
                _showSignupForm = true;
                _showLoginForm = false;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'SIGN UP',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _loginFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showLoginForm = false;
                  });
                },
              ),
            ),
            
            const SizedBox(height: 8),
            // Highlighted login error
            if (_loginErrorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade900, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _loginErrorMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            
            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _showForgotPasswordDialogFunc();
                },
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 24),
            
            // Login Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'SIGN IN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            // Switch to Sign Up
            TextButton(
              onPressed: () {
                setState(() {
                  _showLoginForm = false;
                  _signupErrorMessage = null;
                _showSignupForm = true;
                });
              },
              child: const Text('Don\'t have an account? Sign up'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _signupFormKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showSignupForm = false;
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Highlighted sign-up error so user knows exactly why it failed
              if (_signupErrorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade900, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _signupErrorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Name Field
              TextFormField(
                controller: _signupNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  if (value.length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // User Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedUserType,
                decoration: InputDecoration(
                  labelText: 'User Type',
                  hintText: 'Select your type',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'student',
                    child: Text('Student'),
                  ),
                  DropdownMenuItem(
                    value: 'instructor',
                    child: Text('Instructor'),
                  ),
                  DropdownMenuItem(
                    value: 'faculty_staff',
                    child: Text('Faculty/Staff'),
                  ),
                  DropdownMenuItem(
                    value: 'security_guard',
                    child: Text('Security Guard'),
                  ),
                  DropdownMenuItem(
                    value: 'first_aider',
                    child: Text('First Aider'),
                  ),
                  DropdownMenuItem(
                    value: 'responder',
                    child: Text('Responder'),
                  ),
                  DropdownMenuItem(
                    value: 'first_aider_leader',
                    child: Text('First Aider Leader'),
                  ),
                  DropdownMenuItem(
                    value: 'responder_leader',
                    child: Text('Responder Leader'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedUserType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your user type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // ID Number (required)
              TextFormField(
                controller: _signupStudentNumberController,
                decoration: InputDecoration(
                  labelText: 'ID Number',
                  hintText: 'Enter your ID number',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your ID number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Email Field (Gmail only)
              TextFormField(
                controller: _signupEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email (Gmail only)',
                  hintText: 'Enter your @gmail.com address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  final email = value.trim().toLowerCase();
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Please enter a valid email';
                  }
                  if (!email.endsWith('@gmail.com')) {
                    return 'Only @gmail.com addresses are allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Password Field
              TextFormField(
                controller: _signupPasswordController,
                obscureText: _obscureSignupPassword,
                onChanged: (value) {
                  _calculatePasswordStrength(value);
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter a strong password',
                  helperText: 'Must contain: 8+ chars, uppercase, lowercase, number, special char',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSignupPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureSignupPassword = !_obscureSignupPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: _validatePassword,
              ),
              // Password Strength Indicator
              if (_passwordStrength.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Text(
                        'Password Strength: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _passwordStrength,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _passwordStrength == 'Strong'
                              ? Colors.green
                              : _passwordStrength == 'Good'
                                  ? Colors.blue
                                  : _passwordStrength == 'Fair'
                                      ? Colors.orange
                                      : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _passwordStrength == 'Strong'
                              ? 1.0
                              : _passwordStrength == 'Good'
                                  ? 0.75
                                  : _passwordStrength == 'Fair'
                                      ? 0.5
                                      : 0.25,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _passwordStrength == 'Strong'
                                ? Colors.green
                                : _passwordStrength == 'Good'
                                    ? Colors.blue
                                    : _passwordStrength == 'Fair'
                                        ? Colors.orange
                                        : Colors.red,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              
              // Confirm Password Field
              TextFormField(
                controller: _signupConfirmPasswordController,
                obscureText: _obscureSignupConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Confirm your password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSignupConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureSignupConfirmPassword = !_obscureSignupConfirmPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _signupPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Sign Up Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSignupLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSignupLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'SIGN UP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // Switch to Sign In
              TextButton(
                onPressed: () {
                  setState(() {
                    _loginErrorMessage = null;
                    _showSignupForm = false;
                    _showLoginForm = true;
                  });
                },
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
