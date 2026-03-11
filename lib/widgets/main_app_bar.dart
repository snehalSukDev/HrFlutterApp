import 'dart:ui';
import 'package:flutter/material.dart';

import '../screens/notification_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/glass/glass_container.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.1),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleSpacing: (showBack || canPop) ? 0 : NavigationToolbar.kMiddleSpacing,
            leading: showBack
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: isDark ? Colors.white : Colors.black, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
            title: Row(
              children: [
                if (!showBack) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/techbirdicon.png',
                      height: 24,
                      width: 24,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            actions: [
              // IconButton(
              //   icon: Icon(
              //     isDark ? Icons.light_mode : Icons.dark_mode,
              //     color: isDark ? Colors.white : Colors.black,
              //   ),
              //   onPressed: () => themeNotifier.toggleTheme(),
              // ),
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    color: isDark ? Colors.white : Colors.black),
                onPressed: () => _showNotifications(context),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showProfile(context),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.8),
                  child: Text(
                    userInitials?.toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        color: const Color(0xFF0F172A),
        opacity: 0.9,
        blur: 20,
        height: MediaQuery.of(context).size.height * 0.8,
        child: const NotificationScreen(),
      ),
    );
  }

  void _showProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        color: const Color(0xFF0F172A),
        opacity: 0.9,
        blur: 20,
        height: MediaQuery.of(context).size.height * 0.9,
        child: ProfileScreen(
          currentUserEmail: currentUserEmail,
          currentEmployeeId: currentEmployeeId,
          userInitials: userInitials,
          onLogout: () async {
            if (onLogout != null) {
              await onLogout!();
            }
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
            }
          },
        ),
      ),
    );
  }
}
