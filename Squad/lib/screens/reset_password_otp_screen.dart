import 'package:flutter/material.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/utils/app_localizations.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
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

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.verifyPasswordResetOtpAndSetPassword(
        phone: widget.phoneNumber,
        otp: _otpController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      if (res['success'] == true) {
        _showSuccess(res['message'] ?? (loc?.tr('password_updated') ?? 'Password updated'));
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        _showError(res['message'] ?? (loc?.tr('invalid_otp') ?? 'Invalid OTP'));
      }
    } catch (e) {
      _showError('${loc?.tr('reset_failed') ?? 'Reset failed'}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.tr('reset_password') ?? 'Reset Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text('${loc?.tr('phone_number') ?? 'Phone'}: ${widget.phoneNumber}'),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: loc?.tr('otp') ?? 'OTP'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return loc?.tr('validation_required') ?? 'Required';
                    if (v.trim().length < 4) return loc?.tr('validation_otp_short') ?? 'OTP too short';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: loc?.tr('new_password') ?? 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return loc?.tr('validation_password_required') ?? 'Password required';
                    if (v.length < 6) return loc?.tr('validation_password_short') ?? 'Too short';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(loc?.tr('confirm') ?? 'Confirm'),
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
