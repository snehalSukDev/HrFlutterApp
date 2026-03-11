import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/app_background.dart';

class ExpenseClaimScreen extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;
  final String? userInitials;

  const ExpenseClaimScreen({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
    this.userInitials,
  });

  @override
  State<ExpenseClaimScreen> createState() => _ExpenseClaimScreenState();
}

class _ExpenseClaimScreenState extends State<ExpenseClaimScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<dynamic> _claims = const [];
  String? _employeeId;
  String _statusFilter = 'All';

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
      final filters = [
        ['employee', '=', employeeId],
      ];
      if (_statusFilter != 'All') {
        filters.add(['status', '=', _statusFilter]);
      }
      final params = {
        'filters': jsonEncode(filters),
        'fields': '["*"]',
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
        _claims = data;
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
      return DateFormat('dd MMM yy').format(d);
    } catch (_) {
      return value;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft':
        return Colors.orange.shade700;
      case 'Submitted':
      case 'Under Approval':
        return Colors.blue.shade700;
      case 'Approved':
      case 'Paid':
        return Colors.green.shade700;
      case 'Rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: MainAppBar(
          title: 'Expense Claim',
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
          child: _buildBody(context),
        ),
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
                style: const TextStyle(color: Colors.white),
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
    final claims = _claims;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: GlassContainer(
                height: 48,
                borderRadius: BorderRadius.circular(24),
                child: const Center(
                  child: Text(
                    'My Claims',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GlassButton(
              onPressed: _openNewClaimSheet,
              label: 'New Claim',
              icon: Icons.add,
              width: 140,
              height: 44,
              color:
                  const Color.fromARGB(255, 21, 59, 126).withValues(alpha: 0.3),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Filter:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('All'),
              selectedColor:
                  const Color.fromARGB(255, 65, 99, 158).withValues(alpha: 0.3),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: _statusFilter == 'All' ? Colors.white : Colors.white70,
              ),
              selected: _statusFilter == 'All',
              onSelected: (_) {
                setState(() {
                  _statusFilter = 'All';
                });
                _loadData(refresh: true);
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _statusFilter,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _statusFilter = value;
                    });
                    _loadData(refresh: true);
                  },
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                    DropdownMenuItem(
                        value: 'Submitted', child: Text('Submitted')),
                    DropdownMenuItem(
                        value: 'Approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                    DropdownMenuItem(
                        value: 'Rejected', child: Text('Rejected')),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassContainer(
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
                const Expanded(
                  child: Text(
                    'My Claims List',
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
                    '${claims.length}',
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
        if (claims.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No expense claims found.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          ...claims.map((raw) {
            final item = raw as Map<String, dynamic>;
            final name = item['name']?.toString() ?? '';
            final date = _formatDate(item['expense_date']?.toString() ??
                item['posting_date']?.toString());
            final status = item['status']?.toString() ?? 'Draft';
            final total = item['custom_expense_amount']?.toString() ??
                item['total_claimed_amount']?.toString() ??
                '0.00';
            final currency = item['custom_currency']?.toString() ?? 'INR';
            final color = _statusColor(status);
            return GestureDetector(
              onTap: () {
                _showClaimDetails(item);
              },
              child: GlassContainer(
                margin: const EdgeInsets.only(bottom: 6),
                borderRadius: BorderRadius.circular(10),
                color: Colors.black,
                opacity: 0.5,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          Icons.receipt_long,
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$date • $currency $total',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
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

  void _showClaimDetails(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ExpenseClaimDetailSheet(
          claim: item,
        );
      },
    );
  }

  void _openNewClaimSheet() {
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
            child: _ExpenseClaimFormSheet(
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

class _ExpenseClaimDetailSheet extends StatefulWidget {
  final Map<String, dynamic> claim;

  const _ExpenseClaimDetailSheet({required this.claim});

  @override
  State<_ExpenseClaimDetailSheet> createState() =>
      _ExpenseClaimDetailSheetState();
}

class _ExpenseClaimDetailSheetState extends State<_ExpenseClaimDetailSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _fullClaim;

  @override
  void initState() {
    super.initState();
    _loadFullDetails();
  }

  Future<void> _loadFullDetails() async {
    try {
      final name = widget.claim['name']?.toString();
      if (name == null) {
        throw Exception('Invalid Claim ID');
      }
      final data = await FrappeApi.getResource('Expense Claim', name);
      if (mounted) {
        setState(() {
          _fullClaim = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
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
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return value;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft':
        return Colors.orange.shade700;
      case 'Submitted':
      case 'Under Approval':
        return Colors.blue.shade700;
      case 'Approved':
      case 'Paid':
        return Colors.green.shade700;
      case 'Rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Expense Details',
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
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }
    final claim = _fullClaim ?? widget.claim;
    final name = claim['name']?.toString() ?? '';
    final status = claim['status']?.toString() ?? 'Draft';
    final postingDate = _formatDate(claim['posting_date']?.toString());
    final total = claim['total_claimed_amount']?.toString() ?? '0.00';
    final remarks = claim['custom_remarks']?.toString() ??
        claim['remarks']?.toString() ??
        '';
    final expenses = claim['expenses'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassContainer(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _statusColor(status).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: _statusColor(status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabelValue('Posting Date', postingDate),
                  const SizedBox(height: 8),
                  _buildLabelValue('Total Amount', total),
                  if (remarks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildLabelValue('Remarks', remarks),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Expense Items',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (expenses.isEmpty)
            const Text(
              'No expense items found.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...expenses.map((e) {
              debugPrint("Expense Item: $e");
              final item = e as Map<String, dynamic>;
              final expenseType = item['expense_type']?.toString() ?? '';
              final date = _formatDate(item['expense_date']?.toString());
              final amount = item['amount']?.toString() ??
                  item['amount']?.toString() ??
                  '0.00';
              final currency = item['custom_currency']?.toString() ??
                  item['currency']?.toString() ??
                  'INR';
              final description = item['description']?.toString() ?? '';

              return GlassContainer(
                margin: const EdgeInsets.only(bottom: 12),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              expenseType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '$currency $amount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}

class _ExpenseRowData {
  DateTime? date = DateTime.now();
  String modeOfPayment = 'Cash';
  String currency = 'INR';
  String? type;
  String amount = '';
}

class _ExpenseClaimFormSheet extends StatefulWidget {
  final String employeeId;
  final VoidCallback onSubmitted;

  const _ExpenseClaimFormSheet({
    required this.employeeId,
    required this.onSubmitted,
  });

  @override
  State<_ExpenseClaimFormSheet> createState() => _ExpenseClaimFormSheetState();
}

class _ExpenseClaimFormSheetState extends State<_ExpenseClaimFormSheet> {
  final TextEditingController _remarksController = TextEditingController();
  final List<_ExpenseRowData> _rows = [_ExpenseRowData()];
  bool _submitting = false;
  List<String> _expenseTypes = [];
  List<String> _currencies = [];
  String? _expenseApprover;

  @override
  void initState() {
    super.initState();
    _fetchExpenseTypes();
    _fetchCurrencies();
    _fetchEmployeeDetails();
  }

  Future<void> _fetchEmployeeDetails() async {
    try {
      final employee = await FrappeApi.fetchEmployeeDetails(
        widget.employeeId,
        byEmail: false,
      );
      if (mounted && employee != null) {
        setState(() {
          _expenseApprover = employee['expense_approver']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchExpenseTypes() async {
    try {
      final types = await FrappeApi.getResourceList(
        'Expense Claim Type',
        params: {
          'fields': '["name"]',
          'limit_page_length': '0',
        },
      );
      if (mounted) {
        setState(() {
          _expenseTypes = types.map((e) => e['name'].toString()).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchCurrencies() async {
    try {
      final currencies = await FrappeApi.getResourceList(
        'Currency',
        params: {
          'fields': '["name"]',
          'filters': '[["enabled","=","1"]]',
          'limit_page_length': '0',
        },
      );
      if (mounted) {
        setState(() {
          _currencies = currencies.map((e) => e['name'].toString()).toList();
          // Ensure default 'INR' is in the list, otherwise add it if needed or just rely on API
          if (!_currencies.contains('INR')) {
            _currencies.add('INR');
          }
          _currencies.sort();
        });
      }
    } catch (_) {
      // Fallback if API fails
      if (mounted) {
        setState(() {
          if (!_currencies.contains('INR')) _currencies.add('INR');
        });
      }
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    BuildContext context,
    _ExpenseRowData row,
  ) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: row.date ?? now,
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
      setState(() {
        row.date = picked;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _handleSubmit() async {
    if (_rows.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please add at least one expense row.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    for (final row in _rows) {
      if (row.date == null ||
          row.amount.trim().isEmpty ||
          row.currency.trim().isEmpty ||
          row.type == null ||
          row.type!.trim().isEmpty) {
        Fluttertoast.showToast(
          msg:
              'Please fill Expense Date, Currency, Type and Amount for all rows.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return;
      }
    }
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      final expenses = _rows.map((row) {
        final dateStr = DateFormat('yyyy-MM-dd').format(row.date!);
        return {
          'expense_date': dateStr,
          'custom_mode_of_payment': row.modeOfPayment,
          'custom_currency': row.currency.trim(),
          'expense_type': row.type!.trim(),
          'amount': double.tryParse(row.amount.trim()) ?? 0,
          'custom_expense_amount': double.tryParse(row.amount.trim()) ?? 0,
        };
      }).toList();
      final doc = <String, dynamic>{
        'doctype': 'Expense Claim',
        'employee': widget.employeeId,
        'expense_approver': _expenseApprover,
        'custom_remarks': _remarksController.text.trim(),
        'expenses': expenses,
      };
      debugPrint("Expense Claim Doc: $doc");
      final response = await FrappeApi.callMethod(
        'frappe.client.insert',
        args: {
          'doc': jsonEncode(doc),
        },
      );
      debugPrint("Expense Claim Success: $response");
      Fluttertoast.showToast(
        msg: 'Expense claim submitted.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      widget.onSubmitted();
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      debugPrint("Expense Claim Error: $e");
      Fluttertoast.showToast(
        msg: message,
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        height: MediaQuery.of(context).size.height * 0.85, // Limit height
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Expense Claim',
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Expenses (Details)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        GlassButton(
                          onPressed: () {
                            setState(() {
                              _rows.add(_ExpenseRowData());
                            });
                          },
                          label: 'Add Row',
                          icon: Icons.add,
                          width: 100,
                          height: 32,
                          color: const Color.fromARGB(255, 21, 59, 126)
                              .withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        final rowLabel = 'Row ${index + 1}';
                        return GlassContainer(
                          margin: const EdgeInsets.only(bottom: 12),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      rowLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_rows.length > 1)
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _rows.removeAt(index);
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text('Expense Date',
                                    style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 4),
                                _DateField(
                                  label: _formatDate(row.date),
                                  onTap: () => _pickDate(context, row),
                                ),
                                const SizedBox(height: 12),
                                const Text('Mode of Payment',
                                    style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildChip(
                                      label: 'Cash',
                                      selected: row.modeOfPayment == 'Cash',
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            row.modeOfPayment = 'Cash';
                                          });
                                        }
                                      },
                                    ),
                                    _buildChip(
                                      label: 'Personal Card',
                                      selected:
                                          row.modeOfPayment == 'Personal Card',
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            row.modeOfPayment = 'Personal Card';
                                          });
                                        }
                                      },
                                    ),
                                    _buildChip(
                                      label: 'Corporate Card',
                                      selected:
                                          row.modeOfPayment == 'Corporate Card',
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            row.modeOfPayment =
                                                'Corporate Card';
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text('Currency',
                                    style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _currencies.contains(row.currency)
                                          ? row.currency
                                          : null,
                                      hint: const Text(
                                        'Select Currency',
                                        style: TextStyle(color: Colors.white38),
                                      ),
                                      dropdownColor: const Color(0xFF1E293B),
                                      style:
                                          const TextStyle(color: Colors.white),
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down,
                                          color: Colors.white),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            row.currency = value;
                                          });
                                        }
                                      },
                                      items: _currencies.map((currency) {
                                        return DropdownMenuItem<String>(
                                          value: currency,
                                          child: Text(currency),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text('Expense Claim Type *',
                                    style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: row.type,
                                      hint: const Text(
                                        'Select Type',
                                        style: TextStyle(color: Colors.white38),
                                      ),
                                      dropdownColor: const Color(0xFF1E293B),
                                      style:
                                          const TextStyle(color: Colors.white),
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down,
                                          color: Colors.white),
                                      onChanged: (value) {
                                        setState(() {
                                          row.type = value;
                                        });
                                      },
                                      items: _expenseTypes.map((type) {
                                        return DropdownMenuItem<String>(
                                          value: type,
                                          child: Text(type),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text('Expense Amount *',
                                    style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 4),
                                TextField(
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  onChanged: (value) {
                                    row.amount = value;
                                  },
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Expense Amount',
                                    hintStyle:
                                        const TextStyle(color: Colors.white38),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 0),
                    const Text('Remarks',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _remarksController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Remarks',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        onPressed: _handleSubmit,
                        label: _submitting ? 'Submitting...' : 'Submit Claim',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
      ),
      selected: selected,
      onSelected: onSelected,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final theme = Theme.of(context);
    final isPlaceholder = label == 'Select date';
    final baseColor =
        theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface;
    final placeholderColor = baseColor.withValues(alpha: 0.6);
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPlaceholder ? placeholderColor : baseColor,
          ),
        ),
      ),
    );
  }
}
