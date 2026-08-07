import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/user_search_provider.dart';
import 'package:catch_watch/views/after_login_pages/movie_details_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../res/app_colors.dart';
import '../../utils/text_style.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Content> _filteredContent = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, List<Content> allContent) {
    setState(() {
      if (query.isEmpty) {
        _isSearching = false;
        _filteredContent = [];
      } else {
        _isSearching = true;
        _filteredContent = allContent
            .where((content) =>
                content.title?.toLowerCase().contains(query.toLowerCase()) ??
                false)
            .toList();
      }
    });

    if (query.isNotEmpty) {
      context.read<ReelsProvider>().searchReels(query);
      context.read<UserSearchProvider>().searchUsers(query);
    } else {
      context.read<UserSearchProvider>().clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeScreenProvider>();
    final reelsProvider = context.watch<ReelsProvider>();
    final userSearchProvider = context.watch<UserSearchProvider>();
    
    final List<Content> displayList =
        _isSearching ? _filteredContent : homeProvider.allContent.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: AppColors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const SizedBox(height: 50),
          
          // Custom header with back button
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.search, color: Colors.grey, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (value) =>
                                _onSearchChanged(value, homeProvider.allContent),
                            decoration: InputDecoration(
                              hintText: "Search Movies, Reels & Users",
                              hintStyle: text14(color: AppColors.textSecondary),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: text14(),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('', homeProvider.allContent);
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.clear, color: Colors.grey, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
  
          const SizedBox(height: 12),
  
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_isSearching && userSearchProvider.users.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Users",
                      style: text18(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...userSearchProvider.users.map((user) => _buildUserTile(user)),
                  const SizedBox(height: 20),
                ],

                if (displayList.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _isSearching ? "Movies & Shows" : "Recommended for You",
                      style: text18(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...displayList.map((item) => _buildContentTile(item)),
                  const SizedBox(height: 20),
                ],
                
                if (_isSearching) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Reels",
                      style: text18(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (reelsProvider.isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ))
                  else if (reelsProvider.reels.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("No reels found", style: text14(color: AppColors.textSecondary)),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 16),
                        itemCount: reelsProvider.reels.length,
                        itemBuilder: (context, index) {
                          final reel = reelsProvider.reels[index];
                          return _buildReelCard(reel);
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
  
                if (_isSearching && displayList.isEmpty && reelsProvider.reels.isEmpty && userSearchProvider.users.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        "No results found",
                        style: text16(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserModel user) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.grey200),
        ),
        child: ClipOval(
          child: user.profileImage != null && user.profileImage!.isNotEmpty
              ? Image.network(
                  user.profileImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 30, color: Colors.grey),
                )
              : const Icon(Icons.person, size: 30, color: Colors.grey),
        ),
      ),
      title: Row(
        children: [
          Text(
            user.name ?? 'Unknown User',
            style: text16(fontWeight: FontWeight.w600),
          ),
          if (user.isVerified == true || user.blueTick == true) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, color: Colors.blue, size: 16),
          ],
        ],
      ),
      subtitle: Text(
        user.username ?? '',
        style: text13(color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey400),
      onTap: () {
        if (user.username != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(username: user.username!.replaceAll('@', '')),
            ),
          );
        }
      },
    );
  }

  Widget _buildContentTile(Content item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: item.poster != null && item.poster!.isNotEmpty
            ? Image.network(
                item.poster!,
                width: 70,
                height: 45,
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => Container(
                  width: 70,
                  height: 45,
                  color: AppColors.grey200,
                  child: const Icon(Icons.movie, size: 20),
                ),
              )
            : Container(
                width: 70,
                height: 45,
                color: AppColors.grey200,
                child: const Icon(Icons.movie, size: 20),
              ),
      ),
      title: Text(
        item.title ?? 'Untitled',
        style: text18(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        "${item.type ?? ''} • ${item.releaseYear ?? ''}",
        style: text12(color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 18,
        color: AppColors.primary,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailScreen(content: item),
          ),
        );
      },
    );
  }

  Widget _buildReelCard(ReelModel reel) {
    return GestureDetector(
      onTap: () {
        context.read<ReelsProvider>().setTargetReelId(reel.id);
        context.read<HomeScreenProvider>().changePage(1); // Go to Shorts tab
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: reel.thumbnail != null && reel.thumbnail!.isNotEmpty
                ? NetworkImage(reel.thumbnail!)
                : const AssetImage('assets/images/logo.jpg') as ImageProvider,
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (reel.user?.name != null)
                    Text(
                      reel.user!.name!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text10(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  Text(
                    reel.caption ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text10(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
