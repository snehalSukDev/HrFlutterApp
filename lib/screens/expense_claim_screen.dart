import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: MainAppBar(
        title: 'Expense Claim',
        onLogout: widget.onLogout,
        userInitials: widget.userInitials ?? widget.currentUserEmail,
        currentUserEmail: widget.currentUserEmail,
        currentEmployeeId: widget.currentEmployeeId,
        showBack: true,
      ),
      body: RefreshIndicator(
        onRefresh: () {
          setState(() {
            _refreshing = true;
          });
          return _loadData(refresh: true);
        },
        child: _buildBody(context, theme),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
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
    final claims = _claims;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF271085),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'My Claims',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _openNewClaimSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF271085),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              icon: const Icon(
                Icons.add,
                size: 20,
              ),
              label: const Text('New Claim'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Filter:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('All'),
              selectedColor: const Color.fromARGB(255, 211, 209, 209),
              selected: _statusFilter == 'All',
              onSelected: (_) {
                setState(() {
                  _statusFilter = 'All';
                });
                _loadData(refresh: true);
              },
            ),
            const Spacer(),
            DropdownButton<String>(
              value: _statusFilter,
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
                DropdownMenuItem(
                  value: 'All',
                  child: Text('All'),
                ),
                DropdownMenuItem(
                  value: 'Draft',
                  child: Text('Draft'),
                ),
                DropdownMenuItem(
                  value: 'Submitted',
                  child: Text('Submitted'),
                ),
                DropdownMenuItem(
                  value: 'Approved',
                  child: Text('Approved'),
                ),
                DropdownMenuItem(
                  value: 'Paid',
                  child: Text('Paid'),
                ),
                DropdownMenuItem(
                  value: 'Rejected',
                  child: Text('Rejected'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.list_alt,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'My Claims List',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF271085),
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
        const SizedBox(height: 12),
        if (claims.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No expense claims found.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ),
          )
        else
          ...claims.map((raw) {
            final item = raw as Map<String, dynamic>;
            final name = item['name']?.toString() ?? 'Expense Claim';
            final date = _formatDate(item['posting_date']?.toString());
            final currency = item['currency']?.toString() ?? '';
            final total =
                (item['grand_total'] ?? item['total_amount'] ?? 0).toString();
            final status = item['status']?.toString() ?? 'Draft';
            final statusColor = _statusColor(status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color.fromARGB(255, 43, 26, 26)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surface,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: theme.iconTheme.color,
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
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
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
                            '$currency $total',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
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

class _ExpenseRowData {
  DateTime? date;
  String modeOfPayment = 'Cash';
  String currency = '';
  String type = '';
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
          row.currency.trim().isEmpty) {
        Fluttertoast.showToast(
          msg: 'Please fill Expense Date, Currency and Amount for all rows.',
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
          'mode_of_payment': row.modeOfPayment,
          'currency': row.currency.trim(),
          'expense_type': row.type.trim(),
          'amount': double.tryParse(row.amount.trim()) ?? 0,
        };
      }).toList();
      final doc = <String, dynamic>{
        'doctype': 'Expense Claim',
        'employee': widget.employeeId,
        'remarks': _remarksController.text.trim(),
        'expenses': expenses,
      };
      await FrappeApi.callMethod(
        'frappe.client.insert',
        args: {
          'doc': jsonEncode(doc),
        },
      );
      Fluttertoast.showToast(
        msg: 'Expense claim submitted.',
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
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Expense Claim',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Remarks',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _remarksController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Remarks',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Expenses (Expense Claim Detail)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _rows.add(_ExpenseRowData());
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Add Row'),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final row = _rows[index];
                final rowLabel = 'Row ${index + 1}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            rowLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
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
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expense Date',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      _DateField(
                        label: _formatDate(row.date),
                        onTap: () => _pickDate(context, row),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Mode of Payment',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Cash'),
                            selectedColor:
                                const Color.fromARGB(255, 211, 209, 209),
                            selected: row.modeOfPayment == 'Cash',
                            onSelected: (_) {
                              setState(() {
                                row.modeOfPayment = 'Cash';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Personal Card'),
                            selectedColor:
                                const Color.fromARGB(255, 211, 209, 209),
                            selected: row.modeOfPayment == 'Personal Card',
                            onSelected: (_) {
                              setState(() {
                                row.modeOfPayment = 'Personal Card';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Corporate Card'),
                            selectedColor:
                                const Color.fromARGB(255, 211, 209, 209),
                            selected: row.modeOfPayment == 'Corporate Card',
                            onSelected: (_) {
                              setState(() {
                                row.modeOfPayment = 'Corporate Card';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Currency',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        onChanged: (value) {
                          row.currency = value;
                        },
                        decoration: const InputDecoration(
                          hintText: 'Currency',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Expense Claim Type *',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        onChanged: (value) {
                          row.type = value;
                        },
                        decoration: const InputDecoration(
                          hintText: 'Expense Claim Type',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Expense Amount *',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (value) {
                          row.amount = value;
                        },
                        decoration: const InputDecoration(
                          hintText: 'Expense Amount',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
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
