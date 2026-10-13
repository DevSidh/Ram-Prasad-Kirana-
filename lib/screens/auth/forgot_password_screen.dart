import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _codeRequested = false;
  bool _complete = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<ApiService>().post('/auth/password-reset/request', {
        'email': _emailController.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _loading = false;
        _codeRequested = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<ApiService>().post('/auth/password-reset/confirm', {
        'email': _emailController.text.trim(),
        'code': _codeController.text.trim(),
        'password': _passwordController.text,
      });
      if (!mounted) return;
      setState(() {
        _loading = false;
        _complete = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _complete
                  ? _ResetComplete(onContinue: () => Navigator.pop(context))
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _codeRequested
                                ? 'Choose a new password'
                                : 'Reset your password',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _codeRequested
                                ? 'Enter the six-digit code sent to your email. The code expires in 10 minutes.'
                                : 'We’ll email a one-time verification code to your registered address.',
                            style: TextStyle(
                              color: AppConstants.textMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            enabled: !_codeRequested,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (!email.contains('@') ||
                                  !email.contains('.')) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          if (_codeRequested) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Six-digit code',
                                prefixIcon: Icon(Icons.verified_user_outlined),
                              ),
                              validator: (value) => RegExp(r'^\d{6}$')
                                      .hasMatch(value?.trim() ?? '')
                                  ? null
                                  : 'Enter the six-digit code',
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'New password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                ),
                              ),
                              validator: (value) => (value?.length ?? 0) >= 8
                                  ? null
                                  : 'Use at least 8 characters',
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm new password',
                                prefixIcon: Icon(Icons.lock_reset_outlined),
                              ),
                              validator: (value) =>
                                  value == _passwordController.text
                                      ? null
                                      : 'Passwords do not match',
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => setState(() {
                                          _codeRequested = false;
                                          _error = null;
                                        }),
                                child: const Text('Use a different email'),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFB42318),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          CustomButton(
                            text: _codeRequested
                                ? 'Change password'
                                : 'Send verification code',
                            isLoading: _loading,
                            onPressed:
                                _codeRequested ? _resetPassword : _requestCode,
                          ),
                          if (_codeRequested)
                            Center(
                              child: TextButton(
                                onPressed: _loading ? null : _requestCode,
                                child: const Text('Send a new code'),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetComplete extends StatelessWidget {
  final VoidCallback onContinue;

  const _ResetComplete({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline,
            color: AppConstants.primary, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Password changed',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Your new password is ready. Sign in with it to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppConstants.textMuted),
        ),
        const SizedBox(height: 24),
        CustomButton(text: 'Back to sign in', onPressed: onContinue),
      ],
    );
  }
}
