import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/app_background.dart';
import '../widgets/glass/glass_button.dart';

class SalarySlipScreen extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;
  final String? userInitials;

  const SalarySlipScreen({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
    this.userInitials,
  });

  @override
  State<SalarySlipScreen> createState() => _SalarySlipScreenState();
}

class _SalarySlipScreenState extends State<SalarySlipScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<dynamic> _slips = const [];

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
        'start_date',
        'end_date',
        'status',
        'net_pay',
        'gross_pay',
        'currency',
      ]);
      final data = await FrappeApi.getResourceList(
        'Salary Slip',
        params: {
          'filters': filters,
          'fields': fields,
          'order_by': 'start_date desc',
          'limit_page_length': 50,
        },
        cache: true,
        forceRefresh: refresh,
      );
      setState(() {
        _slips = data;
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
      return DateFormat('MMM d, y').format(d);
    } catch (_) {
      return value;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Draft':
        return Colors.orange.shade700;
      case 'Submitted':
        return Colors.blue.shade700;
      case 'Paid':
        return Colors.green.shade700;
      case 'Cancelled':
        return Colors.red.shade700;
      case 'Unpaid':
        return Colors.red.shade700;
      case 'Overdue':
        return Colors.pink.shade700;
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
          title: 'Payslips',
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
    if (_slips.isEmpty) {
      return const Center(
        child: Text('No salary slips found.',
            style: TextStyle(color: Colors.white70)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _slips.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassContainer(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
              opacity: 0.2,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.list_alt,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Salary List',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_slips.length}',
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
          );
        }
        final item = _slips[index - 1] as Map<String, dynamic>;
        final period =
            '${_formatDate(item['start_date']?.toString())} → ${_formatDate(item['end_date']?.toString())}';
        final status = item['status']?.toString() ?? '';
        final currency = item['currency']?.toString() ?? '';
        final netPay = (item['net_pay'] ?? '').toString();
        final statusColor = _getStatusColor(status);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
            opacity: 0.5,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final name = item['name']?.toString();
                if (name != null && name.isNotEmpty) {
                  _showSalarySlipModal(context, name);
                }
              },
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
                        Icons.receipt_long,
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
                            period,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$currency $netPay',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['name']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSalarySlipModal(BuildContext context, String slipName) {
    // Find the slip details from _slips list
    final slip = _slips.firstWhere(
      (s) => s['name'] == slipName,
      orElse: () => null,
    );

    if (slip == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(16),
          color: const Color.fromARGB(255, 28, 12, 67),
          opacity: 0.5,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Salary Slip',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('ID', slip['name']?.toString() ?? ''),
                _buildDetailRow('Employee', widget.currentUserEmail ?? ''),
                _buildDetailRow(
                  'Period',
                  '${_formatDate(slip['start_date']?.toString())} - ${_formatDate(slip['end_date']?.toString())}',
                ),
                _buildDetailRow(
                  'Gross Pay',
                  '${slip['currency'] ?? ''} ${slip['gross_pay'] ?? '0.00'}',
                ),
                _buildDetailRow(
                  'Net Pay',
                  '${slip['currency'] ?? ''} ${slip['net_pay'] ?? '0.00'}',
                ),
                _buildDetailRow('Status', slip['status']?.toString() ?? ''),
                const Spacer(),
                // Action buttons (similar to React Native)
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        onPressed: () => _handleShare(slipName),
                        icon: Icons.share,
                        label: 'Share',
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassButton(
                        onPressed: () => _handleGetPdf(slipName),
                        icon: Icons.picture_as_pdf,
                        label: 'PDF',
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showWebViewModal(this.context, slipName);
                    },
                    icon: Icons.visibility,
                    label: 'View Slip',
                    color: Colors.blueAccent.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showWebViewModal(BuildContext context, String slipName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (context) => _SalarySlipViewer(slipName: slipName),
    );
  }

  Future<void> _handleShare(String slipName) async {
    final baseUrl = FrappeApi.baseUrl;
    final uri =
        Uri.parse('$baseUrl/api/method/frappe.utils.print_format.download_pdf')
            .replace(
      queryParameters: {
        'doctype': 'Salary Slip',
        'name': slipName,
        'format': 'Standard',
      },
    );

    try {
      final dio = Dio();
      final cookieHeader = FrappeApi.cookieHeader;

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/salary_slip_$slipName.pdf';

      await dio.download(
        uri.toString(),
        filePath,
        options: Options(
          headers: cookieHeader != null ? {'Cookie': cookieHeader} : {},
        ),
      );

      // Share the file using share_plus
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Salary Slip $slipName',
        text: 'Please find attached salary slip $slipName',
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error sharing PDF: ${e.toString()}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      debugPrint('Share Error: $e');
    }
  }

  Future<void> _handleGetPdf(String slipName) async {
    final baseUrl = FrappeApi.baseUrl;

    // First try to get attachment URL if available
    final attachmentUrl = await _getAttachmentUrl(slipName);

    try {
      final dio = Dio();
      final cookieHeader = FrappeApi.cookieHeader;
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/salary_slip_$slipName.pdf';

      if (attachmentUrl != null) {
        // Download from attachment URL
        await dio.download(
          attachmentUrl,
          filePath,
          options: Options(
            headers: cookieHeader != null ? {'Cookie': cookieHeader} : {},
          ),
        );
      } else {
        // Use Frappe's PDF generation API
        final uri = Uri.parse(
                '$baseUrl/api/method/frappe.utils.print_format.download_pdf')
            .replace(
          queryParameters: {
            'doctype': 'Salary Slip',
            'name': slipName,
            'format': 'Standard',
          },
        );

        await dio.download(
          uri.toString(),
          filePath,
          options: Options(
            headers: cookieHeader != null ? {'Cookie': cookieHeader} : {},
          ),
        );
      }

      // Show success toast
      Fluttertoast.showToast(
        msg: 'PDF downloaded successfully',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      // Open the file directly without any sharing functionality
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        Fluttertoast.showToast(
          msg: 'Error opening file: ${result.message}',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error downloading PDF: ${e.toString()}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      debugPrint('PDF Download Error: $e');
    }
  }

  Future<String?> _getAttachmentUrl(String slipName) async {
    try {
      final res = await FrappeApi.callMethod(
        'frappe.desk.form.load.get_docinfo',
        args: {
          'doctype': 'Salary Slip',
          'name': slipName,
        },
      );

      final docinfo = res['docinfo'] ?? res['message']?['docinfo'];
      if (docinfo != null) {
        final files = docinfo['attachments'] ??
            docinfo['attachment'] ??
            docinfo['files'] ??
            [];
        if (files.isNotEmpty) {
          final firstFile = files.first;
          final url = firstFile['file_url'] ??
              firstFile['filepath'] ??
              firstFile['url'];
          if (url != null) {
            final baseUrl = FrappeApi.baseUrl;
            if (url.startsWith('http')) {
              return url;
            } else {
              return '$baseUrl$url';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting attachment URL: $e');
    }
    return null;
  }
}

class _SalarySlipViewer extends StatefulWidget {
  final String slipName;

  const _SalarySlipViewer({required this.slipName});

  @override
  State<_SalarySlipViewer> createState() => _SalarySlipViewerState();
}

class _SalarySlipViewerState extends State<_SalarySlipViewer> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final baseUrl = FrappeApi.baseUrl;
    final uri = Uri.parse('$baseUrl/printview').replace(
      queryParameters: {
        'doctype': 'Salary Slip',
        'name': widget.slipName,
        'format': 'Standard',
      },
    );
    final url = uri.toString();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      );

    _loadContent(baseUrl, url);
  }

  Future<void> _loadContent(String baseUrl, String url) async {
    final cookieHeader = FrappeApi.cookieHeader;
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      final uri = Uri.parse(baseUrl);
      final domain = uri.host;
      final cookies = cookieHeader.split(';');
      for (final c in cookies) {
        final parts = c.trim().split('=');
        if (parts.length >= 2) {
          final key = parts[0];
          final value = parts.sublist(1).join('=');
          try {
            await WebViewCookieManager().setCookie(
              WebViewCookie(
                name: key,
                value: value,
                domain: domain,
                path: '/',
              ),
            );
          } catch (e) {
            debugPrint('Error setting cookie: $e');
          }
        }
      }
    }

    await _controller.loadRequest(
      Uri.parse(url),
      headers: cookieHeader != null ? {'Cookie': cookieHeader} : {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      body: SafeArea(
        child: Column(
          children: [
            // Header with close button (similar to React Native)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Salary Slip View',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ),
            // WebView content (similar to React Native)
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(
                    controller: _controller,
                    gestureRecognizers: {
                      Factory<VerticalDragGestureRecognizer>(
                        () => VerticalDragGestureRecognizer(),
                      ),
                    },
                  ),
                  if (_isLoading)
                    Container(
                      color: Colors.white.withValues(alpha: 0.8),
                      child: const Center(
                        child: CircularProgressIndicator(),
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
