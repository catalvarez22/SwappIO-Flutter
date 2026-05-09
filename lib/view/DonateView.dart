import 'package:flutter/material.dart';

import '../model/CharityModel.dart';
import '../viewModel/AppServicesViewModel.dart';
import 'shared/AppColorsView.dart';
import 'shared/AppRoutesView.dart';
import 'shared/AsyncStateView.dart';
import 'shared/GradientScaffoldView.dart';
import 'shared/SwapioBottomNavView.dart';

class DonateView extends StatefulWidget {
  const DonateView({super.key});

  @override
  State<DonateView> createState() => _DonateViewState();
}

class _DonateViewState extends State<DonateView> {
  final _charityRepository = AppServicesViewModel.instance.charityRepository;
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<CharityModel> _charities = const [];
  bool _isLoading = true;
  String? _error;

  List<String> get _categories => const [
        'All',
        'Women',
        'Children',
        'Winter Gear',
        'Professional',
      ];

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
      final charities = await _charityRepository.getCharities();
      if (!mounted) return;
      setState(() {
        _charities = charities;
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

  List<CharityModel> get _filtered {
    final query = _searchController.text.toLowerCase();
    return _charities.where((charity) {
      final matchesSearch = query.isEmpty ||
          charity.name.toLowerCase().contains(query) ||
          charity.location.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == 'All' ||
          charity.tags.any((tag) => tag.toLowerCase() == _selectedCategory.toLowerCase());
      return matchesSearch && matchesCategory;
    }).toList();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final charities = _filtered;
    final featured = charities.isNotEmpty ? charities.first : null;
    final remainingCharities = featured == null
        ? charities
        : charities.where((charity) => charity.id != featured.id).toList();

    return GradientScaffoldView(
      bottomNavigationBar: const SwapioBottomNavView(currentRoute: AppRoutesView.donate),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'Donate to Charities',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No hay filtros avanzados adicionales por ahora.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search charities in Bogota...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((category) {
                        final isSelected = category == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedCategory = category),
                            selectedColor: AppColorsView.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColorsView.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'FEATURED CAUSE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColorsView.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (featured != null)
                    _FeaturedCharityCard(
                      charity: featured,
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRoutesView.charityDetail,
                        arguments: featured.id,
                      ),
                    ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ALL CHARITIES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColorsView.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: remainingCharities.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text('No hay fundaciones para mostrar con este filtro.'),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final charity = remainingCharities[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CharityCard(
                            charity: charity,
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutesView.charityDetail,
                              arguments: charity.id,
                            ),
                          ),
                        );
                      },
                      childCount: remainingCharities.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCharityCard extends StatelessWidget {
  const _FeaturedCharityCard({required this.charity, required this.onTap});

  final CharityModel charity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 215,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF7A8332), Color(0xFF5D6F2C), Color(0xFF95C2D6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E98B0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'FEATURED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.location_on_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 2),
                Text(charity.location, style: const TextStyle(color: Colors.white)),
              ],
            ),
            const Spacer(),
            Text(
              charity.name,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              charity.description,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ...charity.tags.take(2).map(
                  (tag) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColorsView.primary,
                  ),
                  child: const Text('Donate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CharityCard extends StatelessWidget {
  const _CharityCard({required this.charity, required this.onTap});

  final CharityModel charity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.58),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColorsView.primary.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: AppColorsView.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(charity.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        charity.location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColorsView.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppColorsView.primary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              charity.description,
              style: const TextStyle(color: AppColorsView.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ...charity.tags.take(2).map(
                  (tag) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColorsView.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 11, color: AppColorsView.primary),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  charity.distance,
                  style: const TextStyle(
                    color: AppColorsView.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
