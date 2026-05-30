import 'package:flutter/material.dart';
import '../../res/app_colors.dart';
import '../../utils/text_style.dart';

class SearchScreen extends StatelessWidget {
   SearchScreen({super.key});

  final List<SearchItem> recentSearches = [
    SearchItem(
      image: "assets/images/1.png",
      title: "Avatar",
    ),
    SearchItem(
      image: "assets/images/2.png",
      title: "1917",
    ),
    SearchItem(
      image: "assets/images/3.png",
      title: "Spider-Man",
    ),

  ];

  @override
  Widget build(BuildContext context) {
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
                    decoration: InputDecoration(
                      hintText: "Search",
                      hintStyle: text16(color: AppColors.textSecondary),
                      border: InputBorder.none,
                    ),
                    style: text16(),
                  ),
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
            "Recent Searches",
            style: text20(fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 16),

        // Recent Searches List
        Expanded(
          child: ListView.builder(

            itemCount: recentSearches.length,
            itemBuilder: (context, index) {
              final item = recentSearches[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    item.image,
                    width: 70,
                    height: 45,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  item.title,
                  style: text18(fontWeight: FontWeight.w500),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: AppColors.primary,
                ),
                onTap: () {
                  // TODO: Navigate to movie/series detail
                },
              );
            },
          ),
        ),

      // Extra space for bottom navigation
      ],
    );
  }
}

class SearchItem {
  final String image;
  final String title;

  SearchItem({required this.image, required this.title});
}