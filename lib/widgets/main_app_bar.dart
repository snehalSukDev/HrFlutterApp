import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/notification_screen.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Future<void> Function()? onLogout;
  final String? userInitials;
  final String? currentUserEmail;
  final String? currentEmployeeId;
  final bool showBack;

  const MainAppBar({
    super.key,
    required this.title,
    this.onLogout,
    this.userInitials,
    this.currentUserEmail,
    this.currentEmployeeId,
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = context.watch<ThemeNotifier>();
    final colors = notifier.colors;
    final isDark = notifier.isDark;

    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            )
          : null,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 8, right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/techbirdicon.png',
              height: 24,
              width: 24,
              fit: BoxFit.contain,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
          onPressed: notifier.toggleTheme,
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) {
                return FractionallySizedBox(
                  heightFactor: 0.8,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).cardColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: const NotificationScreen(),
                  ),
                );
              },
            );
          },
          icon: const Icon(Icons.notifications_none_outlined),
        ),
        if (onLogout != null)
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              showDialog<void>(
                context: context,
                barrierDismissible: true,
                builder: (ctx) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Logout'),
                    content: const Text(
                      'Are you sure you want to log out?',
                    ),
                    actionsPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await onLogout?.call();
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.power_settings_new),
          ),
        if (userInitials != null && userInitials!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (currentUserEmail != null || currentEmployeeId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfileScreen(
                        currentUserEmail: currentUserEmail,
                        currentEmployeeId: currentEmployeeId,
                        onLogout: onLogout ?? () async {},
                        userInitials: userInitials,
                      ),
                    ),
                  );
                }
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color.fromARGB(255, 43, 26, 26)
                    : colors.primary.withValues(alpha: 0.12),
                child: Text(
                  userInitials!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
