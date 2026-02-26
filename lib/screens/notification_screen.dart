import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/frappe_api.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<Map<String, dynamic>> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool refresh = false}) async {
    if (!refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await FrappeApi.callMethod(
        'frappe.desk.doctype.notification_log.notification_log.get_notification_logs',
        args: {
          'cache': true,
          'forceRefresh': refresh,
        },
      );
      final message = res['message'];
      List<dynamic> rawList = const [];
      if (message is Map<String, dynamic>) {
        final candidates = [
          message['notification_logs'],
          message['notifications'],
          message['logs'],
          message['data'],
        ];
        for (final c in candidates) {
          if (c is List) {
            rawList = c;
            break;
          }
        }
      } else if (message is List) {
        rawList = message;
      }
      final list =
          rawList.whereType<Map<String, dynamic>>().toList(growable: false);
      // for (final it in list) {
      // final parsed = _deriveSubjectAndBody(it);
      // final subj = parsed['subject'] ?? '';
      // final body = parsed['body'] ?? '';

      // }
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
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
      return '';
    }
    try {
      final dt = DateTime.parse(value);
      return DateFormat('M/d/yyyy, h:mm:ss a').format(dt);
    } catch (_) {
      return value;
    }
  }

  String _decodeHtmlEntities(String input) {
    var out = input;
    out = out.replaceAll('&nbsp;', ' ');
    out = out.replaceAll('&amp;', '&');
    out = out.replaceAll('&lt;', '<');
    out = out.replaceAll('&gt;', '>');
    out = out.replaceAll('&quot;', '"');
    out = out.replaceAll('&#39;', "'");
    return out;
  }

  String _htmlToPlain(String html) {
    var text = html;
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp('<[^>]*>'), '');
    text = _decodeHtmlEntities(text);
    return text.trim();
  }

  Map<String, String> _deriveSubjectAndBody(Map<String, dynamic> item) {
    String subject =
        (item['subject'] ?? item['email_subject'] ?? item['title'] ?? '')
            .toString()
            .trim();
    // Clean any HTML in subject
    if (subject.isNotEmpty) {
      final plain = _htmlToPlain(subject);
      if (plain.isNotEmpty) {
        subject = plain;
      }
    }
    String html =
        (item['email_content'] ?? item['content'] ?? item['message'] ?? '')
            .toString();
    String body = _htmlToPlain(html);
    if (subject.isEmpty) {
      if (item['document_type'] != null && item['document_name'] != null) {
        subject =
            '${item['document_type']?.toString() ?? ''} ${item['document_name']?.toString() ?? ''}'
                .trim();
      }
    }
    if (subject.isEmpty && body.isNotEmpty) {
      final lines = body.split('\n').where((e) => e.trim().isNotEmpty).toList();
      if (lines.isNotEmpty) {
        final first = lines.first.trim();
        subject = first.length <= 80 ? first : first.substring(0, 80);
        if (lines.length > 1) {
          body = lines.skip(1).join('\n').trim();
        }
      }
    }
    if (subject.isEmpty) {
      subject = 'Notification';
    }
    return {'subject': subject, 'body': body};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    Widget body;
    if (_loading && !_refreshing) {
      body = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_error != null) {
      body = Center(
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
                onPressed: () => _fetchNotifications(refresh: true),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    } else if (_notifications.isEmpty) {
      body = const Center(
        child: Text('No New notifications'),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () {
          setState(() {
            _refreshing = true;
          });
          return _fetchNotifications(refresh: true);
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final item = _notifications[index];
            final parsed = _deriveSubjectAndBody(item);
            final subject = parsed['subject'] ?? 'Notification';
            final body = parsed['body'] ?? '';
            final creation = (item['creation'] ?? '').toString();
            final isReadRaw = item['read'];
            final isRead =
                isReadRaw == 1 || isReadRaw == true || isReadRaw == '1';
            final statusText = isRead ? 'Read' : 'Unread';
            final statusColor = isRead ? Colors.grey : const Color(0xFF1D4ED8);
            final dateText = _formatDate(creation);
            final summary = body;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF111827)
                    : const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead
                      ? Colors.grey.withValues(alpha: 0.4)
                      : const Color.fromARGB(255, 174, 180, 197),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dateText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        dateText,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          _openDetail(item);
                        },
                        child: const Text('Read more'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Notifications',
                  style: titleStyle,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final parsed = _deriveSubjectAndBody(item);
    final subject = (parsed['subject'] ?? 'Notification').toString();
    final bodyText = (parsed['body'] ?? '').toString();
    final creation = (item['creation'] ?? '').toString();
    final dateText = _formatDate(creation);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final localTheme = Theme.of(ctx);
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: localTheme.cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject,
                        style: localTheme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (dateText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateText,
                    style: localTheme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      bodyText.isEmpty ? 'No details available.' : bodyText,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
