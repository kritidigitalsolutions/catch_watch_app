import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeScreenProvider>();
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
                      hintText: "Search",
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

        // Recent Searches Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _isSearching ? "Search Results" : "Recommended for You",
            style: text20(fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 16),

        // Recent Searches List
        Expanded(
          child: displayList.isEmpty
              ? Center(
                  child: Text(
                    _isSearching ? "No results found" : "No content available",
                    style: text16(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final item = displayList[index];
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
                  },
                ),
        ),
      ],
    );
  }
}
