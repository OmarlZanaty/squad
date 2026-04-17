import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';

import 'package:squad/utils/app_colors.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/screens/main_screen.dart';

import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:smart_auth/smart_auth.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationMethod;

  const OtpVerificationScreen({super.key, required this.phoneNumber, required this.verificationMethod});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _canResend = false;
  Timer? _resendTimer;
  int _resendCountdown = 60;
  final ValueNotifier<bool> _canResendOtp = ValueNotifier(true);
  final ValueNotifier<bool> _isLoadingWhatsapp = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingSms = ValueNotifier(false);
  final ValueNotifier<int> _remainingSeconds = ValueNotifier(0);
  final _smartAuth = SmartAuth.instance;
  final double _borderWidth = 0.7;

  @override
  void initState() {
    super.initState();
    _userConsent();
    _canResend = false;
    _resendCountdown = 60;
    _startResendTimer(widget.verificationMethod);
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    _isLoadingSms.dispose();
    _isLoadingWhatsapp.dispose();
    _canResendOtp.dispose();
    _remainingSeconds.dispose();
    _smartAuth.removeUserConsentApiListener();
    super.dispose();
  }

  Future<void> _userConsent() async {
    final res = await _smartAuth.getSmsWithUserConsentApi();
    if (res.hasData) {
      final code = res.requireData.code;
      if (code == null) return;
      _otpController.text = code;
    }
  }

  void _startResendTimer(String verificationMethod) {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds.value = _resendCountdown;
      _canResendOtp.value = false;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        _canResendOtp.value = true;
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)));
  }

  Future<void> _resendOtp(String verificationMethod) async {
    final loc = AppLocalizations.of(context);
    setState(() => _canResend = false);
    _resendCountdown = 60;
    _startResendTimer(verificationMethod);
    if (verificationMethod == 'sms') {
      _isLoadingSms.value = true;
    } else {
      _isLoadingWhatsapp.value = true;
    }
    try {
      final result = await ApiService.sendOtp(phone: widget.phoneNumber, verificationMethod: verificationMethod);

      if (result['success'] == true) {
        _showSuccess(loc?.tr('otp_resent_successfully') ?? 'OTP resent successfully');
        Navigator.of(context).pop();
      } else {
        _showError(result['message'] ?? (loc?.tr('failed_to_resend_otp') ?? 'Failed to resend OTP'));
      }
    } catch (e) {
      _showError(loc?.tr('failed_to_resend_otp') ?? 'Failed to resend OTP');
    } finally {
      if (verificationMethod == 'sms') {
        _isLoadingSms.value = false;
      } else {
        _isLoadingWhatsapp.value = false;
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    final loc = AppLocalizations.of(context);
    if (otp.isEmpty) {
      _showError(loc?.tr('please_enter_otp') ?? 'Please enter OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.verifyOtp(phone: widget.phoneNumber, otp: otp);

      if (result['success'] == false) {
        _showError(result['message'] ?? (loc?.tr('verification_failed') ?? 'Verification failed'));
        return;
      }

      if (result['token'] == null || result['user'] == null) {
        _showError(loc?.tr('invalid_response_from_server') ?? 'Invalid response from server');
        return;
      }

      final role = (result['user']?['type'] ?? '').toString().toLowerCase().trim();

      if (role == 'player') {
        _showError(loc?.tr('app_not_for_players') ?? 'This app is not for players');
        return;
      }

      if (role != 'guest' && role != 'scout') {
        _showError(loc?.tr('app_for_scouts_only') ?? 'This app is for scouts/viewers only');
        return;
      }

      await AuthService.saveAuthData(
        token: result['token'] ?? '',
        userId: result['user']['id'] ?? 0,
        name: result['user']['name'] ?? 'User',
        email: result['user']['email'] ?? '',
        role: role,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScreen()), (_) => false);
    } catch (e, st) {
      debugPrint('❌ Verification crashed: $e');
      debugPrint('$st');
      _showError('${loc?.tr('verification_error') ?? 'Verification error'}: $e');
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
                            onPressed: canResend ? () => _resendOtp('sms') : null,
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
                            onPressed: canResend ? () => _resendOtp('whatsapp') : null,
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(loc?.tr('otp_verification') ?? 'OTP Verification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text('${loc?.tr('enter_otp') ?? 'Enter the OTP sent to'} ${widget.phoneNumber}', style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Directionality(
                textDirection: TextDirection.ltr,
                child: PinCodeTextField(
                  length:  6,
                  enablePinAutofill: true,
                  controller: _otpController,
                  appContext: context,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.slide,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    fieldHeight: 60,
                    fieldWidth: 50,
                    borderWidth: _borderWidth,
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Theme.of(context).primaryColor,
                    selectedFillColor: Colors.white,
                    inactiveFillColor: Theme.of(context).cardColor,
                    inactiveColor: Theme.of(context).disabledColor.withAlpha((0.6 * 256).toInt()),
                    activeColor: Theme.of(context).disabledColor,
                    activeFillColor: Theme.of(context).cardColor,
                    inactiveBorderWidth: _borderWidth,
                    selectedBorderWidth: _borderWidth,
                    disabledBorderWidth: _borderWidth,
                    errorBorderWidth: _borderWidth,
                    activeBorderWidth: _borderWidth,
                  ),
                  animationDuration: const Duration(milliseconds: 300),
                  backgroundColor: Colors.transparent,
                  enableActiveFill: true,
                  beforeTextPaste: (text) => true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkModeAccent : AppColors.primary,
                    foregroundColor: isDark ? AppColors.black : Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text((loc?.tr('verify_otp') ?? 'Verify OTP'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _canResend ? _showOtpMethodBottomSheet : null,
                child: Text(
                  _canResend ? (loc?.tr('resend_otp') ?? 'Resend OTP') : (loc?.tr('resend_in') ?? 'Resend OTP').replaceAll('{count}', '$_resendCountdown'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
