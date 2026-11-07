import 'package:catch_watch/models/content_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/empty_state_widget.dart';
import 'package:catch_watch/utils/entitlement_helper.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:flutter/material.dart';

class ContentGridScreen extends StatelessWidget {
  final String title;
  final List<Content> contentList;

  const ContentGridScreen({
    super.key,
    required this.title,
    required this.contentList,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: text18(color: AppColors.black, fontWeight: FontWeight.w800),
        ),
      ),
      body: contentList.isEmpty
          ? EmptyStateWidget(
              title: 'No $title Found',
              message: 'No content is available in this category yet.',
              icon: Icons.movie_outlined,
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: contentList.length,
              itemBuilder: (context, index) {
                return _GridItem(content: contentList[index]);
              },
            ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final Content content;
  const _GridItem({required this.content});

  void _handleTap(BuildContext context) async {
    await EntitlementHelper.openContent(context, content);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  content.poster != null
                      ? Image.network(content.poster!, fit: BoxFit.fill)
                      : Image.asset('assets/images/logo.jpg', fit: BoxFit.fill),
                  if (content.isPremium == true)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'P',
                          style: text10(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text11(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
