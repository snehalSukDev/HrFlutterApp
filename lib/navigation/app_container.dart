import 'package:flutter/material.dart';

import '../services/frappe_api.dart';
import '../services/secure_storage.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../navigation/app_navigator.dart';
import '../widgets/glass/app_background.dart';

class AppContainer extends StatefulWidget {
  const AppContainer({super.key});

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer> {
  bool _loading = true;
  bool _showOnboarding = false;
  bool _authenticated = false;
  String? _currentUserEmail;
  String? _currentEmployeeId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final hasSeenOnboarding =
          await SecureStorage.getItem('hasSeenOnboarding');
      if (!mounted) {
        return;
      }
      if (hasSeenOnboarding == null) {
        setState(() {
          _showOnboarding = true;
          _loading = false;
        });
        return;
      }
      final storedBase = await SecureStorage.getItem('frappeBaseUrl');
      if (storedBase != null && storedBase.isNotEmpty) {
        FrappeApi.setBaseUrl(storedBase);
      }
      if (FrappeApi.baseUrl.isEmpty) {
        setState(() {
          _authenticated = false;
          _loading = false;
        });
        return;
      }

      // Restore session cookie if available
      final storedCookie = await SecureStorage.getItem('sessionCookie');
      if (storedCookie != null && storedCookie.isNotEmpty) {
        FrappeApi.setCookieHeader(storedCookie);
      }

      final userRes = await FrappeApi.getCurrentUser();
      final email = userRes['message']?.toString();
      if (email != null && email.isNotEmpty && email != 'Guest') {
        final employee =
            await FrappeApi.fetchEmployeeDetails(email, byEmail: true);
        if (!mounted) {
          return;
        }
        if (employee != null && employee['name'] != null) {
          setState(() {
            _currentUserEmail = email;
            _currentEmployeeId = employee['name']?.toString();
            _authenticated = true;
            _loading = false;
          });
        } else {
          setState(() {
            _authenticated = false;
            _loading = false;
          });
        }
      } else {
        setState(() {
          _authenticated = false;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authenticated = false;
        _loading = false;
      });
    }
  }

  Future<void> _handleOnboardingComplete() async {
    await SecureStorage.setItem('hasSeenOnboarding', 'true');
    if (!mounted) {
      return;
    }
    setState(() {
      _showOnboarding = false;
      _loading = true;
    });
    await _bootstrap();
  }

  Future<void> _handleLogout() async {
    try {
      await FrappeApi.logoutUser();
      await SecureStorage.removeItem('frappeBaseUrl');
      await SecureStorage.removeItem('currentUserEmail');
      await SecureStorage.removeItem('currentEmployeeId');
      await SecureStorage.removeItem('sessionCookie'); // Clear session
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _authenticated = false;
      _currentUserEmail = null;
      _currentEmployeeId = null;
    });
  }

  Future<void> _handleLoginSuccess(
    String baseUrl,
    String email,
  ) async {
    FrappeApi.setBaseUrl(baseUrl);
    await SecureStorage.setItem('frappeBaseUrl', baseUrl);
    await SecureStorage.setItem('currentUserEmail', email);

    // Save session cookie
    if (FrappeApi.cookieHeader != null) {
      await SecureStorage.setItem('sessionCookie', FrappeApi.cookieHeader!);
    }

    try {
      final employee =
          await FrappeApi.fetchEmployeeDetails(email, byEmail: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUserEmail = email;
        _currentEmployeeId =
            employee != null ? employee['name']?.toString() : null;
        _authenticated = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUserEmail = email;
        _authenticated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: _handleOnboardingComplete,
      );
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (!_authenticated) {
      return LoginScreen(
        onLoginSuccess: _handleLoginSuccess,
      );
    }
    return AppBackground(
      child: AppNavigator(
        currentUserEmail: _currentUserEmail,
        currentEmployeeId: _currentEmployeeId,
        onLogout: _handleLogout,
      ),
    );
  }
}
