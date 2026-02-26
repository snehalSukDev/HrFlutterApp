import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/shift_details_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/leaves_screen.dart';
import '../screens/salary_slip_screen.dart';
import '../screens/expense_claim_screen.dart';
import '../screens/approval_screen.dart';
import '../services/frappe_api.dart';

class AppNavigator extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;

  const AppNavigator({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
  });

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  int _index = 0;
  String? _employeeName;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String? get _userInitials {
    final name = _employeeName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      if (parts.isNotEmpty) {
        return parts.first.substring(0, 1).toUpperCase();
      }
    }
    final email = widget.currentUserEmail?.trim();
    if (email == null || email.isEmpty) {
      return null;
    }
    return email.substring(0, 1).toUpperCase();
  }

  Future<void> _loadProfile() async {
    final email = widget.currentUserEmail?.trim();
    if (email == null || email.isEmpty) {
      return;
    }
    try {
      final dynamic profile = await FrappeApi.fetchEmployeeDetails(
        email,
        byEmail: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _employeeName =
            (profile is Map<String, dynamic> ? profile['employee_name'] : null)
                ?.toString();
      });
    } catch (_) {}
  }

  void _openMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                const Text(
                  'More Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MoreOptionCard(
                        icon: Icons.checklist_rtl,
                        label: 'Approvals',
                        color: const Color(0xFF2563EB),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ApprovalScreen(
                                currentUserEmail: widget.currentUserEmail,
                                currentEmployeeId: widget.currentEmployeeId,
                                onLogout: widget.onLogout,
                                userInitials: _userInitials,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MoreOptionCard(
                        icon: Icons.attach_money,
                        label: 'Expenses',
                        color: const Color(0xFFFBBF24),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExpenseClaimScreen(
                                currentUserEmail: widget.currentUserEmail,
                                currentEmployeeId: widget.currentEmployeeId,
                                onLogout: widget.onLogout,
                                userInitials: _userInitials,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        currentUserEmail: widget.currentUserEmail,
        currentEmployeeId: widget.currentEmployeeId,
        onLogout: widget.onLogout,
        onTabChange: (value) {
          if (value == 5) {
            _openMoreSheet();
          } else {
            setState(() {
              _index = value;
            });
          }
        },
      ),
      ShiftDetailsScreen(
        currentUserEmail: widget.currentUserEmail,
        currentEmployeeId: widget.currentEmployeeId,
        onLogout: widget.onLogout,
        userInitials: _userInitials,
      ),
      AttendanceScreen(
        currentUserEmail: widget.currentUserEmail,
        currentEmployeeId: widget.currentEmployeeId,
        onLogout: widget.onLogout,
        userInitials: _userInitials,
      ),
      LeavesScreen(
        currentUserEmail: widget.currentUserEmail,
        currentEmployeeId: widget.currentEmployeeId,
        onLogout: widget.onLogout,
        userInitials: _userInitials,
      ),
      SalarySlipScreen(
        currentUserEmail: widget.currentUserEmail,
        currentEmployeeId: widget.currentEmployeeId,
        onLogout: widget.onLogout,
        userInitials: _userInitials,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        onTap: (value) {
          if (value == 5) {
            _openMoreSheet();
          } else {
            setState(() {
              _index = value;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.layers_outlined),
            label: 'Shift',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Leave',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Salary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _MoreOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MoreOptionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF111827)
              : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
