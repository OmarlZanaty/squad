import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/utils/app_localizations.dart';

import 'package:squad/services/api_service.dart';
import 'package:squad/screens/login_screen.dart';
import 'package:squad/screens/terms_of_use_screen.dart';
import 'package:squad/screens/privacy_policy_screen.dart';
import 'package:squad/screens/otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'guest'; // Default role
  bool _acceptedTerms = false; // Terms acceptance
  Timer? _resendTimer;
  final ValueNotifier<bool> _canResendOtp = ValueNotifier(true);
  final ValueNotifier<bool> _isLoadingWhatsapp = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingSms = ValueNotifier(false);
  final ValueNotifier<int> _remainingSeconds = ValueNotifier(60);

  @override
  void dispose() {
    _nameController.dispose();

    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    _canResendOtp.dispose();
    _isLoadingWhatsapp.dispose();
    _isLoadingSms.dispose();
    _remainingSeconds.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if terms are accepted
    if (!_acceptedTerms) {
      final loc = AppLocalizations.of(context);
      _showError(loc?.tr('must_accept_terms') ?? 'يجب الموافقة على الشروط والأحكام');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.register(
        name: _nameController.text.trim(),

        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );

      if (!mounted) return;

      final loc = AppLocalizations.of(context);

      if (result['success'] == true) {
        // Show OTP method selection bottom sheet
        _showOtpMethodBottomSheet();
      } else {
        _showError(result['message'] ?? (loc?.tr('error_register_failed') ?? 'Registration failed'));
      }
    } catch (e) {
      final loc = AppLocalizations.of(context);
      _showError('${loc?.tr('error') ?? 'Error'}: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  TextDirection getTextDirection(String text) {
    if (text.isEmpty) return TextDirection.ltr;

    final firstChar = text.trim().characters.first;

    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(firstChar);

    return isArabic ? TextDirection.rtl : TextDirection.ltr;
  }

  void _showOtpMethodBottomSheet() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 15,
                children: [
                  Text(loc?.tr('select_otp_method') ?? 'Select OTP Method', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ValueListenableBuilder<bool>(
                    valueListenable: _canResendOtp,
                    builder: (context, canResend, child) {
                      if (canResend) return SizedBox.shrink();
                      return ValueListenableBuilder<int>(
                        valueListenable: _remainingSeconds,
                        builder: (context, remaining, child) {
                          return Text(
                            (loc?.tr('resend_in') ?? 'Resend in {count}').replaceAll('{count}', remaining.toString()),
                            style: const TextStyle(fontSize: 16, color: Colors.red),
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoadingSms,
                    builder: (context, isLoading, child) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _canResendOtp,
                        builder: (context, canResend, child) {
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.message_outlined),
                            label: isLoading
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text(
                                  loc?.tr('resending_via_sms') ?? 'Resending via SMS',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                                : Text(
                              loc?.tr('receive_otp_via_sms') ?? 'Receive OTP via SMS',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                            onPressed: canResend ? () => _sendOtp('sms') : null,
                            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48))),
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoadingWhatsapp,
                    builder: (context, isLoading, child) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _canResendOtp,
                        builder: (context, canResend, child) {
                          return ElevatedButton.icon(
                            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                            label: isLoading
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text(
                                  loc?.tr('resending_via_whatsapp') ?? 'Resending via WhatsApp',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                                : Text(
                              loc?.tr('receive_otp_via_whatsapp') ?? 'Receive OTP via WhatsApp',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                            onPressed: canResend ? () => _sendOtp('whatsapp') : null,
                            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48))),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendOtp(String method) async {
    final loc = AppLocalizations.of(context);

    // Validate phone number
    if (_phoneController.text.isEmpty || _phoneController.text.length < 10) {
      _showError(loc?.tr('validation_phone_required') ?? 'Phone number is required');
      return;
    }

    // Start loading
    if (method == 'sms') {
      _isLoadingSms.value = true;
    } else {
      _isLoadingWhatsapp.value = true;
    }

    try {
      final response = await ApiService.sendOtp(
        phone: _phoneController.text.trim(),
        verificationMethod: method,
      );

      if (response['success'] == true) {
        // OTP sent successfully, navigate to verification screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: _phoneController.text.trim(),
              verificationMethod: method,
            ),
          ),
        );
      } else {
        _showError(response['message'] ?? (loc?.tr('error_sending_otp') ?? 'Error sending OTP'));
      }
    } catch (e) {
      _showError('${loc?.tr('error') ?? 'Error'}: $e');
    } finally {
      // Stop loading
      if (method == 'sms') {
        _isLoadingSms.value = false;
      } else {
        _isLoadingWhatsapp.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Title
                Text(
                  loc?.tr('register_title') ?? 'Create New Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  loc?.tr('') ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  textDirection: getTextDirection(_nameController.text),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: loc?.tr('full_name') ?? 'Full Name',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                    ),
                   // hintText: loc?.tr('full_name_hint') ?? 'Enter your full name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return loc?.tr('validation_name_required') ?? 'Name is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),


                // Phone Number Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: loc?.tr('phone') ?? 'Phone Number',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                    ),
                    hintText: loc?.tr('phone_hint') ?? 'Enter your phone number',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return loc?.tr('validation_phone_required') ?? 'Phone number is required';
                    }
                    if (value.length < 10) {
                      return loc?.tr('validation_phone_invalid') ?? 'Invalid phone number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textDirection: getTextDirection(_nameController.text),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: loc?.tr('password') ?? 'Password',
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                    ),
                    hintText: loc?.tr('password_hint2') ?? 'Enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.grey,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return loc?.tr('validation_password_required') ?? 'Password is required';
                    }
                    if (value.length < 8) {
                      return loc?.tr('validation_password_short') ??
                          'Password is too short (minimum 8 characters)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textDirection: getTextDirection(_nameController.text),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: loc?.tr('confirm_password') ?? 'Confirm Password',
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                    ),
                    hintText: loc?.tr('confirm_password_hint') ?? 'Re-enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.grey,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return loc?.tr('validation_password_required') ?? 'Password is required';
                    }
                    if (value != _passwordController.text) {
                      return loc?.tr('validation_password_mismatch') ?? 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Role Selection
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'guest',
                                child: Text('مُشجع'),
                              ),
                              DropdownMenuItem(
                                value: 'scout',
                                enabled: false,
                                child: Row(
                                  children: [
                                    Text(
                                      'مُستكشف',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedRole = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Terms and Privacy Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (value) {
                        setState(() => _acceptedTerms = value ?? false);
                      },
                      activeColor: isDark ? AppColors.darkModeAccent : AppColors.primary,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          children: [
                            Text(
                              loc?.tr('i_agree_to') ?? 'أوافق على ',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TermsOfUseScreen(showAcceptButton: false),
                                  ),
                                );
                              },
                              child: Text(
                                loc?.tr('terms_conditions') ?? 'الشروط والأحكام',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            Text(
                              ' ${loc?.tr('and') ?? 'و'} ',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PrivacyPolicyScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                loc?.tr('privacy_policy') ?? 'سياسة الخصوصية',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Register Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkModeAccent : AppColors.primary,
                      foregroundColor: isDark ? AppColors.black : Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                      loc?.tr('send_otp') ?? 'Send OTP',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      loc?.tr('already_have_account') ?? 'Already have an account?',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: Text(
                        loc?.tr('login_now') ?? 'Login Now',
                        style: TextStyle(
                          color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
