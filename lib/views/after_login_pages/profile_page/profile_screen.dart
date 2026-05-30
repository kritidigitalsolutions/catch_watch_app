import 'package:catch_watch/utils/custom_button.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  // Jab scroll is value se zyada ho, collapsed bar dikhao
  static const double _collapseThreshold = 160.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final collapsed = _scrollController.offset > _collapseThreshold;
      if (collapsed != _isCollapsed) {
        setState(() => _isCollapsed = collapsed);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // ── Main scrollable content ──────────────────────────────────────
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Full expanded orange header (no appbar title here)
              SliverToBoxAdapter(child: _ExpandedHeader(provider: provider)),

              // // Stats
              // SliverToBoxAdapter(child: _buildStats(provider)),

              // Tab row
              SliverToBoxAdapter(child: _buildTabRow(provider)),

              // Divider
              const SliverToBoxAdapter(
                child: Divider(color: Color(0xFFF0F0F0), thickness: 1, height: 1),
              ),

              // Grid
              _buildGrid(provider),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),

          // ── Collapsed sticky bar (only visible after scroll threshold) ───
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _isCollapsed ? 0 : -80, // slide in from top
            left: 0,
            right: 0,
            child: _CollapsedBar(provider: provider),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(ProfileProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          _statCard(provider.videosCount, 'VIDEOS'),
          const SizedBox(width: 10),
          _statCard(provider.followers, 'FOLLOWERS'),
          const SizedBox(width: 10),
          _statCard(provider.following, 'FOLLOWING'),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: text18(color: AppColors.primary, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: text10(color: AppColors.grey600, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabRow(ProfileProvider provider) {
    final tabs = [
      (ProfileTab.videos, Icons.play_circle_outline_rounded, 'VIDEOS'),
      (ProfileTab.cuts, Icons.content_cut_rounded, 'CUTS'),
      (ProfileTab.saved, Icons.bookmark_border_rounded, 'SAVED'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: tabs.map((t) {
          final isActive = provider.activeTab == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => provider.setTab(t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? AppColors.primary : AppColors.grey100,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(t.$2,
                        size: 18,
                        color: isActive ? AppColors.primary : AppColors.grey600),
                    const SizedBox(height: 4),
                    Text(t.$3,
                        style: text8(
                          color: isActive ? AppColors.primary : AppColors.grey600,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid(ProfileProvider provider) {
    final items = provider.currentTabItems;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
              (_, i) => _GridCard(item: items[i]),
          childCount: items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 0.75,
        ),
      ),
    );
  }
}

// ─── Full expanded orange header ────────────────────────────────────────────
class _ExpandedHeader extends StatelessWidget {
  final ProfileProvider provider;
  const _ExpandedHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topPadding + 12, bottom: 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5F00), Color(0xFFCC3D00)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative circles
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -20, left: -20,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.08),
              ),
            ),
          ),

          // ── Menu button top-right (always visible in expanded state) ──
          Positioned(
            top: 0, right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomIconButton(icon: Icons.menu_rounded, color: AppColors.white, onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MenuScreen()));
              }),
            ),
          ),

          // ── Center content ──
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 36),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                ),
                child: CircleAvatar(
                  radius: 42,
                  backgroundImage: AssetImage(provider.avatarAsset),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(provider.name,
                  style: text20(color: Colors.white, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(provider.handle, style: text14(color: Colors.white70)),
              const SizedBox(height: 14),
              _pill(Icons.edit_rounded, 'Edit Profile'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(label,
                    style: text12(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Collapsed sticky bar (slides in from top when scrolled) ───────────────
class _CollapsedBar extends StatelessWidget {
  final ProfileProvider provider;
  const _CollapsedBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 8,
        bottom: 10,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(

        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5F00), Color(0xFFCC3D00)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33FF5F00),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Small avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(provider.avatarAsset),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 10),

          // Name + handle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(provider.name,
                    style: text14(color: Colors.white, fontWeight: FontWeight.w800)),
                Text(provider.handle, style: text11(color: Colors.white70)),
              ],
            ),
          ),

          // Edit pill
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text('Edit',
                          style:
                          text11(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Menu button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomIconButton(icon: Icons.menu_rounded,  color: AppColors.white, onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MenuScreen()));
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Grid card ──────────────────────────────────────────────────────────────
class _GridCard extends StatelessWidget {
  final VideoItem item;
  const _GridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(item.image, fit: BoxFit.cover),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 10, 5, 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text(item.views,
                      style: text8(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}