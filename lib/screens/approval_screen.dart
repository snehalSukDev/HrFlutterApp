import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/app_background.dart';

class ApprovalScreen extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;
  final String? userInitials;

  const ApprovalScreen({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
    this.userInitials,
  });

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  String _docTypeTab = 'expense';

  String _expenseStatus = 'Pending';
  String _expenseSearch = '';
  List<dynamic> _claimsToApprove = const [];

  String _leaveStatus = 'all';
  String _leaveSearch = '';
  List<dynamic> _leaveList = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (_docTypeTab == 'expense') {
      await _fetchExpenseApprovals(refresh: refresh);
    } else {
      await _fetchLeaveApprovals(refresh: refresh);
    }
  }

  Future<void> _fetchExpenseApprovals({bool refresh = false}) async {
    final employeeId = widget.currentEmployeeId?.trim();
    if (employeeId == null || employeeId.isEmpty) {
      setState(() {
        _loading = false;
        _refreshing = false;
        _error =
            'Employee ID not available. Please ensure your profile is complete.';
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
      final filters = <List<dynamic>>[
        ['expense_approver', '=', employeeId],
      ];
      if (_expenseStatus.isNotEmpty && _expenseStatus != 'All') {
        filters.add(['approval_status', '=', _expenseStatus]);
      }
      if (_expenseSearch.trim().isNotEmpty) {
        filters.add([
          'employee_name',
          'like',
          '%${_expenseSearch.trim()}%',
        ]);
      }
      final params = <String, dynamic>{
        'filters': jsonEncode(filters),
        'fields': jsonEncode([
          'name',
          'employee_name',
          'posting_date',
          'total_claimed_amount',
          'approval_status',
        ]),
        'order_by': 'posting_date desc',
        'limit_page_length': '50',
      };
      final data = await FrappeApi.getResourceList(
        'Expense Claim',
        params: params,
        cache: true,
        forceRefresh: refresh,
      );
      setState(() {
        _claimsToApprove = data;
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

  Future<void> _fetchLeaveApprovals({bool refresh = false}) async {
    final email = widget.currentUserEmail?.trim();
    if (email == null || email.isEmpty) {
      setState(() {
        _loading = false;
        _refreshing = false;
        _error =
            'User email not available. Please ensure your profile is complete.';
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
      final filters = <List<dynamic>>[
        ['leave_approver', '=', email],
      ];
      if (_leaveStatus == 'Approved') {
        filters.add(['status', '=', 'Approved']);
      } else if (_leaveStatus == 'Rejected') {
        filters.add(['status', '=', 'Rejected']);
      } else if (_leaveStatus == 'Open') {
        filters.add(['docstatus', '=', 0]);
      }
      if (_leaveSearch.trim().isNotEmpty) {
        filters.add([
          'employee_name',
          'like',
          '%${_leaveSearch.trim()}%',
        ]);
      }
      final params = <String, dynamic>{
        'filters': jsonEncode(filters),
        'fields': jsonEncode([
          'name',
          'employee_name',
          'leave_type',
          'status',
          'total_leave_days',
          'from_date',
          'to_date',
          'description',
          'posting_date',
          'docstatus',
        ]),
        'order_by': 'modified desc',
        'limit_page_length': '50',
        'as_dict': '1',
      };
      final data = await FrappeApi.getResourceList(
        'Leave Application',
        params: params,
        cache: true,
        forceRefresh: refresh,
      );
      setState(() {
        _leaveList = data;
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
      final raw = value.split(' ').first;
      final d = DateTime.parse(raw);
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      final year = d.year.toString().substring(2);
      return '$day-$month-$year';
    } catch (_) {
      return value;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'Draft':
        return const Color(0xFFE0F2F1);
      case 'Submitted':
      case 'Pending':
      case 'Open':
        return const Color(0xFFFFF3E0);
      case 'Cancelled':
      case 'Rejected':
      case 'Unpaid':
        return const Color(0xFFFFEBEE);
      case 'Paid':
      case 'Approved':
        return const Color(0xFFE8F5E9);
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'Draft':
        return const Color(0xFF00695C);
      case 'Submitted':
      case 'Pending':
      case 'Open':
        return const Color(0xFFEF6C00);
      case 'Cancelled':
      case 'Rejected':
      case 'Unpaid':
        return const Color(0xFFC62828);
      case 'Paid':
      case 'Approved':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey.shade800;
    }
  }

  Future<void> _changeExpenseStatus(
    Map<String, dynamic> item,
    String nextStatus,
  ) async {
    try {
      final doc = {
        'doctype': 'Expense Claim',
        'name': item['name'],
        'approval_status': nextStatus,
      };
      await FrappeApi.callMethod(
        'frappe.desk.form.save.savedocs',
        args: {
          'doc': jsonEncode(doc),
          'action': 'Save',
        },
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense $nextStatus'),
        ),
      );
      await _fetchExpenseApprovals(refresh: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update expense status'),
        ),
      );
    }
  }

  Future<void> _changeLeaveStatus(
    Map<String, dynamic> item,
    String nextStatus,
  ) async {
    try {
      final doc = {
        'doctype': 'Leave Application',
        'name': item['name'],
        'status': nextStatus,
      };
      await FrappeApi.callMethod(
        'frappe.desk.form.save.savedocs',
        args: {
          'doc': jsonEncode(doc),
          'action': 'Save',
        },
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave status updated'),
        ),
      );
      await _fetchLeaveApprovals(refresh: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update leave status'),
        ),
      );
    }
  }

  void _openExpenseDetail(Map<String, dynamic> item) {
    final status = item['approval_status']?.toString().isNotEmpty == true
        ? item['approval_status'].toString()
        : 'Draft';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Expense Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Employee',
                  value: item['employee_name']?.toString() ?? '',
                ),
                _InfoRow(
                  label: 'Amount',
                  value: '₹ ${(item['total_claimed_amount'] ?? 0).toString()}',
                ),
                _InfoRow(
                  label: 'Date',
                  value: _formatDate(item['posting_date']?.toString()),
                ),
                _InfoRow(
                  label: 'Status',
                  value: status,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        onPressed: () {
                          _changeExpenseStatus(item, 'Rejected');
                        },
                        label: 'Reject',
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassButton(
                        onPressed: () {
                          _changeExpenseStatus(item, 'Approved');
                        },
                        label: 'Approve',
                        color: Colors.greenAccent.withValues(alpha: 0.5),
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

  void _openLeaveDetail(Map<String, dynamic> item) {
    final status = (item['status']?.toString() ?? '').isEmpty ||
            item['status'] == 'Open' ||
            item['docstatus'] == 0
        ? 'Pending'
        : item['status'].toString();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Leave Application',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Employee',
                  value: item['employee_name']?.toString() ?? '',
                ),
                _InfoRow(
                  label: 'Period',
                  value:
                      '${_formatDate(item['from_date']?.toString())} - ${_formatDate(item['to_date']?.toString())}',
                ),
                _InfoRow(
                  label: 'Days',
                  value: (item['total_leave_days'] ?? 0).toString(),
                ),
                _InfoRow(
                  label: 'Type',
                  value: item['leave_type']?.toString() ?? '',
                ),
                _InfoRow(
                  label: 'Status',
                  value: status,
                ),
                _InfoRow(
                  label: 'Reason',
                  value: item['description']?.toString() ?? '',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        onPressed: () {
                          _changeLeaveStatus(item, 'Rejected');
                        },
                        label: 'Reject',
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassButton(
                        onPressed: () {
                          _changeLeaveStatus(item, 'Approved');
                        },
                        label: 'Approve',
                        color: Colors.greenAccent.withValues(alpha: 0.5),
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
    final theme = Theme.of(context);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: MainAppBar(
          title: 'Approvals',
          onLogout: widget.onLogout,
          userInitials: widget.userInitials,
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
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
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
    if (_docTypeTab == 'expense') {
      return _buildExpenseBody(theme);
    }
    return _buildLeaveBody(theme);
  }

  Widget _buildToggleRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_docTypeTab == 'expense') {
                return;
              }
              setState(() {
                _docTypeTab = 'expense';
                _error = null;
              });
              _loadData(refresh: true);
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _docTypeTab == 'expense'
                    ? Colors.blueAccent
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                'Expense',
                style: TextStyle(
                  color:
                      _docTypeTab == 'expense' ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_docTypeTab == 'leave') {
                return;
              }
              setState(() {
                _docTypeTab = 'leave';
                _error = null;
              });
              _loadData(refresh: true);
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _docTypeTab == 'leave'
                    ? Colors.blueAccent
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                'Leave',
                style: TextStyle(
                  color: _docTypeTab == 'leave' ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBar({
    required ThemeData theme,
    required String title,
    required int count,
  }) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(12),
      color: Colors.black,
      opacity: 0.2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.list_alt,
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }

  Widget _buildExpenseBody(ThemeData theme) {
    final items = _claimsToApprove;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToggleRow(theme),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Filter:',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final opt in [
                  'All',
                  'Pending',
                  'Approved',
                  'Rejected',
                ])
                  ChoiceChip(
                    label: Text(opt),
                    selected: _expenseStatus == opt,
                    selectedColor: Colors.blueAccent,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color:
                          _expenseStatus == opt ? Colors.white : Colors.white70,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) {
                      setState(() {
                        _expenseStatus = opt;
                      });
                      _loadData(refresh: true);
                    },
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search Employee...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _expenseSearch = value;
            });
          },
          onSubmitted: (_) {
            _loadData(refresh: true);
          },
        ),
        const SizedBox(height: 16),
        _buildHeaderBar(
          theme: theme,
          title: 'Pending Approvals',
          count: items.length,
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No pending approvals.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          ...items.map((raw) {
            final item = raw as Map<String, dynamic>;
            final name = item['employee_name']?.toString() ??
                item['name']?.toString() ??
                '';
            final date = _formatDate(item['posting_date']?.toString());
            final amount = (item['total_claimed_amount'] ?? 0).toString();
            final statusRaw =
                item['approval_status']?.toString().isNotEmpty == true
                    ? item['approval_status'].toString()
                    : 'Draft';
            final bg = _statusBackground(statusRaw);
            final textColor = _statusTextColor(statusRaw);
            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 8),
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
              opacity: 0.5,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _openExpenseDetail(item);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
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
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
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
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹ $amount',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: bg.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusRaw,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildLeaveBody(ThemeData theme) {
    final items = _leaveList;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToggleRow(theme),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Filter:',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final opt in const [
                  {'label': 'All', 'value': 'all'},
                  {'label': 'Pending', 'value': 'Open'},
                  {'label': 'Approved', 'value': 'Approved'},
                  {'label': 'Rejected', 'value': 'Rejected'},
                ])
                  ChoiceChip(
                    label: Text(opt['label']!),
                    selected: _leaveStatus == opt['value'],
                    selectedColor: Colors.blueAccent,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: _leaveStatus == opt['value']
                          ? Colors.white
                          : Colors.white70,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) {
                      setState(() {
                        _leaveStatus = opt['value']!;
                      });
                      _loadData(refresh: true);
                    },
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search Employee...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _leaveSearch = value;
            });
          },
          onSubmitted: (_) {
            _loadData(refresh: true);
          },
        ),
        const SizedBox(height: 16),
        _buildHeaderBar(
          theme: theme,
          title: 'Leave Approvals',
          count: items.length,
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No pending leaves.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          ...items.map((raw) {
            final item = raw as Map<String, dynamic>;
            final name = item['employee_name']?.toString() ??
                item['name']?.toString() ??
                '';
            final from = _formatDate(item['from_date']?.toString());
            final to = _formatDate(item['to_date']?.toString());
            final type = item['leave_type']?.toString() ?? 'Leave';
            final statusRaw = (item['status']?.toString() ?? '').isEmpty ||
                    item['status'] == 'Open' ||
                    item['docstatus'] == 0
                ? 'Pending'
                : item['status'].toString();
            final bg = _statusBackground(statusRaw);
            final textColor = _statusTextColor(statusRaw);
            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 8),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _openLeaveDetail(item);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                        child: const Icon(
                          Icons.date_range,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$type • $from -> $to',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: bg.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusRaw,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
