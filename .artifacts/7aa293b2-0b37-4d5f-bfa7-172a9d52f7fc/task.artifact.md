# Task: Fix Follow/Following Logic Consistency

- [x] Centralize follow state in `ProfileProvider`
    - [x] Add `_followingIds` Set to `ProfileProvider`
    - [x] Update `fetchFollowing` to populate `_followingIds`
    - [x] Update `toggleFollow` to manage `_followingIds`
    - [x] Add `isUserFollowed` helper to `ProfileProvider`
- [x] Update `ReelsProvider` to sync follow state
    - [x] Refactor `_followingIds` to stay in sync with `ProfileProvider` or rely on a shared state
    - [x] Ensure UI updates both `ReelsProvider` and `ProfileProvider`
- [x] Update `UserProfileProvider` to sync follow state
    - [x] Ensure `toggleFollow` and `fetchUserProfile` respect the centralized state via UI selectors
- [x] Update UI components
    - [x] Update `FollowersFollowingScreen` to use centralized `isUserFollowed`
    - [x] Update `UserProfileScreen` follow button logic
    - [x] Update `ShortVideoPlayerScreen` follow button logic
- [x] Verification
    - [x] Verify consistent follow status across all screens
