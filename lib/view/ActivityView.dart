import 'package:flutter/material.dart';

import '../viewModel/AppServicesViewModel.dart';
import '../model/AppUserModel.dart';
import '../model/ProductModel.dart';
import 'shared/AppRoutesView.dart';
import 'shared/AsyncStateView.dart';
import 'shared/GradientScaffoldView.dart';
import 'shared/ProductCardView.dart';

enum ActivityType { purchases, listings, favorites }

class ActivityViewArgs {
  const ActivityViewArgs({
    required this.title,
    required this.type,
  });

  final String title;
  final ActivityType type;
}

class ActivityView extends StatefulWidget {
  const ActivityView({super.key, required this.args});

  final ActivityViewArgs args;

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  final _userRepository = AppServicesViewModel.instance.userRepository;
  final _productRepository = AppServicesViewModel.instance.productRepository;
  late Future<List<Object>> _activityFuture;

  @override
  void initState() {
    super.initState();
    _activityFuture = _loadData();
  }

  Future<List<ProductModel>> _loadProducts() async {
    final user = await _userRepository.getCurrentUser();
    switch (widget.args.type) {
      case ActivityType.purchases:
        return _productRepository.getProductsByIds(user.purchases);
      case ActivityType.listings:
        return _productRepository.getProductsByIds(user.listings);
      case ActivityType.favorites:
        return _productRepository.getProductsByIds(user.favorites);
    }
  }

  Future<List<Object>> _loadData() {
    return Future.wait<Object>([
      _loadProducts(),
      _userRepository.getCurrentUser(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: _activityFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AsyncStateView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() => _activityFuture = _loadData()),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final products = snapshot.data![0] as List<ProductModel>;
        final user = snapshot.data![1] as AppUserModel;
        final favorites = user.favorites;
        return GradientScaffoldView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.args.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: Text('Aún no tienes elementos aquí.'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductCardView(
                          product: product,
                          isFavorite: favorites.contains(product.id),
                          onFavoriteTap: () async {
                            await _userRepository.toggleFavorite(product.id);
                            if (mounted) {
                              setState(() => _activityFuture = _loadData());
                            }
                          },
                          onTap: () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutesView.productDetail,
                              arguments: product.id,
                            );
                            if (mounted) {
                              setState(() => _activityFuture = _loadData());
                            }
                          },
                        );
                      },
                    ),
            ),
              ],
            ),
          ),
        );
      },
    );
  }
}








