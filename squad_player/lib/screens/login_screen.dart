import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:squad_player/screens/reset_password_otp_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:squad_player/utils/app_colors.dart';
import 'package:squad_player/utils/app_localizations.dart';
import 'package:squad_player/services/api_service.dart';
import 'package:squad_player/services/auth_service.dart';
import 'package:squad_player/screens/register_screen.dart';
import 'package:squad_player/screens/main_screen.dart';

import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.fromVerification = false});
  final bool fromVerification;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Phone + password login — uses _phoneController (shared with OTP mode)
  final _passwordController = TextEditingController();

  // OTP login
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showPhonePasswordLogin = false; // renamed for clarity: true = phone+password, false = OTP

  final ValueNotifier<bool> _canResendOtp = ValueNotifier(true);
  final ValueNotifier<bool> _isLoadingWhatsapp = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingSms = ValueNotifier(false);
  Timer? _resendTimer;
  final ValueNotifier<int> _remainingSeconds = ValueNotifier(60);

  @override
  void dispose() {
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    _canResendOtp.dispose();
    _isLoadingWhatsapp.dispose();
    _isLoadingSms.dispose();
    _remainingSeconds.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.fromVerification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return InReviewBottomSheet();
          },
        );
      });
    }
  }



  bool _isPlayer(dynamic user) {
    final type = (user?['type'] ?? '').toString().toLowerCase().trim();
    return type == 'player';
  }

  Future<void> _toggleLoginMode() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _showPhonePasswordLogin = !_showPhonePasswordLogin;
      _otpController.clear();
      _passwordController.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ================= SUPPORT =================

  Future<void> _openWhatsApp() async {
    const phoneNumber = '201003100623';
    final uri = Uri.parse('https://wa.me/$phoneNumber');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError(
        AppLocalizations.of(context)?.tr('cannot_open_whatsapp') ?? 'Cannot open WhatsApp',
      );
    }
  }

  // ================= OTP =================

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
                  Text(
                    loc?.tr('select_otp_method') ?? 'Select OTP Method',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _canResendOtp,
                    builder: (context, canResend, child) {
                      if (canResend) return const SizedBox.shrink();
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
                          return ElevatedButton(
                            onPressed: canResend ? () => _sendOtp('sms') : null,
                            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                              minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
                            ),
                            child: isLoading
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text(loc?.tr('resending_via_sms') ?? 'Resending via SMS', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                const Icon(Icons.message_outlined),
                              ],
                            )
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(loc?.tr('receive_otp_via_sms') ?? 'Receive OTP via SMS', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                const Icon(Icons.message_outlined),
                              ],
                            ),
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
                          return ElevatedButton(
                            onPressed: canResend ? () => _sendOtp('whatsapp') : null,
                            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                              minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
                            ),
                            child: isLoading
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text(loc?.tr('resending_via_whatsapp') ?? 'Resending via WhatsApp', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                              ],
                            )
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(loc?.tr('receive_otp_via_whatsapp') ?? 'Receive OTP via WhatsApp', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                              ],
                            ),
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

  String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _sendOtp(String verificationMethod) async {
    _canResendOtp.value = false;
    if (verificationMethod == 'sms') {
      _isLoadingSms.value = true;
    } else {
      _isLoadingWhatsapp.value = true;
    }

    final Map<String, dynamic> response = await ApiService.sendOtp(
      phone: digitsOnly(_phoneController.text),
      verificationMethod: verificationMethod,
    );

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.only(top: 20, left: 16, right: 16),
        ),
      );
      if (verificationMethod == 'sms') {
        _isLoadingSms.value = false;
      } else {
        _isLoadingWhatsapp.value = false;
      }

      _canResendOtp.value = false;
      _remainingSeconds.value = 60;
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _remainingSeconds.value--;
        if (_remainingSeconds.value <= 0) {
          _canResendOtp.value = true;
          _remainingSeconds.value = 60;
          timer.cancel();
        }
      });
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: digitsOnly(_phoneController.text),
            verificationMethod: verificationMethod,
          ),
        ),
      );
    } else {
      if (response['statusCode'] == 404) {
        _showError(response['message']);
        if (verificationMethod == 'sms') {
          _isLoadingSms.value = false;
        } else {
          _isLoadingWhatsapp.value = false;
        }
        _canResendOtp.value = true;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
        return;
      }
      _showError(response['message'] ?? 'Failed to send OTP');
      if (verificationMethod == 'sms') {
        _isLoadingSms.value = false;
      } else {
        _isLoadingWhatsapp.value = false;
      }
      _canResendOtp.value = true;
    }
  }

  // ================= PHONE + PASSWORD LOGIN =================

  Future<void> _loginWithPhonePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(
        phone: digitsOnly(_phoneController.text),
        password: _passwordController.text,
      );

      if (result['success'] == false) {
        _showError(result['message'] ?? 'حدث خطأ أثناء تسجيل الدخول');
        return;
      }

      if (result['token'] == null || result['user'] == null) {
        _showError('استجابة غير صحيحة من السيرفر');
        return;
      }

      if (!_isPlayer(result['user'])) {
        _showError('هذا التطبيق خاص باللاعبين فقط');
        return;
      }

      final token = result['token'];

      await AuthService.saveAuthData(
        token: token,
        userId: result['user']['id'],
        name: result['user']['name'] ?? 'User',
        email: result['user']['email'] ?? '',
        role: result['user']['type'],
      );

      await AuthService.saveToken(token);

      final t = await SecureStorageService.getToken();
      debugPrint('LOGIN secure token saved? ${t != null && t.isNotEmpty}');

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
            (_) => false,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= RESET PASSWORD =================

  void _showResetPasswordBottomSheet() {
    final loc = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc?.tr('reset_password') ?? 'Reset Password',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: loc?.tr('phone_number') ?? 'Phone Number',
                      hintText: '01XXXXXXXXX',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.message_outlined),
                    label: Text(loc?.tr('reset_via_sms') ?? 'Reset via SMS'),
                    onPressed: _isLoading
                        ? null
                        : () {
                      Navigator.pop(context);
                      _sendResetOtp('sms');
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 18),
                    label: Text(loc?.tr('reset_via_whatsapp') ?? 'Reset via WhatsApp'),
                    onPressed: _isLoading
                        ? null
                        : () {
                      Navigator.pop(context);
                      _sendResetOtp('whatsapp');
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendResetOtp(String method) async {
    final loc = AppLocalizations.of(context);
    final phone = digitsOnly(_phoneController.text);

    if (phone.isEmpty || !RegExp(r'^(01)[0-9]{9}$').hasMatch(phone)) {
      _showError(loc?.tr('validation_phone_invalid') ?? 'Invalid phone number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.sendPasswordResetOtp(
        phone: phone,
        verificationMethod: method,
      );

      if (res is Map && res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? (loc?.tr('otp_sent') ?? 'OTP sent')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordOtpScreen(
              phoneNumber: phone,
              verificationMethod: method,
            ),
          ),
        );
      } else {
        _showError((res is Map ? res['message'] : null) ?? (loc?.tr('failed_to_send_otp') ?? 'Failed to send OTP'));
      }
    } catch (e) {
      _showError('${loc?.tr('failed_to_send_otp') ?? 'Failed to send OTP'}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 80),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/SQlast.png', height: 200),
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Image.asset('assets/images/solgan2-removebg-preview.png', height: 60),
                    ),
                  ],
                ),

                const SizedBox(height: 0),

                // Toggle button
                TextButton(
                  onPressed: _isLoading ? null : _toggleLoginMode,
                  child: Text(
                    _showPhonePasswordLogin
                        ? (loc?.tr('use_otp_instead') ?? 'Use OTP instead')
                        : (loc?.tr('use_password_instead') ?? 'Use Phone & Password instead'),
                  ),
                ),

                const SizedBox(height: 24),

                // ================= OTP MODE =================
                if (!_showPhonePasswordLogin) ...[
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: loc?.tr('phone_number') ?? 'Phone Number',
                      hintText: '01XXXXXXXXX',
                    ),
                    validator: (value) {
                      if (_showPhonePasswordLogin) return null; // skip in password mode
                      if (value == null || value.isEmpty) return loc?.tr('validation_phone_required');
                      if (!RegExp(r'^(01)[0-9]{9}$').hasMatch(digitsOnly(value))) {
                        return loc?.tr('validation_phone_invalid') ?? 'Invalid phone number';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _showOtpMethodBottomSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkAccentDark : AppColors.primary,
                        foregroundColor: isDark ? AppColors.black : Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(loc?.tr('send_otp') ?? 'Send OTP', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 16),
                ]

                // ================= PHONE + PASSWORD MODE =================
                else ...[
                  // ✅ PHONE field (was email before — now fixed)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: loc?.tr('phone_number') ?? 'Phone Number',
                      hintText: '01XXXXXXXXX',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (!_showPhonePasswordLogin) return null;
                      if (value == null || value.isEmpty) {
                        return loc?.tr('validation_phone_required') ?? 'Phone number required';
                      }
                      if (!RegExp(r'^(01)[0-9]{9}$').hasMatch(digitsOnly(value))) {
                        return loc?.tr('validation_phone_invalid') ?? 'Invalid phone number';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: loc?.tr('password') ?? 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (!_showPhonePasswordLogin) return null;
                      if (value == null || value.isEmpty) return loc?.tr('validation_password_required') ?? 'Password required';
                      if (value.length < 6) return loc?.tr('validation_password_short') ?? 'Too short';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _showResetPasswordBottomSheet,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(loc?.tr('forgot_password') ?? 'Forgot password?'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _loginWithPhonePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkAccentDark : AppColors.primary,
                        foregroundColor: isDark ? AppColors.black : Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(loc?.tr('login') ?? 'Login', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ================= REGISTER =================
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: isDark ? Colors.grey : Colors.black),
                    children: [
                      TextSpan(
                        text: AppLocalizations.of(context)?.tr('create_new_account') ?? 'Create New Account',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                          },
                      ),
                      TextSpan(
                        text: AppLocalizations.of(context)?.tr('no_account_yet') ?? "Don't have an account? ",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ================= SUPPORT =================
                TextButton.icon(
                  onPressed: _openWhatsApp,
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                  label: Text(
                    AppLocalizations.of(context)?.tr('contact_us_whatsapp') ?? 'Contact us via WhatsApp',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InReviewBottomSheet extends StatelessWidget {
  const InReviewBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 15, bottom: 15),
            height: 5,
            width: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).highlightColor,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SvgPicture.asset('assets/images/store_registration_success.svg', width: 130, height: 100),
              const SizedBox(height: 20),
              Text(loc!.tr('welcome_to_squad')),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(left: 30, right: 30),
                child: Text(
                  loc.tr('thanks_for_joining_us_your_registration_is_under_review_hang_tight_we_ll_notify_you_once_approved'),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: 100,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.tr('okay')),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ]),
    );
  }
}