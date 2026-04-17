import 'package:flutter/material.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/utils/app_localizations.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _pass1.dispose();
    _pass2.dispose();
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

    setState(() => _loading = true);
    try {
      final res = await ApiService.resetPassword(
        token: widget.token,
        newPassword: _pass1.text,
      );

      if (res is Map && res['success'] == true) {
        _showSuccess(res['message'] ?? (loc?.tr('password_reset_success') ?? 'Password updated'));
        if (!mounted) return;
        Navigator.pop(context); // back to login
      } else {
        _showError((res is Map ? res['message'] : null) ?? (loc?.tr('reset_failed') ?? 'Reset failed'));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.tr('reset_password') ?? 'Reset password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  loc?.tr('enter_new_password') ?? 'Enter your new password',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _pass1,
                  obscureText: _obscure1,
                  decoration: InputDecoration(
                    labelText: loc?.tr('new_password') ?? 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return loc?.tr('validation_password_required') ?? 'Password required';
                    if (v.length < 6) return loc?.tr('validation_password_short') ?? 'Too short';
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _pass2,
                  obscureText: _obscure2,
                  decoration: InputDecoration(
                    labelText: loc?.tr('confirm_password') ?? 'Confirm password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return loc?.tr('validation_password_required') ?? 'Password required';
                    if (v != _pass1.text) return loc?.tr('passwords_not_match') ?? 'Passwords do not match';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(loc?.tr('save') ?? 'Save'),
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