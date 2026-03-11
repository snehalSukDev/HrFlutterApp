import 'package:flutter/material.dart';

import '../services/frappe_api.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/app_background.dart';

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
        'Announcement',
        params: {
          'order_by': 'creation desc',
          'limit_page_length': 50,
        },
        cache: true,
        forceRefresh: refresh,
      );
      setState(() {
        _allAnnouncements = data;
      });
    } catch (e) {
      String errorMessage = e.toString();
      // Remove "Exception: " prefix if present
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.replaceFirst('Exception: ', '');
      }

      // Handle specific PermissionError for Announcements
      if (errorMessage.contains('Permission Error') ||
          errorMessage.contains('PermissionError')) {
        errorMessage =
            'Permission Error: The Employee does not have permission to access Announcements.';
      }

      setState(() {
        _error = errorMessage;
      });
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredAnnouncements() {
    final List<Map<String, dynamic>> base =
        _allAnnouncements.whereType<Map<String, dynamic>>().toList();
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
    final list = _filteredAnnouncements();
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: MainAppBar(
          title: 'Announcements',
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
          child: _buildBody(context, list),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search announcements',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
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
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Status:',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'All',
              selected: _statusFilter == 'All',
              onSelected: () {
                setState(() {
                  _statusFilter = 'All';
                });
              },
            ),
            const Spacer(),
            DropdownButton<String>(
              value: _statusFilter,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
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
        GlassContainer(
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.view_list_outlined,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Announcements',
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
        ),
        const SizedBox(height: 12),
        if (announcements.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: const Center(
              child: const Text(
                'No announcements found.',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          ...announcements.map((item) {
            final subject = item['subject']?.toString() ?? 'Announcement';
            final description = item['description']?.toString() ?? '';
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
              child: GlassContainer(
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.campaign_outlined,
                      color: statusColor,
                    ),
                  ),
                  title: Text(subject,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.white : Colors.white38,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
