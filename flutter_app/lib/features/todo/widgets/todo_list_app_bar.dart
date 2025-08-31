import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../auth/providers/auth_provider.dart';

/// Widget responsible for building and displaying the AppBar for the TodoListScreen.
/// Displays user information and provides sign-out functionality.
class TodoListAppBar extends ConsumerWidget {
  final VoidCallback? onSignOut;

  const TodoListAppBar({this.onSignOut, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return AppBar(
      backgroundColor: AppColors.scaffoldBg,
      elevation: 0,
      title: Text(
        'BETAFLOW List', // Changed app name
        style: TextStyle(
          color: AppColors.lightGray,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (authState.hasValue && authState.value!.isAuthenticated) ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      authState.value!.userName,
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      authState.value!.email,
                      style: TextStyle(
                        color: AppColors.lightGray.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.brightYellow.withValues(
                      alpha: 0.2,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 18,
                      color: AppColors.brightYellow,
                    ),
                  ),
                  color: AppColors.cardBg,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(
                            Icons.logout,
                            color: AppColors.lightGray,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sign Out',
                            style: TextStyle(color: AppColors.lightGray),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) =>
                      _handleMenuSelection(context, ref, value),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleMenuSelection(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    if (value == 'logout') {
      final shouldLogout = await AppDialogs.showSignOutDialog(context: context);

      if (shouldLogout == true && context.mounted) {
        try {
          await ref.read(authProvider.notifier).signOut();
          onSignOut?.call();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to sign out. Please try again.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    }
  }
}
