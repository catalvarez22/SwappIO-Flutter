import 'package:flutter/material.dart';

import '../model/AppUserModel.dart';
import '../viewModel/AppServicesViewModel.dart';
import 'ActivityOptionCardView.dart';
import 'shared/AppColorsView.dart';
import 'shared/AppRoutesView.dart';
import 'shared/AsyncStateView.dart';
import 'shared/GlassPanelView.dart';
import 'shared/GradientScaffoldView.dart';
import 'shared/SwapioBottomNavView.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late Future<AppUserModel> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AppServicesViewModel.instance.userRepository.getCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final userRepository = AppServicesViewModel.instance.userRepository;
    final authRepository = AppServicesViewModel.instance.authRepository;

    return FutureBuilder<AppUserModel>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AsyncStateView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () {
              setState(() {
                _profileFuture = userRepository.getCurrentUser();
              });
            },
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data!;
        return GradientScaffoldView(
          bottomNavigationBar: const SwapioBottomNavView(
            currentRoute: AppRoutesView.profile,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 110),
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
                        'Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No hay ajustes adicionales disponibles.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    IconButton(
                      onPressed: () async {
                        await authRepository.logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutesView.login,
                          (_) => false,
                        );
                      },
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColorsView.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GlassPanelView(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          user.name.substring(0, 1),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColorsView.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user.location} - Member',
                        style: const TextStyle(color: AppColorsView.textMuted),
                      ),
                      const Divider(height: 30),
                      const Text(
                        'CURRENT BALANCE',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: AppColorsView.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\$${user.balance.toStringAsFixed(0)} COP',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColorsView.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: user.balance <= 0
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Retirar saldo'),
                                    content: Text(
                                      'Se retiraran \$${user.balance.toStringAsFixed(0)} COP de tu saldo disponible.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        child: const Text('Retirar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                try {
                                  await userRepository.withdrawBalance(user.balance);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Retiro registrado correctamente.'),
                                    ),
                                  );
                                  setState(() {
                                    _profileFuture = userRepository.getCurrentUser();
                                  });
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error.toString().replaceFirst('Exception: ', ''),
                                      ),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              },
                        child: const Text('Withdraw'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'My Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                ActivityOptionCardView(
                  title: 'My Purchases',
                  subtitle: '${user.purchases.length} active orders',
                  icon: Icons.shopping_bag_rounded,
                  iconColor: AppColorsView.primary,
                  iconBackground: AppColorsView.primary.withOpacity(0.1),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutesView.purchases),
                ),
                const SizedBox(height: 12),
                ActivityOptionCardView(
                  title: 'My Listings',
                  subtitle: '${user.listings.length} items for sale',
                  icon: Icons.storefront_rounded,
                  iconColor: const Color(0xFFEA580C),
                  iconBackground: const Color(0x1AEA580C),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutesView.listings),
                ),
                const SizedBox(height: 12),
                ActivityOptionCardView(
                  title: 'Favorites',
                  subtitle: '${user.favorites.length} saved items',
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFE11D48),
                  iconBackground: const Color(0x1AE11D48),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutesView.favorites),
                ),
                const SizedBox(height: 12),
                ActivityOptionCardView(
                  title: 'Dashboard de Negocio',
                  subtitle: 'Metricas BQ6, BQ9 y BQ10',
                  icon: Icons.analytics_rounded,
                  iconColor: Colors.indigo,
                  iconBackground: Colors.indigo.withOpacity(0.1),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutesView.reports),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
