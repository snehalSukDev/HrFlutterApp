import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/frappe_api.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/app_background.dart';
import '../widgets/glass/glass_button.dart';

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
    if (value == null || value.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(value.split(' ').first);
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = _employeeProfile;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
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
                          child: Text('No profile data',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        GlassContainer(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.1),
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
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                profile['employee_name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile['designation']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile['name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassContainer(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: const Text(
                                  'Personal Information',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final itemWidth =
                                      (constraints.maxWidth - 12) / 2;
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: itemWidth,
                                        child: _DetailTile(
                                          label: 'Email',
                                          value:
                                              profile['user_id']?.toString() ??
                                                  'N/A',
                                          icon: Icons.mail_outline,
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _DetailTile(
                                          label: 'Phone',
                                          value: profile['cell_number']
                                                  ?.toString() ??
                                              'N/A',
                                          icon: Icons.phone_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _DetailTile(
                                          label: 'Department',
                                          value: profile['department']
                                                  ?.toString() ??
                                              'N/A',
                                          icon: Icons.apartment_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _DetailTile(
                                          label: 'Company',
                                          value:
                                              profile['company']?.toString() ??
                                                  'N/A',
                                          icon: Icons.domain_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _DetailTile(
                                          label: 'Date of Joining',
                                          value: _formatDate(
                                              profile['date_of_joining']
                                                  ?.toString()),
                                          icon: Icons.calendar_today_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _DetailTile(
                                          label: 'Gender',
                                          value:
                                              profile['gender']?.toString() ??
                                                  'N/A',
                                          icon: Icons.person_outline,
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _DetailTile(
                                          label: 'Blood Group',
                                          value: profile['blood_group']
                                                  ?.toString() ??
                                              'N/A',
                                          icon: Icons.bloodtype_outlined,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassContainer(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            children: [
                              ListTile(
                                onTap: () {
                                  setState(() {
                                    _aboutOpen = !_aboutOpen;
                                  });
                                },
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'More Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                trailing: Transform.rotate(
                                  angle: _aboutOpen ? 3.1415 : 0,
                                  child: const Icon(
                                    Icons.expand_more,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              if (_aboutOpen)
                                Column(
                                  children: [
                                    _AboutItem(
                                      label: 'Employment Type',
                                      value: profile['employment_type']
                                              ?.toString() ??
                                          'N/A',
                                      icon: Icons.work_outline,
                                    ),
                                    _AboutItem(
                                      label: 'Emergency Contact Name',
                                      value: profile['person_to_be_contacted']
                                              ?.toString() ??
                                          'N/A',
                                      icon: Icons.person_outline,
                                    ),
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
                        const SizedBox(height: 32),
                        GlassButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: const Text('Logout',
                                    style: TextStyle(color: Colors.white)),
                                content: const Text(
                                  'Are you sure you want to log out?',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      widget.onLogout();
                                    },
                                    child: const Text('Logout',
                                        style:
                                            TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            );
                          },
                          label: 'Logout',
                          icon: Icons.logout,
                          color: Colors.redAccent.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.white70,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
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
                    color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.white70,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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
