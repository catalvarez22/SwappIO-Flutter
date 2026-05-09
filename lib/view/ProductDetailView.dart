import 'package:flutter/material.dart';

import '../viewModel/AppServicesViewModel.dart';
import 'shared/AppColorsView.dart';
import '../model/AppUserModel.dart';
import '../model/MockPaymentResultModel.dart';
import '../model/ProductModel.dart';
import 'shared/AppRoutesView.dart';
import 'shared/AsyncStateView.dart';
import 'shared/GlassPanelView.dart';

class ProductDetailView extends StatefulWidget {
  const ProductDetailView({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  final _productRepository = AppServicesViewModel.instance.productRepository;
  final _userRepository = AppServicesViewModel.instance.userRepository;
  final _chatRepository = AppServicesViewModel.instance.chatRepository;
  final _paymentGateway = AppServicesViewModel.instance.paymentGatewayRepository;
  bool? _favoriteOverride;
  bool _isFavoriteUpdating = false;
  bool _isPurchasing = false;

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _buyProduct(ProductModel product) async {
    final checkoutRequest = await showModalBottomSheet<_MockCheckoutRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MockCheckoutSheet(product: product),
    );
    if (checkoutRequest == null) return;

    try {
      if (mounted) {
        setState(() => _isPurchasing = true);
      }
      final paymentResult = await _paymentGateway.authorizePayment(
        amount: product.price,
        productId: product.id,
        productName: product.name,
        paymentMethod: checkoutRequest.paymentMethod,
        cardholderName: checkoutRequest.cardholderName,
        cardNumber: checkoutRequest.cardNumber,
        expiryDate: checkoutRequest.expiryDate,
        cvv: checkoutRequest.cvv,
        installments: checkoutRequest.installments,
      );
      await _productRepository.purchaseProduct(product.id);
      if (!mounted) return;
      await _showPaymentApprovedDialog(paymentResult, product);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutesView.purchases,
        ModalRoute.withName(AppRoutesView.home),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _toggleFavorite(ProductModel product, AppUserModel currentUser) async {
    if (_isFavoriteUpdating) return;
    final currentValue = _favoriteOverride ?? currentUser.favorites.contains(product.id);
    setState(() {
      _favoriteOverride = !currentValue;
      _isFavoriteUpdating = true;
    });
    try {
      await _userRepository.toggleFavorite(product.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _favoriteOverride = currentValue);
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isFavoriteUpdating = false);
      }
    }
  }

  Future<void> _showPaymentApprovedDialog(
    MockPaymentResultModel paymentResult,
    ProductModel product,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pago aprobado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Producto: ${product.name}'),
            const SizedBox(height: 8),
            Text('Monto: \$${paymentResult.amount.toStringAsFixed(0)} COP'),
            const SizedBox(height: 8),
            Text('Metodo: ${paymentResult.paymentMethod}'),
            const SizedBox(height: 8),
            Text('Tarjeta: ${paymentResult.maskedCardNumber}'),
            const SizedBox(height: 8),
            Text('Autorizacion: ${paymentResult.authorizationCode}'),
            const SizedBox(height: 8),
            Text('Transaccion: ${paymentResult.transactionId}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: _loadData(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AsyncStateView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final product = snapshot.data![0] as ProductModel;
        final owner = snapshot.data![1] as AppUserModel;
        final currentUser = snapshot.data![2] as AppUserModel;
        final suggestions = snapshot.data![3] as List<ProductModel>;
        final isOwner = currentUser.id == owner.id;
        final isFavorite = _favoriteOverride ?? currentUser.favorites.contains(product.id);
        return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    SizedBox(height: 360, child: _ProductHero(colors: product.images)),
                    Positioned(
                      top: 48,
                      left: 16,
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.7),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -32),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    child: Column(
                      children: [
                        GlassPanelView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Size ${product.size}', style: const TextStyle(color: AppColorsView.textMuted, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(product.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 16, color: AppColorsView.textMuted),
                                            const SizedBox(width: 4),
                                            Expanded(child: Text(product.location, style: const TextStyle(color: AppColorsView.textMuted))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '\$${product.price.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColorsView.primary),
                                  ),
                                  if (!isOwner)
                                    IconButton(
                                      onPressed: _isFavoriteUpdating
                                          ? null
                                          : () => _toggleFavorite(product, currentUser),
                                      icon: Icon(
                                        isFavorite
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: isFavorite
                                            ? Colors.pink
                                            : AppColorsView.textPrimary,
                                      ),
                                    ),
                                ],
                              ),
                              const Divider(height: 28),
                              const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(product.description, style: const TextStyle(color: AppColorsView.textMuted)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _Badge(
                                    label: product.condition,
                                    background: _conditionBackground(product.condition),
                                    foreground: _conditionColor(product.condition),
                                  ),
                                  ...product.styleTags.map((tag) => _Badge(label: tag)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (product.latitude != null && product.longitude != null)
                          GlassPanelView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Meetup Location', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 10),
                                Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(colors: [Color(0xFFB2DFDB), Color(0xFFE0F2F1)]),
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.place_rounded, size: 36, color: AppColorsView.primary),
                                        SizedBox(height: 8),
                                        Text('Mapa mock del punto de encuentro'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => Navigator.of(context).pushNamed(AppRoutesView.sellerProfile, arguments: owner.id),
                          child: GlassPanelView(
                            child: Row(
                              children: [
                                CircleAvatar(radius: 24, backgroundColor: Colors.white, child: Text(owner.name.substring(0, 1))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(owner.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      const Row(
                                        children: [
                                          Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC107)),
                                          SizedBox(width: 4),
                                          Text('Vendedor', style: TextStyle(color: AppColorsView.textMuted, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isOwner)
                                  IconButton(
                                    onPressed: () async {
                                      try {
                                        final chatId = await _chatRepository.startChatForProduct(product.id);
                                        if (!mounted) return;
                                        Navigator.of(context).pushNamed(AppRoutesView.chatDetail, arguments: chatId);
                                      } catch (error) {
                                        if (!mounted) return;
                                        _showMessage(
                                          error.toString().replaceFirst('Exception: ', ''),
                                          isError: true,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.chat_bubble_rounded, color: AppColorsView.primary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('You Might Also Like', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 260,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: suggestions.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final suggested = suggestions[index];
                                return SizedBox(
                                  width: 180,
                                  child: Card(
                                    color: Colors.white.withOpacity(0.7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: () => Navigator.of(context).pushReplacementNamed(
                                        AppRoutesView.productDetail,
                                        arguments: suggested.id,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: _ProductHero(colors: suggested.images)),
                                            const SizedBox(height: 10),
                                            Text(suggested.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text('\$${suggested.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: GlassPanelView(
              padding: const EdgeInsets.all(16),
              radius: 24,
              child: Row(
                children: isOwner
                    ? [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Listing'),
                                  content: const Text('Are you sure you want to permanently delete this product?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  await _productRepository.deleteProduct(product.id);
                                  if (!mounted) return;
                                  _showMessage('Publicacion eliminada.');
                                  Navigator.of(context).pop();
                                } catch (error) {
                                  if (!mounted) return;
                                  _showMessage(
                                    error.toString().replaceFirst('Exception: ', ''),
                                    isError: true,
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.12),
                              foregroundColor: Colors.red,
                            ),
                            label: const Text('Delete Listing'),
                          ),
                        ),
                      ]
                    : [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Price', style: TextStyle(fontSize: 10, color: AppColorsView.textMuted, fontWeight: FontWeight.w700)),
                              Text('\$${product.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _buyProduct(product),
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: const Text('Buy Now'),
                          ),
                        ),
                      ],
              ),
            ),
          ),
          if (_isPurchasing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(0.22),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
        );
      },
    );
  }

  Future<List<Object>> _loadData() async {
    final product = await _productRepository.getProductById(widget.productId);
    final owner = await _userRepository.getUserById(product.ownerId);
    final currentUser = await _userRepository.getCurrentUser();
    final suggestions = await _productRepository.getSuggestions(product.id);
    return [product, owner, currentUser, suggestions];
  }

  Color _conditionBackground(String condition) {
    switch (condition) {
      case 'New with tags':
        return const Color(0xFFE8F5E9);
      case 'Like New':
        return const Color(0xFFE3F2FD);
      case 'Good':
        return const Color(0xFFFFF3E0);
      case 'Fair':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Color _conditionColor(String condition) {
    switch (condition) {
      case 'New with tags':
        return const Color(0xFF2E7D32);
      case 'Like New':
        return const Color(0xFF1565C0);
      case 'Good':
        return const Color(0xFFEF6C00);
      case 'Fair':
        return const Color(0xFFC62828);
      default:
        return Colors.black54;
    }
  }
}

class _MockCheckoutRequest {
  const _MockCheckoutRequest({
    required this.paymentMethod,
    required this.cardholderName,
    required this.cardNumber,
    required this.expiryDate,
    required this.cvv,
    required this.installments,
  });

  final String paymentMethod;
  final String cardholderName;
  final String cardNumber;
  final String expiryDate;
  final String cvv;
  final int installments;
}

class _MockCheckoutSheet extends StatefulWidget {
  const _MockCheckoutSheet({required this.product});

  final ProductModel product;

  @override
  State<_MockCheckoutSheet> createState() => _MockCheckoutSheetState();
}

class _MockCheckoutSheetState extends State<_MockCheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Catalina Rojas');
  final _cardController = TextEditingController(text: '4242 4242 4242 4242');
  final _expiryController = TextEditingController(text: '12/28');
  final _cvvController = TextEditingController(text: '123');
  String _paymentMethod = 'Tarjeta de credito';
  int _installments = 1;

  @override
  void dispose() {
    _nameController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset + 16),
      child: GlassPanelView(
        radius: 28,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pasarela de pago mock',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Estas pagando ${widget.product.name} por \$${widget.product.price.toStringAsFixed(0)} COP.',
                  style: const TextStyle(color: AppColorsView.textMuted),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: _inputDecoration('Metodo de pago'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Tarjeta de credito',
                      child: Text('Tarjeta de credito'),
                    ),
                    DropdownMenuItem(
                      value: 'Tarjeta debito',
                      child: Text('Tarjeta debito'),
                    ),
                    DropdownMenuItem(
                      value: 'PSE mock',
                      child: Text('PSE mock'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _paymentMethod = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Titular'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el titular.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cardController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Numero de tarjeta mock'),
                  validator: (value) {
                    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                    if (digits.length < 16) {
                      return 'Ingresa 16 digitos.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiryController,
                        keyboardType: TextInputType.datetime,
                        decoration: _inputDecoration('MM/AA'),
                        validator: (value) {
                          if (value == null || !RegExp(r'^\d{2}/\d{2}$').hasMatch(value.trim())) {
                            return 'Formato invalido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cvvController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('CVV'),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || !RegExp(r'^\d{3,4}$').hasMatch(value.trim())) {
                            return 'CVV invalido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _installments,
                  decoration: _inputDecoration('Cuotas'),
                  items: List<DropdownMenuItem<int>>.generate(
                    6,
                    (index) {
                      final installments = index + 1;
                      return DropdownMenuItem(
                        value: installments,
                        child: Text('$installments ${installments == 1 ? 'cuota' : 'cuotas'}'),
                      );
                    },
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _installments = value);
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Tarjeta mock de prueba: usa cualquier numero valido de 16 digitos. Si termina en 0000, el pago se rechaza.',
                    style: TextStyle(fontSize: 12, color: AppColorsView.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.lock_rounded),
                    label: const Text('Autorizar pago mock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.85),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      _MockCheckoutRequest(
        paymentMethod: _paymentMethod,
        cardholderName: _nameController.text.trim(),
        cardNumber: _cardController.text.trim(),
        expiryDate: _expiryController.text.trim(),
        cvv: _cvvController.text.trim(),
        installments: _installments,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.background = Colors.white,
    this.foreground = AppColorsView.textPrimary,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: foreground),
      ),
    );
  }
}

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.colors});

  final List<String> colors;

  @override
  Widget build(BuildContext context) {
    final networkImage = _networkImage();
    if (networkImage != null) {
      return Image.network(
        networkImage,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildGradientHero(),
      );
    }
    return _buildGradientHero();
  }

  Widget _buildGradientHero() {
    final parsed = colors
        .map((value) => _hexToColor(value))
        .whereType<Color>()
        .toList();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: parsed.length >= 2 ? parsed : [Colors.blueGrey, Colors.white],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 40,
            right: 40,
            top: 24,
            bottom: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(42),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _networkImage() {
    for (final value in colors) {
      if (value.startsWith('http')) return value;
    }
    return null;
  }

  Color? _hexToColor(String value) {
    final normalized = value.replaceAll('#', '');
    if (normalized.length != 6) return null;
    return Color(int.parse('FF$normalized', radix: 16));
  }
}






