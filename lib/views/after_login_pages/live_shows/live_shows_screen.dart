import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/live_show_provider.dart';
import 'live_show_card_widget.dart';

class LiveShowsScreen extends StatefulWidget {
  const LiveShowsScreen({super.key});

  @override
  State<LiveShowsScreen> createState() => _LiveShowsScreenState();
}

class _LiveShowsScreenState extends State<LiveShowsScreen> {
  String _statusFilter = 'All Shows';
  String _categoryFilter = 'All Categories';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statuses = ['All Shows', 'Live Now', 'UPCOMING'];
  final List<String> _categories = ['All Categories', 'Music Concert', 'Podcast', 'Entertainment', 'Live Show'];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LiveShowProvider(),
      child: Builder(
        builder: (context) {
          final provider = context.watch<LiveShowProvider>();

          return Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.black, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('Live Shows & Broadcasts', style: text16(color: AppColors.black, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: () => provider.fetchLiveShowsData(
                    status: _statusFilter == 'Live Now' ? 'LIVE' : (_statusFilter == 'UPCOMING' ? 'UPCOMING' : 'ALL'),
                    category: _categoryFilter == 'All Categories' ? 'ALL' : _categoryFilter,
                    search: _searchController.text,
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // Filter & Search Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        style: text13(color: AppColors.black),
                        onSubmitted: (val) {
                          provider.fetchLiveShowsData(
                            status: _statusFilter == 'Live Now' ? 'LIVE' : (_statusFilter == 'UPCOMING' ? 'UPCOMING' : 'ALL'),
                            category: _categoryFilter == 'All Categories' ? 'ALL' : _categoryFilter,
                            search: val,
                          );
                        },
                        decoration: InputDecoration(
                          hintText: 'Search live shows, performers...',
                          hintStyle: text13(color: AppColors.grey500),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppColors.grey600),
                            onPressed: () {
                              _searchController.clear();
                              provider.fetchLiveShowsData(
                                status: _statusFilter == 'Live Now' ? 'LIVE' : (_statusFilter == 'UPCOMING' ? 'UPCOMING' : 'ALL'),
                                category: _categoryFilter == 'All Categories' ? 'ALL' : _categoryFilter,
                                search: '',
                              );
                            },
                          ),
                          filled: true,
                          fillColor: AppColors.grey100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _statuses.map((status) {
                            final isSelected = _statusFilter == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.grey100,
                                labelStyle: text12(color: isSelected ? Colors.white : AppColors.black, fontWeight: FontWeight.bold),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _statusFilter = status;
                                    });
                                    String apiStatus = 'ALL';
                                    if (status == 'Live Now') apiStatus = 'LIVE';
                                    if (status == 'UPCOMING') apiStatus = 'UPCOMING';
                                    provider.fetchLiveShowsData(
                                      status: apiStatus,
                                      category: _categoryFilter == 'All Categories' ? 'ALL' : _categoryFilter,
                                      search: _searchController.text,
                                    );
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Category Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = _categoryFilter == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.grey100,
                                labelStyle: text12(color: isSelected ? Colors.white : AppColors.black, fontWeight: FontWeight.bold),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _categoryFilter = cat;
                                    });
                                    provider.fetchLiveShowsData(
                                      status: _statusFilter == 'Live Now' ? 'LIVE' : (_statusFilter == 'UPCOMING' ? 'UPCOMING' : 'ALL'),
                                      category: _categoryFilter == 'All Categories' ? 'ALL' : _categoryFilter,
                                      search: _searchController.text,
                                    );
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: AppColors.grey300),

                // Shows List
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : provider.shows.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.tv_off, size: 64, color: AppColors.grey400),
                                  const SizedBox(height: 12),
                                  Text('No live shows found', style: text16(color: AppColors.black, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('Try changing your filters or search keyword', style: text12(color: AppColors.grey600)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => provider.fetchLiveShowsData(
                                status: _statusFilter == 'Live Now' ? 'LIVE' : (_statusFilter == 'UPCOMING' ? 'UPCOMING' : 'ALL'),
                                category: _categoryFilter == 'All Categories' ? 'ALL' : _categoryFilter,
                                search: _searchController.text,
                              ),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: provider.shows.length,
                                itemBuilder: (context, index) {
                                  final show = provider.shows[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: LiveShowCardWidget(show: show, isFullWidth: true),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
