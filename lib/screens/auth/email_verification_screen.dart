import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigation/app_shell_route.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_surface.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, this.email = ''});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _sendingCode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
    if (widget.email.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sendCode();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      _formKey.currentState!.validate();
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().requestEmailVerification(email);
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _codeSent = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final verified = await auth.verifyEmail(
      _emailController.text.trim(),
      _codeController.text.trim(),
    );
    if (!mounted) return;
    if (!verified) {
      setState(() => _error = auth.errorMessage);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => appShellForUser(auth.currentUser)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: AuthSurface(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One last step',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'Enter the six-digit code we sent to your email. It expires in 10 minutes.'
                      : 'We’ll send a six-digit code to your email address. You can request another if it expires.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _emailController,
                  enabled: !_sendingCode && !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return email.contains('@') && email.contains('.')
                        ? null
                        : 'Enter a valid email address';
                  },
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Six-digit code',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                    validator: (value) =>
                        RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Enter the six-digit code',
                    onFieldSubmitted: (_) => _verify(),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _sendingCode || auth.isLoading
                        ? null
                        : _codeSent
                            ? _verify
                            : _sendCode,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _sendingCode
                            ? 'Sending code…'
                            : auth.isLoading
                                ? 'Verifying…'
                                : _codeSent
                                    ? 'Verify email'
                                    : 'Send verification code',
                      ),
                    ),
                  ),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed:
                          _sendingCode || auth.isLoading ? null : _sendCode,
                      child: const Text('Send a new code'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
