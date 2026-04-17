import 'package:flutter/material.dart';
import 'package:squad_player/utils/app_colors.dart';
import 'package:squad_player/utils/app_localizations.dart';
import 'package:squad_player/services/api_service.dart';

class ResetPasswordOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationMethod;

  const ResetPasswordOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationMethod,
  });

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _otpController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    debugPrint('RESET OTP SCREEN phoneNumber = "${widget.phoneNumber}"');
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    final otp = _otpController.text.trim();
    final p1 = _newPassController.text;
    final p2 = _confirmPassController.text;

    if (otp.length < 4) {
      _showError(loc?.tr('enter_valid_otp') ?? 'Enter a valid OTP');
      return;
    }
    if (p1.length < 6) {
      _showError(loc?.tr('password_too_short') ?? 'Password is too short');
      return;
    }
    if (p1 != p2) {
      _showError(loc?.tr('passwords_do_not_match') ?? 'Passwords do not match');
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await ApiService.resetPasswordWithOtp(
        phone: widget.phoneNumber,
        otp: otp,
        newPassword: p1,
      );

      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? (loc?.tr('password_reset_success') ?? 'Password reset successfully')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // back to login
      } else {
        _showError(res['message'] ?? (loc?.tr('reset_failed') ?? 'Reset failed'));
      }
    } catch (e) {
      _showError('${loc?.tr('reset_failed') ?? 'Reset failed'}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final phone = widget.phoneNumber.trim().isEmpty ? '---' : widget.phoneNumber.trim();
    final phoneLtr = '\u200E$phone\u200E'; // ✅ force LTR inside Arabic

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.tr('reset_password') ?? 'Reset Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height
                  - kToolbarHeight
                  - MediaQuery.of(context).padding.top
                  - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${loc?.tr('otp_sent_to') ?? 'أدخل كود التحقق المرسل إلى '} $phoneLtr',
                    textDirection: TextDirection.rtl,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: loc?.tr('otp_code') ?? 'OTP Code',
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _newPassController,
                    obscureText: _obscure1,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: loc?.tr('new_password') ?? 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure1 = !_obscure1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _confirmPassController,
                    obscureText: _obscure2,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: loc?.tr('confirm_password') ?? 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure2 = !_obscure2),
                      ),
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Text(loc?.tr('confirm') ?? 'Confirm'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


}
