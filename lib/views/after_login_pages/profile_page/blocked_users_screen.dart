import 'package:catch_watch/models/block_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/block_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/block_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BlockProvider>().fetchBlockedUsers();
      }
    });
  }

  Future<void> _handleUnblock(
    BuildContext context,
    BlockedUser user,
    BlockProvider provider,
  ) async {
    if (provider.isOperationInProgress(user.id)) return;

    String? backendMessage;
    final bool? confirmed = await showUnblockConfirmationDialog(
      context: context,
      userId: user.id,
      username: user.username,
      name: user.name,
      onConfirmUnblock: () async {
        try {
          final res = await provider.unblockUser(user.id);
          backendMessage = res?.message ?? 'User unblocked successfully.';
          return res != null && res.success;
        } catch (e) {
          final msg = e.toString().replaceAll('Exception: ', '');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return false;
        }
      },
    );

    if (confirmed == true && mounted) {
      context.read<ReelsProvider>().onUserUnblocked(user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(backendMessage ?? 'User unblocked successfully.'),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          'Blocked Users',
          style: text18(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<BlockProvider>(
        builder: (context, provider, _) {
          // 1. Initial Loading State
          if (provider.isLoadingBlockedUsers && provider.blockedUsers.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // 2. Fetch Failure / Retry State
          if (provider.blockedUsersError != null && provider.blockedUsers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load blocked users',
                      style: text16(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.blockedUsersError!,
                      textAlign: TextAlign.center,
                      style: text14(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchBlockedUsers(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // 3. Empty State
          if (provider.blockedUsers.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => provider.fetchBlockedUsers(forceRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.grey100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.block_rounded,
                                size: 48,
                                color: AppColors.grey400,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "You haven't blocked anyone yet",
                              textAlign: TextAlign.center,
                              style: text16(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'When you block someone, they won\'t be able to see your content or interact with you, and they will appear here.',
                              textAlign: TextAlign.center,
                              style: text14(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 4. Blocked Users List
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => provider.fetchBlockedUsers(forceRefresh: true),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.blockedUsers.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.grey200,
                indent: 72,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final user = provider.blockedUsers[index];
                final isProcessing = provider.isOperationInProgress(user.id);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: _buildAvatar(user),
                  title: Text(
                    (user.name != null && user.name!.trim().isNotEmpty)
                        ? user.name!.trim()
                        : ((user.username != null && user.username!.trim().isNotEmpty)
                            ? user.username!.trim()
                            : 'Catch&Watch User'),
                    style: text16(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: (user.username != null && user.username!.trim().isNotEmpty)
                      ? Text(
                          user.username!.trim().startsWith('@')
                              ? user.username!.trim()
                              : '@${user.username!.trim()}',
                          style: text14(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: OutlinedButton(
                    onPressed: isProcessing ? null : () => _handleUnblock(context, user, provider),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: isProcessing ? AppColors.grey300 : AppColors.primary,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(84, 36),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Text(
                            'Unblock',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(BlockedUser user) {
    final hasImage = user.profileImage != null && user.profileImage!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        color: AppColors.grey200,
        child: hasImage
            ? Image.network(
                user.profileImage!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallbackAvatar(user),
              )
            : _fallbackAvatar(user),
      ),
    );
  }

  Widget _fallbackAvatar(BlockedUser user) {
    final String initial = ((user.name?.isNotEmpty == true)
            ? user.name![0]
            : (user.username?.isNotEmpty == true ? user.username![0] : 'U'))
        .toUpperCase();

    return Center(
      child: Text(
        initial,
        style: text16(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
