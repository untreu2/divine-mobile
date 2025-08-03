// ABOUTME: Reusable tile widget for displaying user profile information in lists
// ABOUTME: Shows avatar, name, and follow button with tap handling for navigation

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/optimistic_follow_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

class UserProfileTile extends ConsumerWidget {
  const UserProfileTile({
    super.key,
    required this.pubkey,
    this.onTap,
    this.showFollowButton = true,
  });

  final String pubkey;
  final VoidCallback? onTap;
  final bool showFollowButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileService = ref.watch(userProfileServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final isCurrentUser = pubkey == authService.currentPublicKeyHex;
    
    return FutureBuilder(
      future: userProfileService.fetchProfile(pubkey),
      builder: (context, snapshot) {
        final profile = userProfileService.getCachedProfile(pubkey);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: onTap,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[700],
                  backgroundImage: profile?.picture != null && profile!.picture!.isNotEmpty
                      ? CachedNetworkImageProvider(profile.picture!)
                      : null,
                  child: profile?.picture == null || profile!.picture!.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              
              // Name and details
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.bestDisplayName ?? pubkey.substring(0, 8),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (profile?.about != null && profile!.about!.isNotEmpty)
                        Text(
                          profile.about!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              
              // Follow button
              if (showFollowButton && !isCurrentUser) ...[
                const SizedBox(width: 12),
                Consumer(
                  builder: (context, ref, child) {
                    final isFollowing = ref.watch(isFollowingProvider(pubkey));
                    
                    return SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () => _toggleFollow(ref, pubkey, isFollowing),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.grey[700] : Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleFollow(WidgetRef ref, String pubkey, bool isCurrentlyFollowing) async {
    try {
      final socialService = ref.read(socialServiceProvider);
      
      if (isCurrentlyFollowing) {
        await socialService.unfollowUser(pubkey);
        Log.info('👤 Unfollowed user: ${pubkey.substring(0, 8)}', 
            name: 'UserProfileTile', category: LogCategory.ui);
      } else {
        await socialService.followUser(pubkey);
        Log.info('👤 Followed user: ${pubkey.substring(0, 8)}', 
            name: 'UserProfileTile', category: LogCategory.ui);
      }
    } catch (e) {
      Log.error('Failed to toggle follow: $e', 
          name: 'UserProfileTile', category: LogCategory.ui);
    }
  }
}