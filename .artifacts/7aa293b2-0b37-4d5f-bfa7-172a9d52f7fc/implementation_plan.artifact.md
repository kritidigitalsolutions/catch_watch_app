# Implementation Plan - Fix Follow/Following Logic Consistency

This plan aims to centralize and unify the "follow" state across the application (Profile, Followers/Following lists, and Reels) to match Instagram's behavior where follow status is consistent everywhere.

## User Review Required

> [!IMPORTANT]
> The follow state will be primarily managed by `ProfileProvider` as it already handles the current user's profile and stats. `ReelsProvider` and `UserProfileProvider` will be updated to sync with this state.

## Proposed Changes

### [Component] View Models (Providers)

#### [MODIFY] [profile_provider.dart](file:///Users/agra/Documents/GitHub/catch_watch_app/lib/view_model/after_login_provider/profile_provider.dart)
- Add a `Set<String> _followingIds = {}` to store IDs of users the current logged-in user is following.
- Add a getter `bool isUserFollowed(String userId) => _followingIds.contains(userId);`.
- Update `fetchFollowing()` to populate `_followingIds` when fetching for the current user.
- Update `toggleFollow()` to add/remove IDs from `_followingIds` and notify listeners.
- Add a mechanism to notify `ReelsProvider` and `UserProfileProvider` when follow status changes.

#### [MODIFY] [reels_provider.dart](file:///Users/agra/Documents/GitHub/catch_watch_app/lib/view_model/after_login_provider/reels_provider.dart)
- Update `isUserFollowed()` to check if the ID exists in its local set, but also ensure it stays in sync with `ProfileProvider` if possible.
- Ensure `_fetchInitialInteractions()` correctly parses the following list (fixing potential ID extraction bugs).

#### [MODIFY] [user_profile_provider.dart](file:///Users/agra/Documents/GitHub/catch_watch_app/lib/view_model/after_login_provider/user_profile_provider.dart)
- Ensure `toggleFollow` and `syncFollowStatus` are correctly used and integrated with the global state.

### [Component] UI Screens

#### [MODIFY] [followers_following_screen.dart](file:///Users/agra/Documents/GitHub/catch_watch_app/lib/views/after_login_pages/profile_page/followers_following_screen.dart)
- Update the "Follow/Following" button logic to use `provider.isUserFollowed(user.id)` instead of relying solely on `user.isFollowing` property which might be stale or unset.
- Ensure clicking the button updates both `ProfileProvider` and `ReelsProvider` (already partially implemented, but will be refined).

#### [MODIFY] [short_video_screen.dart](file:///Users/agra/Documents/GitHub/catch_watch_app/lib/views/after_login_pages/short_video_screen.dart)
- Verify the follow button logic in Reels and ensure it uses the updated provider state.

## Verification Plan

### Manual Verification
- Log in to the app.
- Go to your profile and check "Following" list. All should show "Following".
- Go to "Followers" list. Check if people you follow show "Following" and others show "Follow".
- Follow/Unfollow someone from the list and verify the button text changes immediately.
- Go to Reels section and find a reel by a user you just followed/unfollowed. The follow button there should reflect the same state.
- Follow someone from Reels and check if they appear correctly in your "Following" list with the correct button state.
