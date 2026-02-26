import 'package:flutter/material.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';

class AnnouncementScreen extends StatefulWidget {
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final Future<void> Function() onLogout;
  final String? userInitials;

  const AnnouncementScreen({
    super.key,
    required this.currentUserEmail,
    required this.currentEmployeeId,
    required this.onLogout,
    this.userInitials,
  });

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<dynamic> _allAnnouncements = const [];
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (!refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await FrappeApi.getResourceList(
        'HR Announcement',
        params: {
          'order_by': 'creation desc',
          'limit_page_length': '50',
        },
        cache: true,
        forceRefresh: refresh,
      );
      setState(() {
        _allAnnouncements = data;
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

  List<Map<String, dynamic>> _filteredAnnouncements() {
    final List<Map<String, dynamic>> base = _allAnnouncements
        .whereType<Map<String, dynamic>>()
        .toList();
    final query = _searchQuery.trim().toLowerCase();
    return base.where((item) {
      final status = item['status']?.toString() ?? '';
      if (_statusFilter != 'All' && status != _statusFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final subject = item['subject']?.toString().toLowerCase() ?? '';
      final message = item['description']?.toString().toLowerCase() ?? '';
      return subject.contains(query) || message.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = _filteredAnnouncements();
    return Scaffold(
      appBar: MainAppBar(
        title: 'Announcement',
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
        child: _buildBody(context, theme, list),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> announcements,
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
                onPressed: () => _loadData(refresh: true),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: const InputDecoration(
            hintText: 'Search announcements',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Status:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('All'),
              selected: _statusFilter == 'All',
              onSelected: (_) {
                setState(() {
                  _statusFilter = 'All';
                });
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
                  value: 'Published',
                  child: Text('Published'),
                ),
                DropdownMenuItem(
                  value: 'Expired',
                  child: Text('Expired'),
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
                Icons.view_list_outlined,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Announcements',
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
                  '${announcements.length}',
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
        if (announcements.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No announcements found.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.7),
                ),
              ),
            ),
          )
        else
          ...announcements.map((item) {
            final subject = item['subject']?.toString() ?? 'Announcement';
            final description =
                item['description']?.toString() ?? '';
            final status = item['status']?.toString() ?? 'Draft';
            Color statusColor;
            switch (status) {
              case 'Published':
                statusColor = Colors.green.shade700;
                break;
              case 'Expired':
                statusColor = Colors.orange.shade700;
                break;
              case 'Draft':
                statusColor = Colors.blue.shade700;
                break;
              default:
                statusColor = Colors.grey.shade700;
            }
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
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.campaign_outlined,
                      color: statusColor,
                    ),
                  ),
                  title: Text(subject),
                  subtitle: Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
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
                ),
              ),
            );
          }),
      ],
    );
  }
}
