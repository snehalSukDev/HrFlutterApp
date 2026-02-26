import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';
import 'expense_claim_screen.dart';
import 'announcement_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;
  final void Function(int index)? onTabChange;

  const HomeScreen({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
    this.onTabChange,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  Map<String, dynamic>? _employeeProfile;
  List<dynamic> _checkins = const [];
  List<dynamic> _holidays = const [];
  List<dynamic> _birthdays = const [];
  List<dynamic> _anniversaries = const [];

  bool _isPunching = false;
  String? _pendingLogType;

  bool _allowMobileCheckin = true;

  double _sliderPosition = 0;
  double _trackWidth = 0;
  final double _knobSize = 44;

  double get _maxDistance => math.max(_trackWidth - _knobSize, 0);

  double _dragStartSlider = 0;
  double _dragDx = 0;

  double? _latitude;
  double? _longitude;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadLocation();
    _loadHrSettings();
  }

  Future<void> _loadAll({bool refresh = false}) async {
    if (!refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final profile = await _fetchProfile();
      if (profile != null) {
        await Future.wait([
          _fetchCheckins(refresh: refresh),
          _fetchEvents(profile, refresh: refresh),
        ]);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
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

  Future<void> _loadLocation() async {
    try {
      final position = await FrappeApi.getGeolocation();
      if (!mounted) {
        return;
      }
      final lat = position.latitude;
      final lon = position.longitude;
      if (lat.isNaN || lon.isNaN) {
        return;
      }
      setState(() {
        _latitude = lat;
        _longitude = lon;
        _locationError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationError = e.toString();
      });
    }
  }

  Future<void> _loadHrSettings() async {
    try {
      final res = await FrappeApi.callMethod(
        'hrms.api.get_hr_settings',
      );
      final raw = res['message'];
      if (!mounted) {
        return;
      }
      Map<String, dynamic> settings;
      if (raw is Map<String, dynamic>) {
        settings = raw;
      } else {
        settings = res;
      }
      final rawAllow = settings['allow_employee_checkin_from_mobile_app'];
      final allow = rawAllow == true ||
          rawAllow == 1 ||
          rawAllow == '1' ||
          rawAllow == 'true';
      setState(() {
        _allowMobileCheckin = allow;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allowMobileCheckin = true;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchProfile() async {
    final email = widget.currentUserEmail?.trim();
    if (email == null || email.isEmpty) {
      setState(() {
        _error = 'Logged in user email is not available.';
      });
      return null;
    }
    final profile = await FrappeApi.fetchEmployeeDetails(
      email,
      byEmail: true,
    );
    setState(() {
      _employeeProfile = profile;
    });
    return profile;
  }

  Future<void> _fetchCheckins({bool refresh = false}) async {
    final filters = jsonEncode([
      ['time', 'Timespan', 'today']
    ]);
    final fields = jsonEncode([
      'log_type',
      'time',
    ]);
    final params = {
      'filters': filters,
      'fields': fields,
      'order_by': 'time asc',
    };
    final data = await FrappeApi.getResourceList(
      'Employee Checkin',
      params: params,
      cache: true,
      forceRefresh: refresh,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _checkins = data;
    });
  }

  Future<void> _fetchEvents(
    Map<String, dynamic> profile, {
    bool refresh = false,
  }) async {
    final employeeId = profile['name']?.toString();
    if (employeeId == null || employeeId.isEmpty) {
      return;
    }
    final args = {
      'employee_id': employeeId,
      'cache': true,
      'forceRefresh': refresh,
    };
    final res = await FrappeApi.callMethod(
      'tbui_backend_core.api.events_today',
      args: args,
    );
    final msg = res['message'];
    List<dynamic> holidays = const [];
    List<dynamic> birthdays = const [];
    List<dynamic> anniversaries = const [];
    if (msg is Map<String, dynamic>) {
      final hValue = msg['holidays'];
      if (hValue is List) {
        holidays = hValue;
      }
      final bValue = msg['birthdays'];
      if (bValue is List) {
        birthdays = bValue;
      }
      final aValue = msg['work_anniversaries'];
      if (aValue is List) {
        anniversaries = aValue;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _holidays = holidays;
      _birthdays = birthdays;
      _anniversaries = anniversaries;
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) {
      return 'Good Morning!';
    }
    if (h < 17) {
      return 'Good Afternoon!';
    }
    return 'Good Evening!';
  }

  Map<String, dynamic>? get _lastCheckin {
    if (_checkins.isEmpty) {
      return null;
    }
    final last = _checkins.last;
    if (last is Map<String, dynamic>) {
      return last;
    }
    return null;
  }

  bool get _effectivePunchedIn {
    if (_isPunching) {
      return _pendingLogType == 'IN';
    }
    final last = _lastCheckin;
    if (last == null) {
      return false;
    }
    final type = last['log_type']?.toString();
    return type == 'IN';
  }

  Future<bool> _handlePunch(String logType) async {
    if (_employeeProfile == null) {
      return false;
    }
    if (_isPunching) {
      return false;
    }
    final employeeId = _employeeProfile!['name']?.toString();
    if (employeeId == null || employeeId.isEmpty) {
      return false;
    }
    var success = false;
    setState(() {
      _isPunching = true;
      _pendingLogType = logType;
    });
    try {
      final position = await FrappeApi.getGeolocation();
      final now = DateTime.now();
      final timeString =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final doc = {
        'doctype': 'Employee Checkin',
        'employee': employeeId,
        'log_type': logType,
        'time': timeString,
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
      await FrappeApi.callMethod(
        'frappe.desk.form.save.savedocs',
        args: {
          'doc': jsonEncode(doc),
          'action': 'Save',
        },
      );
      await _fetchCheckins(refresh: true);
      if (!mounted) {
        success = true;
        return success;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checked $logType'),
        ),
      );
      success = true;
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
          _isPunching = false;
          _pendingLogType = null;
        });
      }
    }
    return success;
  }

  String _formatLastSwipe() {
    final last = _lastCheckin;
    if (last == null) {
      return '-';
    }
    final raw = last['time']?.toString();
    if (raw == null || raw.isEmpty) {
      return '-';
    }
    try {
      final d = DateTime.parse(raw);
      return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year.toString().substring(2)} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _employeeProfile;
    final greeting = _greeting();
    return Scaffold(
      appBar: MainAppBar(
        title: 'Home',
        onLogout: widget.onLogout,
        userInitials: _userInitials(profile),
        currentUserEmail: widget.currentUserEmail,
        currentEmployeeId: widget.currentEmployeeId,
      ),
      body: RefreshIndicator(
        onRefresh: () {
          setState(() {
            _refreshing = true;
          });
          return _loadAll(refresh: true);
        },
        child: _buildBody(context, theme, profile, greeting),
      ),
    );
  }

  String? _userInitials(Map<String, dynamic>? profile) {
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
    final email = widget.currentUserEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    return null;
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic>? profile,
    String greeting,
  ) {
    if (_loading && !_refreshing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _loadAll(refresh: true),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (profile == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('No profile data available.'),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: const Color(0xFF213465),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.brightness == Brightness.dark
                          ? const Color.fromARGB(255, 43, 26, 26)
                          : const Color.fromARGB(255, 129, 128, 128),
                      child: Text(
                        (_userInitials(profile) ?? '?').toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile['employee_name']?.toString() ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last swipe: ${_formatLastSwipe()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLocationCard(theme),
                const SizedBox(height: 16),
                _buildPunchSlider(theme),
                const SizedBox(height: 16),
                _buildQuickActions(context),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildCelebrationCard(theme),
        const SizedBox(height: 16),
        _buildHolidays(theme),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickAction(
              icon: Icons.request_quote_outlined,
              label: 'Expense Claim',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ExpenseClaimScreen(
                      currentUserEmail: widget.currentUserEmail,
                      currentEmployeeId: widget.currentEmployeeId,
                      onLogout: widget.onLogout,
                      userInitials: _userInitials(_employeeProfile),
                    ),
                  ),
                );
              },
            ),
            _QuickAction(
              icon: Icons.access_time,
              label: 'Attendance',
              onTap: () {
                widget.onTabChange?.call(2);
              },
            ),
            _QuickAction(
              icon: Icons.event_available,
              label: 'Leave',
              onTap: () {
                widget.onTabChange?.call(3);
              },
            ),
            _QuickAction(
              icon: Icons.campaign_outlined,
              label: 'Announcement',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => AnnouncementScreen(
                      currentUserEmail: widget.currentUserEmail,
                      currentEmployeeId: widget.currentEmployeeId,
                      onLogout: widget.onLogout,
                      userInitials: _userInitials(_employeeProfile),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCelebrationCard(ThemeData theme) {
    final hasBirthdays = _birthdays.isNotEmpty;
    final hasAnniversaries = _anniversaries.isNotEmpty;
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardBackgroundColor = isDarkMode
        ? const Color.fromARGB(255, 43, 26, 26)
        : theme.colorScheme.surface;

    if (!hasBirthdays && !hasAnniversaries) {
      return Card(
        elevation: 2,
        color: cardBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎉 Celebrations',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No birthdays or work anniversaries today.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      elevation: 2,
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎉 Celebrations',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (hasBirthdays) ...[
              // Divider(
              //   height: 24,
              //   thickness: 1,
              //   color: theme.dividerColor,
              // ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.card_giftcard,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Birthdays',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _birthdays.length,
                  itemBuilder: (context, index) {
                    final item = _birthdays[index] as Map<String, dynamic>;
                    final name = item['employee_name']?.toString() ??
                        item['name']?.toString() ??
                        '';
                    final initial = name.isNotEmpty
                        ? name.trim().substring(0, 1).toUpperCase()
                        : '?';
                    return Container(
                      width: 100,
                      margin: EdgeInsets.only(
                        right: index == _birthdays.length - 1 ? 0 : 10,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey.shade600
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDarkMode
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Today',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            if (hasAnniversaries) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Work Anniversaries',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _anniversaries.length,
                  itemBuilder: (context, index) {
                    final item = _anniversaries[index] as Map<String, dynamic>;
                    final name = item['employee_name']?.toString() ??
                        item['name']?.toString() ??
                        '';
                    final initial = name.isNotEmpty
                        ? name.trim().substring(0, 1).toUpperCase()
                        : '?';
                    return Container(
                      width: 100,
                      margin: EdgeInsets.only(
                        right: index == _anniversaries.length - 1 ? 0 : 10,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey.shade600
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDarkMode
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Anniversary',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'My Location',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMapView(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(ThemeData theme) {
    if (_locationError != null) {
      return Container(
        color: theme.colorScheme.surface,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _locationError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadLocation,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_latitude == null || _longitude == null) {
      return Container(
        color: theme.colorScheme.surface,
        alignment: Alignment.center,
        child: Text(
          'Fetching location...',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    final center = LatLng(_latitude!, _longitude!);
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'hr_mobile_flutter',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.location_on,
                color: theme.colorScheme.primary,
                size: 32,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPunchSlider(ThemeData theme) {
    if (!_allowMobileCheckin) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEC),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFFEA4335),
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Not allowed to checkin from here',
          style: TextStyle(
            color: Color(0xFFEA4335),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final effectivePunchedIn = _effectivePunchedIn;
    final bgColor =
        effectivePunchedIn ? const Color(0xFFFFECEC) : const Color(0xFFE8FFF0);
    final borderColor =
        effectivePunchedIn ? const Color(0xFFEA4335) : const Color(0xFF34A853);
    final textColor = borderColor;
    final label =
        effectivePunchedIn ? 'Slide back to Punch Out' : 'Slide to Punch In';
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width != _trackWidth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _trackWidth = width;
              _sliderPosition = effectivePunchedIn ? _maxDistance : 0;
            });
          });
        }
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: borderColor),
          ),
          child: Stack(
            children: [
              if (_isPunching)
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _pendingLogType == 'OUT'
                            ? 'Punching Out...'
                            : 'Punching In...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Center(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Positioned(
                left: _sliderPosition,
                top: 4,
                bottom: 4,
                child: GestureDetector(
                  onHorizontalDragStart: (_) {
                    if (_isPunching || _trackWidth <= 0) {
                      return;
                    }
                    _dragStartSlider = _effectivePunchedIn ? _maxDistance : 0;
                    _dragDx = 0;
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_isPunching || _trackWidth <= 0) {
                      return;
                    }
                    _dragDx += details.delta.dx;
                    final max = _maxDistance;
                    final next = (_dragStartSlider + _dragDx).clamp(0.0, max);
                    setState(() {
                      _sliderPosition = next;
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    _handleSliderRelease();
                  },
                  child: Container(
                    width: _knobSize,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scaleX: effectivePunchedIn ? -1 : 1,
                      child: const Icon(
                        Icons.login,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSliderRelease() async {
    if (_isPunching || _trackWidth <= 0) {
      return;
    }
    final max = _maxDistance;
    final current = _sliderPosition;
    final punchedIn = _effectivePunchedIn;
    if (!punchedIn) {
      final threshold = max * 0.6;
      if (current >= threshold) {
        setState(() {
          _sliderPosition = max;
        });
        final ok = await _handlePunch('IN');
        if (!mounted) {
          return;
        }
        if (ok) {
          setState(() {
            _sliderPosition = _maxDistance;
          });
        } else {
          setState(() {
            _sliderPosition = 0;
          });
        }
      } else {
        setState(() {
          _sliderPosition = 0;
        });
      }
    } else {
      final threshold = max * 0.4;
      if (current <= threshold) {
        setState(() {
          _sliderPosition = 0;
        });
        final ok = await _handlePunch('OUT');
        if (!mounted) {
          return;
        }
        if (ok) {
          setState(() {
            _sliderPosition = 0;
          });
        } else {
          setState(() {
            _sliderPosition = _maxDistance;
          });
        }
      } else {
        setState(() {
          _sliderPosition = _maxDistance;
        });
      }
    }
  }

  Widget _buildHolidays(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardBackgroundColor = isDarkMode
        ? const Color.fromARGB(255, 43, 26, 26)
        : theme.colorScheme.surface;

    if (_holidays.isEmpty) {
      return Card(
        elevation: 2,
        color: cardBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No upcoming holidays.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    return Card(
      elevation: 2,
      color: cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Holidays',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._holidays.map((raw) {
              final item = raw as Map<String, dynamic>;
              final desc = item['description']?.toString() ?? '';
              final dateRaw = item['holiday_date']?.toString() ??
                  item['date']?.toString() ??
                  '';
              String day = '';
              String month = '';
              String weekday = '';
              if (dateRaw.isNotEmpty) {
                try {
                  final d = DateTime.parse(dateRaw);
                  day = d.day.toString().padLeft(2, '0');
                  final months = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec'
                  ];
                  month = months[d.month - 1];
                  final weekdays = [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday'
                  ];
                  weekday = weekdays[d.weekday - 1];
                } catch (_) {}
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: isDarkMode
                            ? cardBackgroundColor.withValues(alpha: 0.7)
                            : theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            day.isEmpty ? '??' : day,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            month.isEmpty ? 'N/A' : month,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            desc,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (weekday.isNotEmpty)
                            Text(
                              weekday,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF5B4ED6),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
