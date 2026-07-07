import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/views/after_login_pages/movie_details_screen.dart';
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeScreenProvider>();
    final reelsProvider = context.watch<ReelsProvider>();
    
    final List<Content> displayList =
        _isSearching ? _filteredContent : homeProvider.allContent.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 50),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        _onSearchChanged(value, homeProvider.allContent),
                    decoration: InputDecoration(
                      hintText: "Search Movies & Reels",
                      hintStyle: text16(color: AppColors.textSecondary),
                      border: InputBorder.none,
                    ),
                    style: text16(),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _onSearchChanged('', homeProvider.allContent);
                    },
                    child: const Icon(Icons.clear, color: Colors.grey),
                  ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (displayList.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _isSearching ? "Movies & Shows" : "Recommended for You",
                    style: text20(fontWeight: FontWeight.bold),
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
                    style: text20(fontWeight: FontWeight.bold),
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

              if (_isSearching && displayList.isEmpty && reelsProvider.reels.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text(
                      "No results found",
                      style: text16(color: AppColors.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
                fit: BoxFit.cover,
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
        context.read<HomeScreenProvider>().changePage(1); // Go to Shorts tab
      },
      child: Container(
        width: 120,
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
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                reel.caption ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text10(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
