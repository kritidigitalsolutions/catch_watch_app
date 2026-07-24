import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/view_model/after_login_provider/notification_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/watchlist_provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:catch_watch/utils/custom_button.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/views/after_login_pages/content_grid_screen.dart';
import 'package:catch_watch/views/after_login_pages/movie_details_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/notification_screen.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/subsrciption_screen.dart';
import 'package:catch_watch/views/after_login_pages/short_video_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/content_model.dart';
import '../../res/app_colors.dart';
import '../../utils/text_style.dart';

void _openShortFilm(BuildContext context, Content content) {
  // Check if premium and needs subscription
  final subProvider = context.read<SubscriptionProvider>();
  bool canWatch = content.isPremium != true || subProvider.currentSubscription != null;

  if (!canWatch) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ShortVideoPlayerScreen(
        isVisible: true,
        initialReels: [ReelModel.fromContent(content)],
      ),
    ),
  );
}

Future<void> _openMovie(BuildContext context, Content content) async {
  if (content.type == 'shortFilm' || content.type == 'short' || content.type == 'shortfilm') {
    _openShortFilm(context, content);
    return;
  }

  final subProvider = context.read<SubscriptionProvider>();

  // Check if content is free or user has an active subscription
  bool canWatch =
      content.isPremium != true || subProvider.currentSubscription != null;

  if (canWatch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(content: content),
      ),
    );
  } else {
    // If premium and no subscription, go to plans
    final subscribed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );

    if (context.mounted && subscribed == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(content: content),
        ),
      );
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchSubscriptionStatus();
      context.read<WatchlistProvider>().fetchWatchlist();
      context.read<HomeScreenProvider>().fetchAllContent();
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeScreenProvider>();

    return provider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : provider.error != null
            ? Center(child: Text(provider.error!))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context, provider),
                  _buildTabBar(provider),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: provider.fetchAllContent,
                      child: _buildTabContent(provider),
                    ),
                  ),
                ],
              );
  }

  Widget _buildTabContent(HomeScreenProvider provider) {
    switch (provider.selectedTabIndex) {
      case 0: // All Shows
        return _buildAllShowsTab(provider);
      case 1: // Movies
        return _buildMoviesTab(provider);
      case 2: // Short Films
        return _buildShortFilmsTab(provider);
      case 3: // Series
        return _buildSeriesTab(provider);
      case 4: // TV Shows
        return _buildTvShowsTab(provider);
      default:
        return _buildAllShowsTab(provider);
    }
  }

  Widget _buildAllShowsTab(HomeScreenProvider provider) {
    return _buildTabWithSections(provider, showContinueWatching: true);
  }

  Widget _buildMoviesTab(HomeScreenProvider provider) {
    return _buildTabWithSections(provider, showContinueWatching: false);
  }

  Widget _buildShortFilmsTab(HomeScreenProvider provider) {
    return _buildTabWithSections(provider, showContinueWatching: false);
  }

  Widget _buildSeriesTab(HomeScreenProvider provider) {
    return _buildTabWithSections(provider, showContinueWatching: false);
  }

  Widget _buildTvShowsTab(HomeScreenProvider provider) {
    return _buildTabWithSections(provider, showContinueWatching: false);
  }

  Widget _buildTabWithSections(HomeScreenProvider provider, {required bool showContinueWatching}) {
    final categories = provider.categories;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildCarousel(provider, context),
        _buildDotIndicator(provider),
        const SizedBox(height: 24),

        // First Category
        if (categories.isNotEmpty) ...[
          _buildCategorySection(provider, categories[0]),
        ],

        // Continue Watching - Only if requested and not empty
        if (showContinueWatching && provider.continueWatching.isNotEmpty) ...[
          _buildSectionHeader('▶ Continue Watching'),
          const SizedBox(height: 10),
          _buildContinueRow(provider),
          const SizedBox(height: 24),
        ],

        // Remaining Categories
        if (categories.length > 1)
          ...categories.skip(1).map((category) => _buildCategorySection(provider, category)),

        SizedBox(height: MediaQuery.paddingOf(context).bottom + 100),
      ],
    );
  }

  Widget _buildCategorySection(HomeScreenProvider provider, dynamic category) {
    final categoryContent = provider.getContentByCategory(category.slug ?? category.name ?? '');
    if (categoryContent.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(category.name ?? '', onMore: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentGridScreen(
                title: category.name ?? '',
                contentList: categoryContent,
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        _buildMovieRow(categoryContent),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCarousel(HomeScreenProvider provider, BuildContext context) {
    final banners = provider.currentTabBanners;
    if (banners.isEmpty) return const SizedBox();

    return CarouselSlider(
      options: CarouselOptions(
        height: 220,
        viewportFraction: 1.0,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        autoPlayAnimationDuration: const Duration(milliseconds: 700),
        onPageChanged: (i, _) => provider.updateBannerIndex(i),
      ),
      items: banners.map((item) {
        return GestureDetector(
          onTap: () => _openMovie(context, item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.banner != null && item.banner!.isNotEmpty
                  ? Image.network(
                      item.banner!,
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset('assets/images/logo.jpg', fit: BoxFit.fill),
                    )
                  : Image.asset('assets/images/logo.jpg', fit: BoxFit.fill),
              // Dark gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(242), // approx 0.95 * 255
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopBar(BuildContext context, HomeScreenProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'CATCH',
                  style: text24(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: 'WATCH',
                  style: text24(
                    color: AppColors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              CustomIconButton(
                icon: Icons.search_rounded,
                onPressed: () {
                  provider.changePage(3);
                },
              ),
              const SizedBox(width: 6),
              Consumer<NotificationProvider>(
                builder: (context, notifProvider, child) {
                  return Stack(
                    children: [
                      CustomIconButton(
                        icon: Icons.notifications_outlined,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                      if (notifProvider.unreadCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(HomeScreenProvider provider) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.tabs.length,
        itemBuilder: (context, index) {
          final isActive = provider.selectedTabIndex == index;
          return GestureDetector(
            onTap: () => provider.selectTab(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 20),
              padding: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                provider.tabs[index],
                style: text14(
                  color: isActive ? AppColors.primary : AppColors.grey600,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDotIndicator(HomeScreenProvider provider) {
    final banners = provider.currentTabBanners;
    if (banners.isEmpty) return const SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(banners.length, (i) {
        final active = i == provider.currentBannerIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 4, top: 8),
          width: active ? 20 : 6,
          height: 3,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.grey700,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onMore}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: text16(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          GestureDetector(
            onTap: onMore,
            child: Text(
              'More →',
              style: text13(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueRow(HomeScreenProvider provider) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: provider.continueWatching.length,
        itemBuilder: (_, i) {
          final item = provider.continueWatching[i];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: _ContinueCard(item: item),
          );
        },
      ),
    );
  }

  Widget _buildMovieRow(List<Content> items) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          return Container(
            width: 132,
            margin: const EdgeInsets.only(right: 12),
            child: _MoviePosterCard(content: items[i]),
          );
        },
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final ContentItem item;
  const _ContinueCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final progress = (double.tryParse(item.progress ?? '0') ?? 0).clamp(
      0.0,
      1.0,
    );
    return GestureDetector(
      onTap: () {
        if (item.content != null) {
          _openMovie(context, item.content!);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            item.image != null && item.image!.isNotEmpty && item.image!.startsWith('http')
                ? Image.network(
                    item.image!,
                    fit: BoxFit.fill, // Use cover for banner aspect ratio
                    errorBuilder: (context, error, stackTrace) =>
                        Image.asset('assets/images/logo.jpg', fit: BoxFit.fill),
                  )
                : Image.asset(
                    (item.image != null && item.image!.isNotEmpty)
                        ? item.image!
                        : 'assets/images/logo.jpg',
                    fit: BoxFit.fill),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(235), // approx 0.92 * 255
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text14(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (item.episode != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.episode!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text10(color: AppColors.grey300),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        color: AppColors.primary,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (item.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: Text(
                              item.badge!,
                              style: text10(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (item.badge != null) const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.meta ?? item.remaining ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text10(color: AppColors.grey300),
                          ),
                        ),
                      ],
                    ),
                    if (item.remaining != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.remaining!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text10(color: AppColors.grey400),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  if (item.content?.id != null) {
                    context.read<HomeScreenProvider>().removeFromContinueWatching(item.content!.id!);
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoviePosterCard extends StatelessWidget {
  final Content content;
  const _MoviePosterCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = context.watch<WatchlistProvider>();
    final isInWatchlist = watchlistProvider.items.any((i) => i.item?.id == content.id);

    return GestureDetector(
      onTap: () => _openMovie(context, content),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  content.poster != null
                      ? Image.network(
                          content.poster!,
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset('assets/images/logo.jpg',
                                  fit: BoxFit.fill),
                        )
                      : Image.asset('assets/images/logo.jpg',
                          fit: BoxFit.fill),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.12),
                          Colors.transparent,
                          Colors.black.withOpacity(0.65),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        if (isInWatchlist) {
                          final watchlistItem = watchlistProvider.items
                              .firstWhere((i) => i.item?.id == content.id);
                          watchlistProvider.removeItem(watchlistItem.id!);
                        } else {
                          watchlistProvider.addItem(content.id!);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isInWatchlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isInWatchlist ? AppColors.primary : Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  if (content.isPremium == true)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PREMIUM',
                          style: text10(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.yellow,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            content.rating?.toString() ?? '0.0',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text11(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text13(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            content.genre?.join(' • ') ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text11(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }
}
