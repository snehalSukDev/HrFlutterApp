import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;
  final String? userInitials;

  const ProfileScreen({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
    this.userInitials,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _employeeProfile;
  bool _loading = true;
  bool _refreshing = false;
  bool _aboutOpen = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (widget.currentUserEmail == null ||
        widget.currentUserEmail!.trim().isEmpty) {
      setState(() {
        _loading = false;
      });
      return;
    }
    if (!forceRefresh) {
      setState(() {
        _loading = true;
      });
    }
    try {
      final profile = await FrappeApi.fetchEmployeeDetails(
        widget.currentUserEmail!.trim(),
        byEmail: true,
      );
      if (mounted) {
        setState(() {
          _employeeProfile = profile;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'N/A';
    }
    try {
      final d = DateTime.parse(value.split(' ').first);
      return DateFormat('EEE MMM dd yyyy').format(d);
    } catch (_) {
      return value;
    }
  }

  String? _getUserInitials() {
    // Try to get initials from profile first
    final profile = _employeeProfile;
    final name = profile?['employee_name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      if (parts.isNotEmpty) {
        return parts.first.substring(0, 1).toUpperCase();
      }
    }

    // Fallback to email if profile not loaded or no name
    final email = widget.currentUserEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    return 'U'; // Ultimate fallback
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = _employeeProfile;

    return Scaffold(
      appBar: MainAppBar(
        title: 'Profile',
        onLogout: widget.onLogout,
        userInitials: widget.userInitials ?? _getUserInitials(),
        currentUserEmail: widget.currentUserEmail,
        currentEmployeeId: widget.currentEmployeeId,
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: () {
          setState(() {
            _refreshing = true;
          });
          return _loadProfile(forceRefresh: true);
        },
        child: _loading && !_refreshing
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              )
            : profile == null
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Center(
                        child: Text('No profile data'),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? const Color.fromARGB(255, 43, 26, 26)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          // border: Border.all(
                          //   color: colors.outline.withValues(alpha: 0.4),
                          // ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color.fromARGB(255, 43, 26, 26)
                                  : colors.primary.withValues(alpha: 0.1),
                              child: Text(
                                (profile['employee_name'] ?? 'U')
                                    .toString()
                                    .trim()
                                    .split(' ')
                                    .where((p) => p.isNotEmpty)
                                    .map((p) => p[0])
                                    .take(2)
                                    .join()
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile['employee_name']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile['designation']?.toString() ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profile['name']?.toString() ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _DetailTile(
                            label: 'Email',
                            value: profile['user_id']?.toString() ?? 'N/A',
                            icon: Icons.mail_outline,
                            iconBg: const Color(0xFFEAF6FB),
                          ),
                          _DetailTile(
                            label: 'Phone',
                            value: profile['cell_number']?.toString() ?? 'N/A',
                            icon: Icons.phone_outlined,
                            iconBg: const Color(0xFFEAF6FB),
                          ),
                          _DetailTile(
                            label: 'Department',
                            value: profile['department']?.toString() ?? 'N/A',
                            icon: Icons.apartment_outlined,
                            iconBg: const Color(0xFFEAF6FB),
                          ),
                          _DetailTile(
                            label: 'Company',
                            value: profile['company']?.toString() ?? 'N/A',
                            icon: Icons.domain_outlined,
                            iconBg: const Color(0xFFEAF6FB),
                          ),
                          _DetailTile(
                            label: 'Date of Joining',
                            value: _formatDate(
                                profile['date_of_joining']?.toString()),
                            icon: Icons.calendar_today_outlined,
                            iconBg: const Color(0xFFEAF6FB),
                          ),
                          _DetailTile(
                            label: 'Gender',
                            value: profile['gender']?.toString() ?? 'N/A',
                            icon: Icons.person_outline,
                            iconBg: const Color(0xFFEAF6FB),
                          ),
                          _DetailTile(
                            label: 'Blood Group',
                            value: profile['blood_group']?.toString() ?? 'N/A',
                            icon: Icons.bloodtype_outlined,
                            iconBg: const Color(0xFFEAF6FB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? const Color.fromARGB(255, 43, 26, 26)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              onTap: () {
                                setState(() {
                                  _aboutOpen = !_aboutOpen;
                                });
                              },
                              title: const Text(
                                'About Me',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Transform.rotate(
                                angle: _aboutOpen ? 3.1415 : 0,
                                child: const Icon(
                                  Icons.expand_more,
                                  color: Color(0xFF0C8DB6),
                                ),
                              ),
                            ),
                            if (_aboutOpen)
                              Column(
                                children: [
                                  // const Divider(height: 1),
                                  _AboutItem(
                                    label: 'Employment Type',
                                    value: profile['employment_type']
                                            ?.toString() ??
                                        'N/A',
                                    icon: Icons.work_outline,
                                  ),
                                  // const Divider(height: 1),
                                  _AboutItem(
                                    label: 'Emergency Contact Name',
                                    value: profile['person_to_be_contacted']
                                            ?.toString() ??
                                        'N/A',
                                    icon: Icons.person_outline,
                                  ),
                                  // const Divider(height: 1),
                                  _AboutItem(
                                    label: 'Emergency Contact Number',
                                    value: profile['emergency_phone_number']
                                            ?.toString() ??
                                        'N/A',
                                    icon: Icons.shield_outlined,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;

  const _DetailTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color.fromARGB(255, 43, 26, 26)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          // border: Border.all(
          //   color: theme.dividerColor.withValues(alpha: 0.5),
          // ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: const Color(0xFF0C8DB6),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AboutItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color.fromARGB(255, 43, 26, 26)
            : const Color(0xFFF8F9FA),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: const Color(0xFF0C8DB6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
