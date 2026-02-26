import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';

class ShiftDetailsScreen extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;
  final String? userInitials;

  const ShiftDetailsScreen({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
    this.userInitials,
  });

  @override
  State<ShiftDetailsScreen> createState() => _ShiftDetailsScreenState();
}

class _ShiftDetailsScreenState extends State<ShiftDetailsScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  DateTime _currentMonth = DateTime.now();
  List<Map<String, dynamic>> _shiftData = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _monthDisplay {
    return '${_monthName(_currentMonth.month)} ${_currentMonth.year}';
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month < 1 || month > 12) {
      return '';
    }
    return names[month - 1];
  }

  Future<void> _loadData({bool refresh = false}) async {
    final hasEmployeeId = widget.currentEmployeeId != null &&
        widget.currentEmployeeId!.isNotEmpty;
    if (!hasEmployeeId &&
        (widget.currentUserEmail == null ||
            widget.currentUserEmail!.trim().isEmpty)) {
      setState(() {
        _loading = false;
        _refreshing = false;
        _error =
            'User email or ID not provided. Please ensure your profile is complete.';
      });
      return;
    }
    if (!refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      String? empId = widget.currentEmployeeId;
      if ((empId == null || empId.isEmpty) && widget.currentUserEmail != null) {
        final filters = jsonEncode([
          ['user_id', '=', widget.currentUserEmail!.trim()]
        ]);
        final fields = jsonEncode(['name']);
        final list = await FrappeApi.getResourceList(
          'Employee',
          params: {
            'filters': filters,
            'fields': fields,
          },
          cache: true,
          forceRefresh: refresh,
        );
        if (list.isEmpty) {
          setState(() {
            _error = 'Employee not found. Please contact your administrator.';
          });
          return;
        }
        final first = list.first as Map<String, dynamic>;
        empId = first['name']?.toString();
      }
      if (empId == null || empId.isEmpty) {
        setState(() {
          _error = 'Employee ID not found. Please contact your administrator.';
        });
        return;
      }
      final startDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final endDate = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      final startStr =
          '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endStr =
          '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      final assignmentFilters = jsonEncode([
        ['employee', '=', empId],
        ['start_date', '<=', endStr],
        ['end_date', '>=', startStr],
        ['docstatus', '=', 1],
      ]);
      final assignmentFields = jsonEncode([
        'name',
        'start_date',
        'end_date',
        'shift_type',
      ]);
      final assignments = await FrappeApi.getResourceList(
        'Shift Assignment',
        params: {
          'filters': assignmentFilters,
          'fields': assignmentFields,
          'limit_page_length': '100',
        },
        cache: true,
        forceRefresh: refresh,
      );
      final Set<String> shiftTypeNames = {};
      for (final raw in assignments) {
        final row = raw as Map<String, dynamic>;
        final type = row['shift_type']?.toString();
        if (type != null && type.isNotEmpty) {
          shiftTypeNames.add(type);
        }
      }
      final Map<String, Map<String, dynamic>> shiftTypeMap = {};
      for (final name in shiftTypeNames) {
        try {
          final details = await FrappeApi.getResource(
            'Shift Type',
            name,
            cache: true,
            forceRefresh: refresh,
          );
          shiftTypeMap[name] = details;
        } catch (_) {}
      }
      final List<Map<String, dynamic>> dailyRoster = [];
      for (final raw in assignments) {
        final assign = raw as Map<String, dynamic>;
        final String shiftType = assign['shift_type']?.toString() ?? '';
        if (shiftType.isEmpty) {
          continue;
        }
        final startRaw = assign['start_date']?.toString();
        if (startRaw == null || startRaw.isEmpty) {
          continue;
        }
        final from = DateTime.parse(startRaw);
        final toRaw = assign['end_date']?.toString();
        final to =
            (toRaw == null || toRaw.isEmpty) ? from : DateTime.parse(toRaw);
        DateTime loopStart = from.isBefore(startDate) ? startDate : from;
        DateTime loopEnd = to.isAfter(endDate) ? endDate : to;
        for (var d = loopStart;
            !d.isAfter(loopEnd);
            d = d.add(const Duration(days: 1))) {
          final keyDate =
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          final details = shiftTypeMap[shiftType];
          dailyRoster.add({
            'id': '${assign['name']}_$keyDate',
            'shift_date': keyDate,
            'shift_type': shiftType,
            'start_time': details?['start_time'],
            'end_time': details?['end_time'],
          });
        }
      }
      dailyRoster.sort((a, b) {
        final da = DateTime.tryParse(a['shift_date']?.toString() ?? '') ??
            DateTime.now();
        final db = DateTime.tryParse(b['shift_date']?.toString() ?? '') ??
            DateTime.now();
        return da.compareTo(db);
      });
      setState(() {
        _shiftData = dailyRoster;
      });
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

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
    });
    _loadData(refresh: true);
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'N/A';
    }
    try {
      final d = DateTime.parse(value);
      const months = [
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
        'Dec',
      ];
      final month = months[d.month - 1];
      final year = d.year.toString().substring(2);
      return '${d.day.toString().padLeft(2, '0')} $month $year';
    } catch (_) {
      return value;
    }
  }

  String _weekdayShort(DateTime date) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[date.weekday % 7];
  }

  String _formatTime(String? value) {
    if (value == null || value.isEmpty) {
      return 'N/A';
    }
    try {
      final parts = value.split(':');
      if (parts.length < 2) {
        return value;
      }
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final isPm = h >= 12;
      final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      final mm = m.toString().padLeft(2, '0');
      return '$displayH:$mm ${isPm ? 'PM' : 'AM'}';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        title: 'Shift',
        onLogout: widget.onLogout,
        userInitials: widget.userInitials ?? widget.currentUserEmail,
        currentUserEmail: widget.currentUserEmail,
        currentEmployeeId: widget.currentEmployeeId,
      ),
      body: RefreshIndicator(
        onRefresh: () {
          setState(() {
            _refreshing = true;
          });
          return _loadData(refresh: true);
        },
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.error_outline,
            size: 50,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _loadData(refresh: true),
            child: const Text('Try Again'),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shift Roster $_monthDisplay',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color.fromARGB(255, 43, 26, 26)
              : null,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color.fromARGB(255, 43, 26, 26)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Day',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Shift',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Start',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'End',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading && !_refreshing)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_shiftData.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 40,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text('No shifts assigned for this month.'),
                    ],
                  ),
                )
              else
                Column(
                  children: _shiftData.map((item) {
                    final dateStr = item['shift_date']?.toString() ?? '';
                    final date = DateTime.tryParse(dateStr);
                    final isWeekend = date != null &&
                        (date.weekday == DateTime.saturday ||
                            date.weekday == DateTime.sunday);
                    return Container(
                      decoration: BoxDecoration(
                        color: isWeekend
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color.fromARGB(255, 43, 26, 26)
                                : const Color(0xFFEF5350)
                                    .withValues(alpha: 0.03))
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade700
                                    : const Color(0xFFDEE2E6),
                            width: 0.5,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatDate(dateStr),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              date == null ? '' : _weekdayShort(date),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              item['shift_type']?.toString() ?? 'N/A',
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatTime(item['start_time']?.toString()),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatTime(item['end_time']?.toString()),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
