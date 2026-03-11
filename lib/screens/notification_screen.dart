import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/frappe_api.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/app_background.dart';

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
                style: const TextStyle(color: Colors.white),
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
        child: Text('No New notifications',
            style: TextStyle(color: Colors.white70)),
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
            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: BorderRadius.circular(16),
              color: Colors.black,
              opacity: 0.4,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
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
                            color: statusColor.withValues(alpha: 0.2),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GlassButton(
                        height: 36,
                        width: 120,
                        onPressed: () {
                          _openDetail(item);
                        },
                        label: 'Read more',
                        color: Colors.blueAccent.withValues(alpha: 0.5),
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
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            'Notifications',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: body,
        ),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> item) {
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
        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom +
                  24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        subject,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                if (dateText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      bodyText.isEmpty ? 'No details available.' : bodyText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
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
