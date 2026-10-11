import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/secure_login_service.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/auth_surface.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../navigation/app_shell_route.dart';

class LoginScreen extends StatefulWidget {
  final bool isAdminLogin;

  const LoginScreen({
    super.key,
    this.isAdminLogin = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _hasSavedLogin = false;
  bool _biometricAvailable = false;
  bool _checkingSavedLogin = true;
  late final SecureLoginService _secureLogin;

  @override
  void initState() {
    super.initState();
    _secureLogin = SecureLoginService(
      storageKey:
          widget.isAdminLogin ? 'saved_admin_login' : 'saved_customer_login',
    );
    _loadSavedLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLogin() async {
    try {
      final hasSaved = await _secureLogin.hasSavedCredentials;
      final hasBiometrics = hasSaved && await _secureLogin.biometricAvailable;
      if (!mounted) return;
      setState(() {
        _hasSavedLogin = hasSaved;
        _biometricAvailable = hasBiometrics;
        _checkingSavedLogin = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingSavedLogin = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not check secure sign-in: $error')),
      );
    }
  }

  Future<void> _handleLogin({bool fromSavedLogin = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
      isAdminLogin: widget.isAdminLogin,
    );

    if (success && mounted) {
      final requiredRole = widget.isAdminLogin ? 'ADMIN' : null;
      if (requiredRole != null &&
          authProvider.currentUser?.role.toUpperCase() != requiredRole) {
        await authProvider.logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This account does not have access to this sign-in.'),
          ),
        );
        return;
      }

      if (!fromSavedLogin) await _offerToSavePassword();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => appShellForUser(authProvider.currentUser)),
      );
    } else if (mounted && authProvider.errorMessage != null) {
      if (fromSavedLogin) {
        await _forgetSavedLogin();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage!)),
      );
    }
  }

  Future<void> _offerToSavePassword() async {
    if (await _secureLogin.hasSavedCredentials ||
        await _secureLogin.savePromptDismissed ||
        !mounted) {
      return;
    }
    final biometricAvailable = await _secureLogin.biometricAvailable;
    if (!mounted) return;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save sign-in on this device?'),
        content: Text(
          biometricAvailable
              ? 'Your sign-in details will be stored in this device’s secure keychain. '
                  'You can use biometrics the next time you sign in.'
              : 'Your sign-in details will be stored securely on this device for quicker sign-in next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save securely'),
          ),
        ],
      ),
    );
    if (shouldSave != true) {
      try {
        await _secureLogin.dismissSavePrompt();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remember this choice: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    try {
      await _secureLogin.save(
        _emailController.text.trim(),
        _passwordController.text,
      );
      await _loadSavedLogin();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save sign-in securely: $error')),
      );
    }
  }

  Future<void> _signInWithBiometrics() async {
    try {
      if (!await _secureLogin.authenticate()) return;
      await _signInWithSavedPassword();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Secure sign-in failed: $error')),
      );
    }
  }

  Future<void> _signInWithSavedPassword() async {
    try {
      final credentials = await _secureLogin.read();
      if (credentials == null) {
        throw StateError('Saved sign-in details are no longer available.');
      }
      _emailController.text = credentials.username;
      _passwordController.text = credentials.password;
      if (mounted) await _handleLogin(fromSavedLogin: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved sign-in failed: $error')),
      );
    }
  }

  Future<void> _forgetSavedLogin() async {
    try {
      await _secureLogin.clear();
      if (!mounted) return;
      setState(() {
        _hasSavedLogin = false;
        _biometricAvailable = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove saved sign-in: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: AuthSurface(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.eco,
                      color: AppConstants.primary, size: 30),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isAdminLogin ? 'Admin sign in' : 'Welcome Back',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdminLogin
                      ? 'Sign in with your store administrator account.'
                      : 'Log in to order everyday essentials and groceries from Ram Prasad General Store.',
                  style: const TextStyle(
                    color: AppConstants.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: widget.isAdminLogin
                      ? TextInputType.text
                      : TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: widget.isAdminLogin
                        ? 'Admin username or email'
                        : 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return widget.isAdminLogin
                          ? 'Please enter admin username'
                          : 'Please enter email';
                    }
                    if (!widget.isAdminLogin && !val.contains('@')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter password';
                    }
                    if (val.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Forgot Password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen()),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                          color: AppConstants.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                CustomButton(
                  text: 'Log In',
                  isLoading: authProvider.isLoading,
                  onPressed: _handleLogin,
                ),
                if (!widget.isAdminLogin) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text('Create account'),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'STORE STAFF',
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(isAdminLogin: true),
                        ),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Admin login'),
                    ),
                  ),
                ],
                if (!_checkingSavedLogin && _hasSavedLogin) ...[
                  if (_biometricAvailable) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          authProvider.isLoading ? null : _signInWithBiometrics,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Sign in with biometrics'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                  if (!_biometricAvailable)
                    OutlinedButton.icon(
                      onPressed: authProvider.isLoading
                          ? null
                          : _signInWithSavedPassword,
                      icon: const Icon(Icons.key_outlined),
                      label: const Text('Continue with saved sign-in'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  TextButton(
                    onPressed: _forgetSavedLogin,
                    child: const Text('Forget saved sign-in'),
                  ),
                ],
                if (widget.isAdminLogin) const SizedBox(height: 16),

                if (widget.isAdminLogin)
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      ),
                      child: const Text('Back to customer sign in'),
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
