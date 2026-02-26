import 'package:flutter/material.dart';

import '../services/frappe_api.dart';
import '../services/secure_storage.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
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
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Techbird HR',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF3B82F6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Login to Your Account',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2933),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  height: double.infinity,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF374151),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'https://',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _siteController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'yourdomain.com',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    ),
                                    keyboardType: TextInputType.url,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _emailController,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Email or Username',
                              hintStyle: const TextStyle(
                                color: Color(0xFF9CA3AF),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1F2933),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: const TextStyle(
                                color: Color(0xFF9CA3AF),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1F2933),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFF9CA3AF),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: !_showPassword,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                              ),
                              onPressed: _loading ? null : _handleLogin,
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
