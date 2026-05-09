import 'package:flutter/material.dart';

import '../viewModel/AppServicesViewModel.dart';
import 'shared/AppColorsView.dart';
import '../model/ProductModel.dart';
import 'shared/AppRoutesView.dart';
import 'shared/AsyncStateView.dart';
import 'shared/SwapioBottomNavView.dart';
import 'shared/GradientScaffoldView.dart';
import 'shared/ProductCardView.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _productRepository = AppServicesViewModel.instance.productRepository;
  final _userRepository = AppServicesViewModel.instance.userRepository;
  final _searchController = TextEditingController();
  String _selectedTag = 'All';
  List<String> _tags = const [];
  List<ProductModel> _products = const [];
  Set<String> _favoriteIds = <String>{};
  String _userName = '';
  bool _isLoading = true;
  String? _error;
  bool _isRefreshingFavorites = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = await _userRepository.getCurrentUser();
      final tags = await _productRepository.getTags();
      final products = await _productRepository.getTrendingProducts();
      if (!mounted) return;
      setState(() {
        _userName = user.name;
        _tags = tags;
        _products = products;
        _favoriteIds = user.favorites.toSet();
        _selectedTag = tags.contains(_selectedTag) ? _selectedTag : (tags.isNotEmpty ? tags.first : 'All');
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<ProductModel> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    return _products.where((product) {
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          (product.brand?.toLowerCase().contains(query) ?? false) ||
          product.description.toLowerCase().contains(query);
      final matchesTag = _selectedTag == 'All' ||
          _selectedTag == 'Trending' ||
          product.styleTags.any((tag) => tag.toLowerCase() == _selectedTag.toLowerCase());
      return matchesSearch && matchesTag;
    }).toList();
  }

  Future<void> _refreshFavorites() async {
    if (_isRefreshingFavorites) return;
    _isRefreshingFavorites = true;
    try {
      final user = await _userRepository.getCurrentUser();
      if (!mounted) return;
      setState(() => _favoriteIds = user.favorites.toSet());
    } finally {
      _isRefreshingFavorites = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AsyncStateView(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _load();
        },
      );
    }
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final products = _filteredProducts;

    return GradientScaffoldView(
      bottomNavigationBar: const SwapioBottomNavView(currentRoute: AppRoutesView.home),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'SwappIO - Home',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Hi, $_userName',
                              style: const TextStyle(color: AppColorsView.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No tienes notificaciones nuevas.')),
                          );
                        },
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search for clothes, brands...',
                      prefixIcon: Icon(Icons.search_rounded),
                      suffixIcon: Icon(Icons.tune_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _tags.map((tag) {
                        final selected = tag == _selectedTag;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tag),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedTag = tag),
                            selectedColor: AppColorsView.primary,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : AppColorsView.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.35),
                            side: BorderSide.none,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Products Now',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = products[index];
                  final isFavorite = _favoriteIds.contains(product.id);
                  return ProductCardView(
                    product: product,
                    isFavorite: isFavorite,
                    onFavoriteTap: () async {
                      await _userRepository.toggleFavorite(product.id);
                      await _refreshFavorites();
                    },
                    onTap: () async {
                      await Navigator.of(context).pushNamed(
                        AppRoutesView.productDetail,
                        arguments: product.id,
                      );
                      await _refreshFavorites();
                      await _load();
                    },
                  );
                },
                childCount: products.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



