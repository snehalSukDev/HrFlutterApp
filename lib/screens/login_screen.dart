import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/frappe_api.dart';
import '../services/secure_storage.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/glass_text_field.dart';
import '../widgets/glass/glass_button.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function(String baseUrl, String email) onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _siteController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;

  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _scale = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _controller.repeat(reverse: true);
    _loadInitialValues();
  }

  Future<void> _loadInitialValues() async {
    final savedBase = await SecureStorage.getItem('frappeBaseUrl');
    if (!mounted) {
      return;
    }
    if (savedBase != null && savedBase.isNotEmpty) {
      final uri = Uri.parse(savedBase);
      final host = uri.host;
      _siteController.text = host;
    }
    final savedEmail = await SecureStorage.getItem('currentUserEmail');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _emailController.text = savedEmail;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _siteController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _normalizeSite(String s) {
    return s
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/+$'), '')
        .trim();
  }

  Future<void> _showResetPasswordDialog() async {
    final site = _normalizeSite(_siteController.text);
    if (site.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter site first')),
      );
      return;
    }

    final email = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        final controller =
            TextEditingController(text: _emailController.text.trim());
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final email = controller.text.trim();
                    final emailOk = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(email);
                    if (email.isEmpty) {
                      setDialogState(() {
                        error = 'Email is required';
                      });
                      return;
                    }
                    if (!emailOk) {
                      setDialogState(() {
                        error = 'Enter a valid email address';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(email);
                  },
                  child: const Text('Send Link'),
                ),
              ],
            );
          },
        );
      },
    );

    if (email == null || email.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }

    final fullUrl = 'https://${_normalizeSite(site)}';
    FrappeApi.setBaseUrl(fullUrl);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: SizedBox(
            height: 56,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      },
    );

    try {
      final res = await FrappeApi.resetPassword(email);
      print('[ResetPassword] response: $res');
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      String? message;

      final rawMessage = res['message'];
      if (rawMessage is String) {
        message = rawMessage;
      } else if (rawMessage is Map<String, dynamic>) {
        message = rawMessage['message']?.toString();
      }
      message = message?.trim();
      print('[ResetPassword] success: ${message ?? 'Reset link sent'}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            (message != null && message.isNotEmpty)
                ? message
                : 'Reset link sent',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      final message = e.toString().replaceAll('Exception: ', '').trim();
      print('[ResetPassword] error: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(message.isNotEmpty ? message : 'Failed to send link'),
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    final site = _normalizeSite(_siteController.text);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (site.isEmpty || email.isEmpty || password.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
        ),
      );
      return;
    }
    if (email.toLowerCase() == 'administrator') {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only employee accounts can access'),
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final fullUrl = 'https://${_normalizeSite(site)}';
      FrappeApi.setBaseUrl(fullUrl);
      final res = await FrappeApi.loginUser(email, password);
      final message = res['message']?.toString() ?? '';
      if (message == 'Logged In') {
        await SecureStorage.setItem('frappeBaseUrl', fullUrl);
        await SecureStorage.setItem('currentUserEmail', email);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged in successfully'),
          ),
        );
        await widget.onLoginSuccess(fullUrl, email);
      } else {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid credentials'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // resizeToAvoidBottomInset: true, // Allow resize when keyboard appears
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scale.value,
                  child: Image.asset(
                    'assets/images/login/bg3.png',
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(
                  alpha: 0.5), // Increased darkness for better contrast
              child: BackdropFilter(
                filter:
                    ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Added global blur
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Image.asset(
                            'assets/images/techbirdicon.png',
                            height: 40,
                            width: 50,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Techbird HR',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.blue.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Login to Your Account',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 40),
                          GlassContainer(
                            opacity: 0.1,
                            blur: 15,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        height: double.infinity,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          'https://',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _siteController,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: const InputDecoration(
                                            hintText: 'yourdomain.com',
                                            hintStyle: TextStyle(
                                                color: Colors.white38),
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 16),
                                          ),
                                          keyboardType: TextInputType.url,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GlassTextField(
                                  controller: _emailController,
                                  hintText: 'Email or Username',
                                  prefixIcon: Icons.person_outline,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                GlassTextField(
                                  controller: _passwordController,
                                  hintText: 'Password',
                                  obscureText: !_showPassword,
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white60,
                                    ),
                                    onPressed: () => setState(
                                        () => _showPassword = !_showPassword),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                GlassButton(
                                  onPressed: _loading ? () {} : _handleLogin,
                                  label: _loading ? 'Logging in...' : 'Login',
                                  isPrimary: true,
                                  height: 56,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        _showResetPasswordDialog();
                                      },
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
