import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/glass_button.dart';

class AttendanceScreen extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;
  final String? userInitials;

  const AttendanceScreen({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
    this.userInitials,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<dynamic> _records = const [];
  String? _employeeId;

  bool _showCalendar = false;
  DateTime _currentMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDate;
  Map<DateTime, String> _statusByDate = const {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    String? employeeId = widget.currentEmployeeId;
    if ((employeeId == null || employeeId.trim().isEmpty) &&
        widget.currentUserEmail != null &&
        widget.currentUserEmail!.trim().isNotEmpty) {
      try {
        final employee = await FrappeApi.fetchEmployeeDetails(
          widget.currentUserEmail!.trim(),
          byEmail: true,
        );
        employeeId = employee != null ? employee['name']?.toString() : null;
      } catch (_) {}
    }
    if (employeeId == null || employeeId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _refreshing = false;
        _error =
            'Employee ID not available. Please ensure your profile is complete.';
      });
      return;
    }
    _employeeId = employeeId;
    if (!refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final filters = jsonEncode([
        ['employee', '=', employeeId],
      ]);
      final fields = jsonEncode([
        'name',
        'attendance_date',
        'status',
        'in_time',
        'out_time',
      ]);
      final params = {
        'filters': filters,
        'fields': fields,
        'order_by': 'attendance_date desc',
        'limit_page_length': '50',
      };
      final data = await FrappeApi.getResourceList(
        'Attendance',
        params: params,
        cache: true,
        forceRefresh: refresh,
      );
      setState(() {
        _records = data;
        _statusByDate = _buildStatusByDate(data);
        _selectedDate ??= DateTime.now();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'N/A';
    }
    try {
      final d = DateTime.parse(value.split(' ').first);
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
      final month = months[d.month - 1];
      return '${d.day.toString().padLeft(2, '0')} - $month - ${d.year.toString().substring(2)}';
    } catch (_) {
      return value;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green.shade700;
      case 'Absent':
        return Colors.red.shade700;
      case 'On Leave':
        return Colors.blue.shade700;
      case 'Holiday':
        return Colors.orange.shade700;
      case 'Work From Home':
        return const Color.fromARGB(255, 21, 179, 152);
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: MainAppBar(
        title: 'Attendance',
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
                onPressed: () => _loadData(refresh: true),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          children: [
            GlassContainer(
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _ViewToggleButton(
                    icon: Icons.view_list,
                    selected: !_showCalendar,
                    onTap: () {
                      setState(() {
                        _showCalendar = false;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  _ViewToggleButton(
                    icon: Icons.calendar_month,
                    selected: _showCalendar,
                    onTap: () {
                      setState(() {
                        _showCalendar = true;
                      });
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),
            GlassButton(
              onPressed: _openAttendanceRequestForm,
              label: 'Add Attendance',
              icon: Icons.add,
              width: 160,
              height: 44,
              color:
                  const Color.fromARGB(255, 21, 59, 126).withValues(alpha: 0.3),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!_showCalendar)
          _buildListView(context)
        else
          _buildCalendarView(context),
      ],
    );
  }

  Widget _buildListView(BuildContext context) {
    if (_records.isEmpty) {
      return GlassContainer(
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: const Text(
            'No attendance records found.',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    final count = _records.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassContainer(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
          opacity: 0.15,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                const Icon(
                  Icons.view_agenda,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Attendance List',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._records.map((raw) {
          final item = raw as Map<String, dynamic>;
          final status = (item['status'] ?? '').toString();
          final date = _formatDate(item['attendance_date']?.toString());
          final color = _statusColor(status);
          final chipBg = color.withValues(alpha: 0.2);
          return GlassContainer(
            margin: const EdgeInsets.only(bottom: 8),
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
            opacity: 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.calendar_today,
                      color: color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.isEmpty ? 'Attendance' : status,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.isEmpty ? 'Attendance' : status,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCalendarView(BuildContext context) {
    final theme = Theme.of(context);
    final monthLabel = DateFormat.yMMMM().format(_currentMonth);
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekdayIndex = firstDayOfMonth.weekday % 7;
    final rows = <TableRow>[];
    int day = 1 - firstWeekdayIndex;
    while (day <= daysInMonth) {
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        if (day < 1 || day > daysInMonth) {
          cells.add(const SizedBox.shrink());
        } else {
          final date = DateTime(_currentMonth.year, _currentMonth.month, day);
          final normalized = DateTime(date.year, date.month, date.day);
          final status = _statusByDate[normalized];
          final selected =
              _selectedDate != null && _isSameDate(_selectedDate!, normalized);
          cells.add(_CalendarDay(
            date: normalized,
            status: status,
            selected: selected,
            onTap: () {
              setState(() {
                _selectedDate = normalized;
              });
              _showDayDetails(normalized, status);
            },
          ));
        }
        day++;
      }
      rows.add(TableRow(children: cells));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassContainer(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black,
          opacity: 0.5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Text(
                      monthLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon:
                          const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(),
                    1: FlexColumnWidth(),
                    2: FlexColumnWidth(),
                    3: FlexColumnWidth(),
                    4: FlexColumnWidth(),
                    5: FlexColumnWidth(),
                    6: FlexColumnWidth(),
                  },
                  children: [
                    TableRow(
                      children: const [
                        'Sun',
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                      ].map((label) {
                        return _WeekdayLabel(
                          label: label,
                        );
                      }).toList(),
                    ),
                    ...rows,
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            _LegendChip(
              label: 'Absent',
              color: Color(0xFFEF4444),
            ),
            _LegendChip(
              label: 'On Leave',
              color: Color(0xFF8B5CF6),
            ),
            _LegendChip(
              label: 'Present',
              color: Color(0xFF22C55E),
            ),
            _LegendChip(
              label: 'Holiday',
              color: Color(0xFFFACC15),
              textColor: Color(0xFF92400E),
            ),
            _LegendChip(
              label: 'Work From Home',
              color: Color(0xFF60A5FA),
            ),
          ],
        ),
      ],
    );
  }

  void _showDayDetails(DateTime date, String? status) {
    if (status == null || status.isEmpty) {
      return;
    }
    final dateLabel = DateFormat('yyyy-MM-dd').format(date);
    final statusColor = _statusColor(status);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Day Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close',
                          style: TextStyle(color: Colors.blueAccent)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Date',
                  value: dateLabel,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Status',
                  value: status,
                  chipColor: statusColor,
                ),
                const SizedBox(height: 8),
                if (_employeeId != null && _employeeId!.isNotEmpty)
                  _DetailRow(
                    label: 'Employee',
                    value: _employeeId!,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<DateTime, String> _buildStatusByDate(List<dynamic> records) {
    final map = <DateTime, String>{};
    for (final raw in records) {
      final item = raw as Map<String, dynamic>;
      final dateStr = item['attendance_date']?.toString();
      final status = item['status']?.toString() ?? '';
      if (dateStr == null || dateStr.isEmpty || status.isEmpty) {
        continue;
      }
      try {
        final d = DateTime.parse(dateStr.split(' ').first);
        final key = DateTime(d.year, d.month, d.day);
        map[key] = status;
      } catch (_) {}
    }
    return map;
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
    });
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _openAttendanceRequestForm() {
    final employeeId = _employeeId;
    if (employeeId == null || employeeId.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Employee information is not available.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: _AttendanceRequestSheet(
              employeeId: employeeId,
              onSubmitted: () {
                Navigator.of(ctx).pop();
                _loadData(refresh: true);
              },
            ),
          ),
        );
      },
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF271085);
    return Material(
      color: selected
          ? const Color.fromARGB(255, 150, 150, 153)
          : const Color.fromARGB(255, 92, 72, 72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: selected ? Colors.white : selectedColor,
          ),
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const _LegendChip({
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = textColor ?? const Color(0xFFFFFFFF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: tc,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? chipColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: baseColor.withValues(alpha: 0.8),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: chipColor == null
                ? Text(
                    value,
                    style: theme.textTheme.bodyMedium,
                  )
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor!.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: chipColor,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime date;
  final String? status;
  final bool selected;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.date,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Present':
        return const Color(0xFF22C55E);
      case 'Absent':
        return const Color(0xFFEF4444);
      case 'On Leave':
        return const Color(0xFF8B5CF6);
      case 'Holiday':
        return const Color(0xFFFACC15);
      case 'Work From Home':
        return const Color(0xFF60A5FA);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusValue = status;
    Color? fill;
    Color border = Colors.transparent;
    Color textColor = Colors.white;
    if (statusValue != null && statusValue.isNotEmpty) {
      final base = _statusColor(statusValue);
      fill = base.withValues(alpha: 0.22);
      textColor = base;
    }
    if (selected) {
      border = const Color(0xFF1D4ED8);
      fill ??= border.withValues(alpha: 0.12);
    }
    final dayText = date.day.toString();
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: border,
                width: border == Colors.transparent ? 0 : 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              dayText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceRequestSheet extends StatefulWidget {
  final String employeeId;
  final VoidCallback onSubmitted;

  const _AttendanceRequestSheet({
    required this.employeeId,
    required this.onSubmitted,
  });

  @override
  State<_AttendanceRequestSheet> createState() =>
      _AttendanceRequestSheetState();
}

class _AttendanceRequestSheetState extends State<_AttendanceRequestSheet> {
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _halfDay = false;
  DateTime? _halfDayDate;
  bool _includeHolidays = false;
  String _reason = 'Work From Home';
  final TextEditingController _shiftController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _shiftController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    BuildContext context,
    ValueChanged<DateTime?> setter,
    DateTime? initial,
  ) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color.fromARGB(255, 41, 61, 92),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setter(picked);
      setState(() {});
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _handleSubmit() async {
    if (_fromDate == null || _toDate == null) {
      Fluttertoast.showToast(
        msg: 'Please select From Date and To Date.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    if (_halfDay && _halfDayDate == null) {
      Fluttertoast.showToast(
        msg: 'Please select Half Day Date.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate!);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate!);
      final halfDayStr = _halfDayDate != null
          ? DateFormat('yyyy-MM-dd').format(_halfDayDate!)
          : null;
      final doc = <String, dynamic>{
        'doctype': 'Attendance Request',
        'employee': widget.employeeId,
        'from_date': fromStr,
        'to_date': toStr,
        'half_day': _halfDay,
        'include_holidays': _includeHolidays,
        'reason': _reason,
        'shift': _shiftController.text.trim(),
        'explanation': _explanationController.text.trim(),
      };
      if (halfDayStr != null) {
        doc['half_day_date'] = halfDayStr;
      }
      await FrappeApi.callMethod(
        'frappe.client.insert',
        args: {
          'doc': jsonEncode(doc),
        },
      );
      Fluttertoast.showToast(
        msg: 'Attendance request submitted.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      widget.onSubmitted();
    } catch (e) {
      Fluttertoast.showToast(
        msg: e.toString(),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Attendance Request',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('From Date *', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            _DateField(
              label: _formatDate(_fromDate),
              onTap: () => _pickDate(context, (d) => _fromDate = d, _fromDate),
            ),
            const SizedBox(height: 12),
            const Text('To Date *', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            _DateField(
              label: _formatDate(_toDate),
              onTap: () => _pickDate(context, (d) => _toDate = d, _toDate),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _halfDay,
                  activeColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.white70),
                  onChanged: (value) {
                    setState(() {
                      _halfDay = value ?? false;
                    });
                  },
                ),
                const SizedBox(width: 4),
                const Text('Half Day', style: TextStyle(color: Colors.white)),
              ],
            ),
            if (_halfDay) ...[
              const SizedBox(height: 4),
              const Text('Half Day Date',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              _DateField(
                label: _formatDate(_halfDayDate),
                onTap: () => _pickDate(
                  context,
                  (d) => _halfDayDate = d,
                  _halfDayDate,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _includeHolidays,
                  activeColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.white70),
                  onChanged: (value) {
                    setState(() {
                      _includeHolidays = value ?? false;
                    });
                  },
                ),
                const SizedBox(width: 4),
                const Text('Include Holidays',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Shift', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            TextField(
              controller: _shiftController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Shift',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Reason *', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Work From Home'),
                  selectedColor: Colors.blueAccent,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: _reason == 'Work From Home'
                        ? Colors.white
                        : Colors.white70,
                  ),
                  selected: _reason == 'Work From Home',
                  onSelected: (_) {
                    setState(() {
                      _reason = 'Work From Home';
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('On Duty'),
                  selectedColor: Colors.blueAccent,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: _reason == 'On Duty' ? Colors.white : Colors.white70,
                  ),
                  selected: _reason == 'On Duty',
                  onSelected: (_) {
                    setState(() {
                      _reason = 'On Duty';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Explanation', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            TextField(
              controller: _explanationController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Explanation',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GlassButton(
                onPressed: _handleSubmit,
                label: _submitting ? 'Submitting...' : 'Submit Request',
                color: const Color.fromARGB(255, 21, 59, 126)
                    .withValues(alpha: 0.3),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  24,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = label == 'Select date';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isPlaceholder ? Colors.white38 : Colors.white,
                fontSize: 14,
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}
