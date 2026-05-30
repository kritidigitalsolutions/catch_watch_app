import 'package:carousel_slider/carousel_slider.dart';
import 'package:catch_watch/utils/custom_button.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/views/after_login_pages/movie_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../res/app_colors.dart';
import '../../utils/text_style.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeScreenProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(),
        _buildTabBar(provider),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildCarousel(provider),
              _buildDotIndicator(provider),
              const SizedBox(height: 24),
              _buildSectionHeader('🔥 Trending Now'),
              const SizedBox(height: 10),
              _buildTrendingRow(provider),
              const SizedBox(height: 24),
              _buildSectionHeader('▶ Continue Watching'),
              const SizedBox(height: 10),
              _buildContinueRow(provider),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
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
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              CustomIconButton(icon: Icons.search_rounded, onPressed: () {}),
              const SizedBox(width: 6),
              Stack(
                children: [
                  CustomIconButton(
                    icon: Icons.notifications_outlined,
                    onPressed: () {},
                  ),
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

  Widget _buildCarousel(HomeScreenProvider provider) {
    return CarouselSlider(
      options: CarouselOptions(
        height: 220,
        viewportFraction: 1.0,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        autoPlayAnimationDuration: const Duration(milliseconds: 700),
        onPageChanged: (i, _) => provider.updateBannerIndex(i),
      ),
      items: provider.banners.map((item) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(item.image, fit: BoxFit.cover),
            // Dark gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            // Badge + info
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.badge,
                      style: text10(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: text30(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: text18(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.meta, style: text12(color: AppColors.grey400)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _playButton(),
                      const SizedBox(width: 8),
                      _iconCircle(Icons.bookmark_border_rounded),
                      const SizedBox(width: 8),
                      _iconCircle(Icons.share_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _playButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {},
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(provider.banners.length, (i) {
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

  Widget _buildSectionHeader(String title) {
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
          Text(
            'More →',
            style: text13(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
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
            child: _ContentCard(item: item),
          );
        },
      ),
    );
  }

  Widget _buildContinueRow(HomeScreenProvider provider) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: provider.continueWatching.length,
        itemBuilder: (_, i) {
          final item = provider.continueWatching[i];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 10),
            child: _ContinueCard(item: item),
          );
        },
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final ContentItem item;
  const _ContentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MovieDetailScreen()),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(item.image, fit: BoxFit.cover),
            // Positioned(
            //   bottom: 0,
            //   left: 0,
            //   right: 0,
            //   child: Container(
            //     padding: const EdgeInsets.all(6),
            //     decoration: BoxDecoration(
            //       gradient: LinearGradient(
            //         begin: Alignment.topCenter,
            //         end: Alignment.bottomCenter,
            //         colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
            //       ),
            //     ),
            //     child: Row(
            //       children: [
            //         const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 14),
            //         const SizedBox(width: 3),
            //         Text(item.views, style: text11(color: Colors.white, fontWeight: FontWeight.w700)),
            //       ],
            //     ),
            //   ),
            // ),
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
    final progress = double.tryParse(item.progress ?? '0') ?? 0;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MovieDetailScreen()),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(item.image, fit: BoxFit.cover),
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
                  children: [
                    Text(
                      item.title,
                      style: text12(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        color: AppColors.primary,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (item.remaining != null)
                      Text(
                        item.remaining!,
                        style: text10(color: AppColors.grey400),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
