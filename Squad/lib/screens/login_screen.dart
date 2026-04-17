import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:squad/screens/reset_password_otp_screen.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/screens/register_screen.dart';
import 'package:squad/screens/main_screen.dart';
import 'package:squad/screens/otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Email login (optional)
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // OTP login

  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showEmailLogin = false;
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

  void _showResetPasswordBottomSheet() {
    final loc = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🔑 REQUIRED
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        return Padding(
          // 🔑 Push content above keyboard
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc?.tr('reset_password') ?? 'Reset Password',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      autofocus: true, // 👈 optional but nice UX
                      decoration: InputDecoration(
                        labelText:
                        loc?.tr('phone_number') ?? 'Phone Number',
                        hintText: 'أدخل رقم التليفون',
                      ),
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.message_outlined),
                      label:
                      Text(loc?.tr('reset_via_sms') ?? 'Reset via SMS'),
                      onPressed: _isLoading
                          ? null
                          : () {
                        Navigator.pop(context);
                        _sendResetOtp('sms');
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),

                    const SizedBox(height: 8),

                    ElevatedButton.icon(
                      icon: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: Colors.green,
                        size: 18,
                      ),
                      label: Text(
                        loc?.tr('reset_via_whatsapp') ??
                            'Reset via WhatsApp',
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                        Navigator.pop(context);
                        _sendResetOtp('whatsapp');
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
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
      // ✅ You must implement this in ApiService + backend
      final res = await ApiService.sendPasswordResetOtp(
        phone: phone,
        verificationMethod: method, // 'sms' or 'whatsapp'
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
        _showError(
          (res is Map ? res['message'] : null) ??
              (loc?.tr('failed_to_send_otp') ?? 'Failed to send OTP'),
        );
      }
    } catch (e) {
      _showError('${loc?.tr('failed_to_send_otp') ?? 'Failed to send OTP'}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3),
        margin: EdgeInsets.only(
          top: 20,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  Future<void> _blockPlayerAndGoRegister() async {
    _showError("هذا التطبيق عير مخصص للاعبين");

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RegisterScreen()), (_) => false);
  }

  // ✅ your app roles: allow only guest/scout
  bool _isAllowedRole(dynamic user) {
    final role = (user?['type'] ?? '').toString().toLowerCase().trim();
    return role == 'guest' || role == 'scout';
  }

  // ================= WhatsApp support =================
  Future<void> _openWhatsApp() async {
    const phoneNumber = '201003100623';
    const message = 'أهلا مستخدم إسكواد';
    final encodedMessage = Uri.encodeComponent(message);

    final Uri appUrl = Uri.parse('whatsapp://send?phone=$phoneNumber&text=$encodedMessage');
    final Uri webUrl = Uri.parse('https://wa.me/$phoneNumber?text=$encodedMessage');

    try {
      final openedApp = await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      if (!openedApp) {
        final openedWeb = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        if (!openedWeb) _showError('Cannot open WhatsApp');
      }
    } catch (_) {
      try {
        final openedWeb = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        if (!openedWeb) _showError('Cannot open WhatsApp');
      } catch (_) {
        _showError('Cannot open WhatsApp');
      }
    }
  }

  String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _toggleLoginMode() async {
    FocusScope.of(context).unfocus(); // ✅ close current keyboard

    await Future.delayed(const Duration(milliseconds: 100)); // optional but safer
    setState(() {
      _showEmailLogin = !_showEmailLogin;
      _otpController.clear();
    });
  }

  // ================= Email fallback (optional) =================
  Future<void> _loginWithPhone() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = digitsOnly(_phoneController.text);
    final password = _passwordController.text;

    try {
      setState(() => _isLoading = true);

      final result = await ApiService.login(
        phone: phone,
        password: password,
      );

      // ✅ Validate response type
      if (result is! Map) {
        _showError('Unexpected response from server');
        return;
      }

      // ✅ Handle API failure
      // ✅ consider login successful if token exists
      if (result['token'] == null) {
        _showError(result['message'] ?? 'Login failed');
        return;
      }

      // ✅ Validate required fields
      final token = result['token'];
      final user = result['user'];

      if (token == null || user == null) {
        _showError('Invalid server response');
        return;
      }

      final role = (user['type'] ?? '').toString().toLowerCase().trim();

      // ❌ Block player
      if (role == 'player') {
        await _blockPlayerAndGoRegister();
        return;
      }

      // ❌ Block other roles
      if (!_isAllowedRole(user)) {
        _showError('هذا التطبيق خاص بالكشافين/المشاهدين فقط');
        return;
      }

      // ✅ Save auth
      await AuthService.saveAuthData(
        token: token,
        userId: user['id'] ?? 0,
        name: user['name'] ?? 'User',
        email: user['email'] ?? '',
        role: role,
      );

      if (!mounted) return;

      // ✅ Navigate
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
            (_) => false,
      );
    } catch (e, st) {
      debugPrint('❌ Login crashed: $e');
      debugPrint('$st');

      _showError('Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  // ================= SMS Button =================
                  // ================= SMS Button (Icon AFTER text in Arabic) =================
                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoadingSms,
                    builder: (context, isLoadingSms, child) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _canResendOtp,
                        builder: (context, canResend, child) {
                          return ElevatedButton(
                            onPressed: canResend ? () => _sendOtp('sms') : null,
                            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                              minimumSize: WidgetStateProperty.all(
                                const Size(double.infinity, 48),
                              ),
                            ),
                            child: isLoadingSms
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),

                                // 🔤 TEXT FIRST
                                Text(
                                  loc?.tr('resending_via_sms') ?? 'Resending via SMS',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // 🔔 ICON AFTER TEXT
                                const Icon(Icons.message_outlined, size: 20),
                              ],
                            )
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🔤 TEXT FIRST
                                Text(
                                  loc?.tr('receive_otp_via_sms') ?? 'Receive OTP via SMS',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // 🔔 ICON AFTER TEXT
                                const Icon(Icons.message_outlined, size: 20),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

// ================= WhatsApp Button (Icon AFTER text in Arabic) =================
                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoadingWhatsapp,
                    builder: (context, isLoadingWhatsapp, child) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _canResendOtp,
                        builder: (context, canResend, child) {
                          return ElevatedButton(
                            onPressed: canResend ? () => _sendOtp('whatsapp') : null,
                            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                              minimumSize: WidgetStateProperty.all(
                                const Size(double.infinity, 48),
                              ),
                            ),
                            child: isLoadingWhatsapp
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              textDirection: TextDirection.rtl, // Arabic: icon after text
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc?.tr('resending_via_whatsapp') ??
                                      'Resending via WhatsApp',
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 8),
                                const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ],
                            )
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              textDirection: TextDirection.rtl, // Arabic: icon after text
                              children: [
                                Text(
                                  loc?.tr('receive_otp_via_whatsapp') ??
                                      'Receive OTP via WhatsApp',
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 8),
                                const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  color: Colors.green,
                                  size: 20,
                                ),
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

  Future<void> _onForgotPasswordPressed() async {
    final loc = AppLocalizations.of(context);
    final phone = digitsOnly(_phoneController.text);

    // ✅ Validate phone
    if (phone.isEmpty || !RegExp(r'^(01)[0-9]{9}$').hasMatch(phone)) {
      _showError(loc?.tr('validation_phone_invalid') ?? 'Enter a valid phone number');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final res = await ApiService.forgotPassword(phone: phone);

      if (res is Map && res['success'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message'] ?? (loc?.tr('reset_link_sent') ?? 'Reset instructions sent'),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError(
          (res is Map ? res['message'] : null) ??
              (loc?.tr('reset_failed') ?? 'Reset failed'),
        );
      }
    } catch (e) {
      _showError(
        '${loc?.tr('reset_failed') ?? 'Reset failed'}: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp(String verificationMethod) async {
    _canResendOtp.value = false;
    if (verificationMethod == 'sms') {
      _isLoadingSms.value = true;
    } else {
      _isLoadingWhatsapp.value = true;
    }

    final Map<String, dynamic> response = await ApiService.sendOtp(phone: digitsOnly(_phoneController.text), verificationMethod: verificationMethod);


    // add a timer of 60 seconds and disable the verify through button during that time
    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          margin: EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
          ),
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
          timer.cancel();
        }
      });
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phoneNumber: digitsOnly(_phoneController.text), verificationMethod: verificationMethod),
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
        _canResendOtp.value =true;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
        return;
      }
      _showError(response['message'] ?? 'Failed to send OTP');
      if (verificationMethod == 'sms') {
        _isLoadingSms.value = false;
      } else {
        _isLoadingWhatsapp.value = false;
      }
      _canResendOtp.value =true;
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                Center(
                  child: SizedBox(
                    height: 220, // controls full logo+slogan block
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Image.asset(
                          'assets/images/SQlast.png',
                          width: 200,
                          height: 200,
                        ),

                        Positioned(
                          bottom: 0, // 🔥 controls distance
                          child: Image.asset(
                            'assets/images/Solgan.png',
                            width: 200,
                            height: 60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, // 🔥 removes extra vertical space
                      minimumSize: Size.zero,   // 🔥 removes default height
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _isLoading ? null : _toggleLoginMode,
                    child: Text(
                      _showEmailLogin
                          ? (loc?.tr('use_otp_instead') ?? 'Use OTP instead')
                          : (loc?.tr('use_email_password_instead') ?? 'Use Email & Password instead'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),


                const SizedBox(height: 15),



                // ================= OTP UI =================
                if (!_showEmailLogin) ...[
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number, // ✅ better than phone
                    textDirection: TextDirection.ltr,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // ✅ only 0-9
                    ],
                    decoration: InputDecoration(
                      hintText: 'أدخل رقم التليفون',
                    ),

                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc?.tr('validation_phone_required');
                      }
                      if (!RegExp(r'^(01)[0-9]{9}$').hasMatch(value)) {
                        return loc?.tr('validation_phone_invalid') ?? 'Invalid phone number';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _showOtpMethodBottomSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkModeAccent : AppColors.primary,
                        foregroundColor: isDark ? AppColors.black : Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text((loc?.tr('send_otp') ?? 'Send OTP'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 30),
                ] else ...[
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'أدخل رقم التليفون'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Phone required';
                      if (!RegExp(r'^(01)[0-9]{9}$').hasMatch(value)) {
                        return 'رقم تليفون خطا';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: loc?.tr('password') ?? 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (!_showEmailLogin) return null;
                      if (value == null || value.isEmpty) return loc?.tr('validation_password_required') ?? 'Password required';
                      if (value.length < 6) return loc?.tr('validation_password_short') ?? 'Too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 5),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _showResetPasswordBottomSheet,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(loc?.tr('forgot_password') ?? 'Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _isLoading ? null : _loginWithPhone, child: Text(loc?.tr('login') ?? 'Login')),
                ],

                const SizedBox(height: 24),

                // Register Link
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(color: isDark ? Colors.grey[400] : AppColors.textSecondary, fontSize: 14),
                      children: [
                        TextSpan(
                          text: loc?.tr('create_new_account') ?? 'Create New Account',
                          style: TextStyle(color: isDark ? AppColors.darkModeAccent : AppColors.primary, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                            },
                        ),
                        TextSpan(text: '${loc?.tr('no_account_yet') ?? "Don't have an account yet?"}   '),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Support WhatsApp
                Center(
                  child: TextButton.icon(
                    onPressed: _openWhatsApp,
                    label: Text(loc?.tr('contact_us_whatsapp') ?? 'Contact us via WhatsApp'),
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
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
