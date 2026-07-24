import 'package:catch_watch/models/reel_model.dart';
import 'package:catch_watch/view_model/after_login_provider/notification_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
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
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildCarousel(provider, context),
        _buildDotIndicator(provider),
        const SizedBox(height: 24),
        _buildTrendingSection(provider),
        if (provider.continueWatching.isNotEmpty) ...[
          _buildSectionHeader('▶ Continue Watching'),
          const SizedBox(height: 10),
          _buildContinueRow(provider),
          const SizedBox(height: 24),
        ],
        if (provider.movies.isNotEmpty) ...[
          _buildSectionHeader('Recommended Movies', onMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentGridScreen(
                  title: 'Recommended Movies',
                  contentList: provider.movies,
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildMovieRow(provider.movies),
          const SizedBox(height: 24),
        ],
        if (provider.series.isNotEmpty) ...[
          _buildSectionHeader('Popular Series', onMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentGridScreen(
                  title: 'Series',
                  contentList: provider.series,
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildMovieRow(provider.series),
          const SizedBox(height: 24),
        ],
        if (provider.tvShows.isNotEmpty) ...[
          _buildSectionHeader('Popular TV Shows', onMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentGridScreen(
                  title: 'Popular TV Shows',
                  contentList: provider.tvShows,
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildMovieRow(provider.tvShows),
          const SizedBox(height: 24),
        ],
        if (provider.shortFilms.isNotEmpty) ...[
          _buildSectionHeader('Must Watch Short Films', onMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentGridScreen(
                  title: 'Short Films',
                  contentList: provider.shortFilms,
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildMovieRow(provider.shortFilms),
          const SizedBox(height: 24),
        ],
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 100),
      ],
    );
  }

  Widget _buildMoviesTab(HomeScreenProvider provider) {
    return _buildCategoryTab(provider, 'Latest Movies', provider.movies);
  }

  Widget _buildShortFilmsTab(HomeScreenProvider provider) {
    return _buildCategoryTab(provider, 'Short & Sweet', provider.shortFilms);
  }

  Widget _buildSeriesTab(HomeScreenProvider provider) {
    return _buildCategoryTab(provider, 'Popular Series', provider.series);
  }

  Widget _buildTvShowsTab(HomeScreenProvider provider) {
    return _buildCategoryTab(provider, 'Bingeworthy Series', provider.tvShows);
  }

  Widget _buildCategoryTab(HomeScreenProvider provider, String fullListTitle, List<Content> fullList) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildCarousel(provider, context),
        _buildDotIndicator(provider),
        const SizedBox(height: 24),
        _buildTrendingSection(provider),
        _buildSectionHeader(fullListTitle, onMore: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentGridScreen(
                title: fullListTitle,
                contentList: fullList,
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        _buildMovieRow(fullList),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 100),
      ],
    );
  }

  Widget _buildTrendingSection(HomeScreenProvider provider) {
    final trending = provider.currentTabTrending;
    if (trending.isEmpty) return const SizedBox();

    return Column(
      children: [
        _buildSectionHeader('🔥 Trending Now'),
        const SizedBox(height: 10),
        _buildTrendingRow(provider),
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
                      Colors.black.withOpacity(0.95),
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

  Widget _playButton(BuildContext context, Content content) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openMovie(context, content),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  'Play Now',
                  style: text13(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _watchlistIcon(BuildContext context, Content content) {
    final watchlistProvider = context.watch<WatchlistProvider>();
    final isInWatchlist =
        watchlistProvider.items.any((i) => i.item?.id == content.id);

    return GestureDetector(
      onTap: () {
        if (isInWatchlist) {
          final watchlistItem =
              watchlistProvider.items.firstWhere((i) => i.item?.id == content.id);
          watchlistProvider.removeItem(watchlistItem.id!);
        } else {
          watchlistProvider.addItem(content.id!);
        }
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(
          isInWatchlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isInWatchlist ? AppColors.primary : Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _iconCircle(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
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

  Widget _buildTrendingRow(HomeScreenProvider provider) {
    final trending = provider.currentTabTrending;
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: trending.length,
        itemBuilder: (_, i) {
          final item = trending[i];
          return Container(
            width: 132,
            margin: const EdgeInsets.only(right: 12),
            child: _MoviePosterCard(content: item),
          );
        },
      ),
    );
  }

  Widget _buildContinueRow(HomeScreenProvider provider) {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: provider.continueWatching.length,
        itemBuilder: (_, i) {
          final item = provider.continueWatching[i];
          return Container(
            width: 240,
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

class _ContentCard extends StatelessWidget {
  final Content content;
  const _ContentCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openMovie(context, content),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            content.poster != null && content.poster!.isNotEmpty
                ? Image.network(
                    content.poster!,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) =>
                        Image.asset('assets/images/logo.jpg', fit: BoxFit.fill),
                  )
                : Image.asset('assets/images/logo.jpg', fit: BoxFit.fill),
          ],
        ),
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
                    fit: BoxFit.fill,
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
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.92),
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
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 18,
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
