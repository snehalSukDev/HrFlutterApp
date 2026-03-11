import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/glass_button.dart';

class LeavesScreen extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;
  final String? userInitials;

  const LeavesScreen({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
    this.userInitials,
  });

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<_LeaveBalance> _balances = const [];
  List<dynamic> _applications = const [];
  String? _employeeId;

  bool _showCalendar = false;
  DateTime _currentMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDate;
  Map<DateTime, List<Map<String, dynamic>>> _leavesByDate = const {};

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
      final employee = await FrappeApi.getResource('Employee', employeeId);
      final holidayListName = employee['holiday_list']?.toString();
      if (holidayListName != null && holidayListName.isNotEmpty) {
        await FrappeApi.getResource('Holiday List', holidayListName);
      }
      final ledgerFilters = jsonEncode([
        ['employee', '=', employeeId],
        ['docstatus', '=', 1],
      ]);
      final ledgerFields = jsonEncode([
        'leave_type',
        'leaves',
        'transaction_type',
      ]);
      final ledger = await FrappeApi.getResourceList(
        'Leave Ledger Entry',
        params: {
          'filters': ledgerFilters,
          'fields': ledgerFields,
          'limit_page_length': '100',
        },
        cache: true,
        forceRefresh: refresh,
      );
      final Map<String, _LeaveBalance> map = {};
      for (final raw in ledger) {
        final row = raw as Map<String, dynamic>;
        final type = row['leave_type']?.toString() ?? '';
        if (type.isEmpty) {
          continue;
        }
        map[type] ??= _LeaveBalance(type: type);
        final entryLeaves = (row['leaves'] as num?)?.toDouble() ?? 0;
        final txType = row['transaction_type']?.toString();
        if (txType == 'Leave Allocation') {
          map[type] = map[type]!.copyWith(
            allocated: map[type]!.allocated + entryLeaves,
          );
        } else if (txType == 'Leave Application') {
          map[type] = map[type]!.copyWith(
            taken: map[type]!.taken + entryLeaves.abs(),
          );
        }
      }
      final balances = map.values
          .map(
            (b) => b.copyWith(
              remaining: b.allocated - b.taken,
            ),
          )
          .toList()
        ..sort((a, b) => a.type.compareTo(b.type));
      final appFilters = jsonEncode([
        ['employee', '=', widget.currentEmployeeId],
      ]);
      final appFields = jsonEncode([
        'name',
        'from_date',
        'to_date',
        'leave_type',
        'status',
      ]);
      final applications = await FrappeApi.getResourceList(
        'Leave Application',
        params: {
          'filters': appFilters,
          'fields': appFields,
          'order_by': 'from_date desc',
          'limit_page_length': '50',
        },
        cache: true,
        forceRefresh: refresh,
      );
      setState(() {
        _balances = balances;
        _applications = applications;
        _leavesByDate = _groupApplicationsByDate(applications);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: MainAppBar(
        title: 'Leave',
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
              onPressed: _openLeaveApplicationForm,
              label: 'Apply Leave',
              icon: Icons.add,
              width: 140,
              height: 44,
              color:
                  const Color.fromARGB(255, 21, 59, 126).withValues(alpha: 0.3),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_showCalendar)
          _buildCalendarView(context)
        else
          _buildListView(context),
      ],
    );
  }

  Widget _buildListView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave Balances',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        if (_balances.isEmpty)
          const Text('No leave balances found.',
              style: TextStyle(color: Colors.white70))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _balances
                .map(
                  (b) => SizedBox(
                    width: (MediaQuery.of(context).size.width - 16 * 2 - 8) / 2,
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black,
                      opacity: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.type,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            _buildBalanceRow(
                              label: 'Allocated',
                              value: b.allocated.toStringAsFixed(1),
                            ),
                            _buildBalanceRow(
                              label: 'Taken',
                              value: b.taken.toStringAsFixed(1),
                            ),
                            _buildBalanceRow(
                              label: 'Remaining',
                              value: b.remaining.toStringAsFixed(1),
                              highlight: true,
                              highlightColor: b.remaining < 0
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 24),
        Text(
          'Recent Leave Applications',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        if (_applications.isEmpty)
          const Text('No leave applications found.',
              style: TextStyle(color: Colors.white70))
        else
          ..._applications.map(
            (raw) {
              final item = raw as Map<String, dynamic>;
              final type = item['leave_type']?.toString() ?? 'Leave';
              final from = _formatDate(item['from_date']?.toString());
              final to = _formatDate(item['to_date']?.toString());
              final status = item['status']?.toString() ?? 'Applied';
              Color statusColor;
              switch (status) {
                case 'Approved':
                  statusColor = Colors.greenAccent;
                  break;
                case 'Rejected':
                  statusColor = Colors.redAccent;
                  break;
                case 'Open':
                  statusColor = Colors.orangeAccent;
                  break;
                default:
                  statusColor = Colors.blueAccent;
              }
              return GlassContainer(
                margin: const EdgeInsets.only(bottom: 8),
                borderRadius: BorderRadius.circular(12),
                color: Colors.black,
                opacity: 0.5,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.event,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$from → $to',
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
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
          final list = _leavesByDate[normalized] ?? const [];
          cells.add(_LeaveCalendarDay(
            date: normalized,
            leaves: list,
            selected: _selectedDate != null &&
                _selectedDate!.year == normalized.year &&
                _selectedDate!.month == normalized.month &&
                _selectedDate!.day == normalized.day,
            onTap: () {
              setState(() {
                _selectedDate = normalized;
              });
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
                    const TableRow(
                      children: [
                        _WeekdayLabel('Sun'),
                        _WeekdayLabel('Mon'),
                        _WeekdayLabel('Tue'),
                        _WeekdayLabel('Wed'),
                        _WeekdayLabel('Thu'),
                        _WeekdayLabel('Fri'),
                        _WeekdayLabel('Sat'),
                      ],
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
              label: 'Present',
              color: Color(0xFF22C55E),
            ),
            _LegendChip(
              label: 'Absent',
              color: Color(0xFFEF4444),
            ),
            _LegendChip(
              label: 'Leave',
              color: Color(0xFF60A5FA),
            ),
            _LegendChip(
              label: 'Holiday',
              color: Color(0xFFFACC15),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedDate != null)
          _buildSelectedDateLeaves(context, _selectedDate!),
      ],
    );
  }

  Widget _buildSelectedDateLeaves(BuildContext context, DateTime date) {
    // Find leaves for this date
    final applications = _applications.where((app) {
      final fromStr = app['from_date']?.toString();
      final toStr = app['to_date']?.toString();
      if (fromStr == null) return false;
      try {
        final start = DateTime.parse(fromStr.split(' ').first);
        final end = (toStr == null || toStr.isEmpty)
            ? start
            : DateTime.parse(toStr.split(' ').first);
        // Normalize to date only
        final check = DateTime(date.year, date.month, date.day);
        final s = DateTime(start.year, start.month, start.day);
        final e = DateTime(end.year, end.month, end.day);
        return !check.isBefore(s) && !check.isAfter(e);
      } catch (_) {
        return false;
      }
    }).toList();

    if (applications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: const Text(
          'No leave applications on this day.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final label = DateFormat('dd MMM yyyy').format(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Leaves on $label',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        ...applications.map((item) {
          final type = item['leave_type']?.toString() ?? 'Leave';
          final from = _formatDate(item['from_date']?.toString());
          final to = _formatDate(item['to_date']?.toString());
          final status = item['status']?.toString() ?? 'Applied';

          Color statusColor;
          switch (status) {
            case 'Approved':
              statusColor = Colors.greenAccent;
              break;
            case 'Rejected':
              statusColor = Colors.redAccent;
              break;
            case 'Open':
              statusColor = Colors.orangeAccent;
              break;
            default:
              statusColor = Colors.blueAccent;
          }

          return GlassContainer(
            margin: const EdgeInsets.only(bottom: 8),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.2),
                child: Icon(
                  Icons.event,
                  color: statusColor,
                ),
              ),
              title: Text(type,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('$from → $to',
                  style: const TextStyle(color: Colors.white70)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupApplicationsByDate(
    List<dynamic> applications,
  ) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final raw in applications) {
      final item = raw as Map<String, dynamic>;
      final fromStr = item['from_date']?.toString();
      final toStr = item['to_date']?.toString();
      if (fromStr == null || fromStr.isEmpty) {
        continue;
      }
      try {
        final fromDate = DateTime.parse(fromStr.split(' ').first);
        final toDate = (toStr == null || toStr.isEmpty)
            ? fromDate
            : DateTime.parse(toStr.split(' ').first);
        var current = fromDate;
        while (!current.isAfter(toDate)) {
          final key = DateTime(current.year, current.month, current.day);
          final list = map[key] ?? <Map<String, dynamic>>[];
          list.add(item);
          map[key] = list;
          current = current.add(const Duration(days: 1));
        }
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

  void _openLeaveApplicationForm() {
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
            child: _LeaveApplicationSheet(
              employeeId: employeeId,
              balances: _balances,
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

  Widget _buildBalanceRow({
    required String label,
    required String value,
    bool highlight = false,
    Color? highlightColor,
  }) {
    final theme = Theme.of(context);
    final baseColor =
        theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface;
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
      color: highlight
          ? (highlightColor ?? Colors.green)
          : baseColor.withValues(alpha: 0.9),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: textStyle,
          ),
        ],
      ),
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

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseText =
        theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface;
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
              color: baseText,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveCalendarDay extends StatelessWidget {
  final DateTime date;
  final List<Map<String, dynamic>> leaves;
  final bool selected;
  final VoidCallback onTap;

  const _LeaveCalendarDay({
    required this.date,
    required this.leaves,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseText =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    Color? fill;
    Color border = Colors.transparent;
    Color textColor = baseText;
    if (leaves.isNotEmpty) {
      final anyApproved = leaves.any((e) => e['status'] == 'Approved');
      final anyRejected = leaves.any((e) => e['status'] == 'Rejected');
      final anyPending = leaves.any((e) => e['status'] == 'Open');
      Color base;
      if (anyApproved) {
        base = const Color(0xFF22C55E);
      } else if (anyRejected) {
        base = const Color(0xFFEF4444);
      } else if (anyPending) {
        base = const Color(0xFFF97316);
      } else {
        base = const Color(0xFF3B82F6);
      }
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

class _LeaveApplicationSheet extends StatefulWidget {
  final String employeeId;
  final List<_LeaveBalance> balances;
  final VoidCallback onSubmitted;

  const _LeaveApplicationSheet({
    required this.employeeId,
    required this.balances,
    required this.onSubmitted,
  });

  @override
  State<_LeaveApplicationSheet> createState() => _LeaveApplicationSheetState();
}

class _LeaveApplicationSheetState extends State<_LeaveApplicationSheet> {
  String? _selectedLeaveType;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _halfDay = false;
  DateTime? _halfDayDate;
  bool _includeHolidays = false;
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.balances.isNotEmpty) {
      _selectedLeaveType = widget.balances.first.type;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
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
              surface: Color(0xFF1E293B),
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
    if (_selectedLeaveType == null || _selectedLeaveType!.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please select Leave Type.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
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
    if (_reasonController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter Reason.',
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
        'doctype': 'Leave Application',
        'employee': widget.employeeId,
        'from_date': fromStr,
        'to_date': toStr,
        'leave_type': _selectedLeaveType,
        'half_day': _halfDay,
        'include_holidays': _includeHolidays,
        'description': _reasonController.text.trim(),
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
        msg: 'Leave application submitted.',
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
                  'Apply Leave',
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
            const Text('Leave Type *', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedLeaveType,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: widget.balances
                      .map(
                        (b) => DropdownMenuItem<String>(
                          value: b.type,
                          child: Text(b.type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLeaveType = value;
                    });
                  },
                ),
              ),
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
            const Text('Reason *', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reason for leave',
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
                label: _submitting ? 'Submitting...' : 'Submit Leave',
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

class _LeaveBalance {
  final String type;
  final double allocated;
  final double taken;
  final double remaining;

  const _LeaveBalance({
    required this.type,
    this.allocated = 0,
    this.taken = 0,
    this.remaining = 0,
  });

  _LeaveBalance copyWith({
    String? type,
    double? allocated,
    double? taken,
    double? remaining,
  }) {
    return _LeaveBalance(
      type: type ?? this.type,
      allocated: allocated ?? this.allocated,
      taken: taken ?? this.taken,
      remaining: remaining ?? this.remaining,
    );
  }
}
