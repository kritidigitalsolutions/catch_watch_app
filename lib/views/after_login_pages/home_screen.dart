import 'package:catch_watch/models/content_model.dart';
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../res/app_colors.dart';
import '../../utils/text_style.dart';

Future<void> _openMovie(BuildContext context, Content content) async {
  final subProvider = context.read<SubscriptionProvider>();

  // Check if content is free or user has an active subscription
  bool canWatch = content.isPremium != true || subProvider.currentSubscription != null;

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
      case 3: // TV Shows
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
        if (provider.trending.isNotEmpty) ...[
          _buildSectionHeader('🔥 Trending Now', onMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentGridScreen(
                  title: 'Trending Now',
                  contentList: provider.trending,
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildTrendingRow(provider),
          const SizedBox(height: 24),
        ],
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
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildMoviesTab(HomeScreenProvider provider) {
    final movieBanners = provider.movies.where((m) => m.category?.contains('trending') ?? false).toList();
    final actionMovies = provider.movies.where((m) => m.genre?.contains('Action') ?? m.genre?.contains('Thriller') ?? false).toList();
    final romanceMovies = provider.movies.where((m) => m.genre?.contains('Romance') ?? false).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (movieBanners.isNotEmpty) ...[
          _buildCategoryCarousel(movieBanners),
          _buildDotIndicator(provider),
          const SizedBox(height: 24),
        ],
        _buildSectionHeader('Latest Movies', onMore: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentGridScreen(
                title: 'Latest Movies',
                contentList: provider.movies,
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        _buildMovieRow(provider.movies),
        const SizedBox(height: 24),
        if (actionMovies.isNotEmpty) ...[
          _buildSectionHeader('Action & Thriller', onMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentGridScreen(
                  title: 'Action & Thriller',
                  contentList: actionMovies,
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildMovieRow(actionMovies),
          const SizedBox(height: 24),
        ],
        if (romanceMovies.isNotEmpty) ...[
          _buildSectionHeader('Romance', onMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentGridScreen(
                  title: 'Romance Movies',
                  contentList: romanceMovies,
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildMovieRow(romanceMovies),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildShortFilmsTab(HomeScreenProvider provider) {
    final shortBanners = provider.shortFilms.where((m) => m.category?.contains('trending') ?? false).toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (shortBanners.isNotEmpty) ...[
          _buildCategoryCarousel(shortBanners),
          _buildDotIndicator(provider),
          const SizedBox(height: 24),
        ],
        _buildSectionHeader('Short & Sweet', onMore: () {
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
        _buildSectionHeader('Trending Shorts'),
        const SizedBox(height: 10),
        _buildTrendingRow(provider),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTvShowsTab(HomeScreenProvider provider) {
    final tvBanners = provider.tvShows.where((m) => m.category?.contains('trending') ?? false).toList();
    final ongoingShows = provider.tvShows.where((s) => s.status == 'ongoing').toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (tvBanners.isNotEmpty) ...[
          _buildCategoryCarousel(tvBanners),
          _buildDotIndicator(provider),
          const SizedBox(height: 24),
        ],
        _buildSectionHeader('Bingeworthy Series', onMore: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentGridScreen(
                title: 'TV Series',
                contentList: provider.tvShows,
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        _buildMovieRow(provider.tvShows),
        const SizedBox(height: 24),
        if (ongoingShows.isNotEmpty) ...[
          _buildSectionHeader('New Episodes', onMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentGridScreen(
                  title: 'Ongoing Series',
                  contentList: ongoingShows,
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildMovieRow(ongoingShows),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildCategoryCarousel(List<Content> banners) {
    return CarouselSlider(
      options: CarouselOptions(
        height: 220,
        viewportFraction: 1.0,
        enlargeCenterPage: false,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        onPageChanged: (i, _) => context.read<HomeScreenProvider>().updateBannerIndex(i),
      ),
      items: banners.map((item) {
        return GestureDetector(
          onTap: () => _openMovie(context, item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.banner != null
                  ? Image.network(item.banner!, fit: BoxFit.cover)
                  : Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
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

  Widget _buildCarousel(HomeScreenProvider provider, BuildContext context) {
    if (provider.bannersList.isEmpty) return const SizedBox();

    return CarouselSlider(
      options: CarouselOptions(
        height: 220,
        viewportFraction: 1.0,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        autoPlayAnimationDuration: const Duration(milliseconds: 700),
        onPageChanged: (i, _) => provider.updateBannerIndex(i),
      ),
      items: provider.bannersList.map((item) {
        return GestureDetector(
          onTap: () => _openMovie(context, item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.banner != null
                  ? Image.network(item.banner!, fit: BoxFit.cover)
                  : Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
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
    List<Content> currentBanners = [];
    switch (provider.selectedTabIndex) {
      case 0: currentBanners = provider.bannersList; break;
      case 1: currentBanners = provider.movies.where((m) => m.category?.contains('trending') ?? false).toList(); break;
      case 2: currentBanners = provider.shortFilms.where((m) => m.category?.contains('trending') ?? false).toList(); break;
      case 3: currentBanners = provider.tvShows.where((m) => m.category?.contains('trending') ?? false).toList(); break;
    }

    if (currentBanners.isEmpty) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(currentBanners.length, (i) {
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
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: provider.trending.length,
        itemBuilder: (_, i) {
          final item = provider.trending[i];
          return Container(
            width: 110,
            margin: const EdgeInsets.only(right: 10),
            child: _ContentCard(content: item),
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
            content.poster != null
                ? Image.network(content.poster!, fit: BoxFit.cover)
                : Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
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
            item.image.startsWith('http')
                ? Image.network(item.image, fit: BoxFit.cover)
                : Image.asset(item.image, fit: BoxFit.cover),
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
                      ? Image.network(content.poster!, fit: BoxFit.cover)
                      : Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
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
