import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../viewModel/AppServicesViewModel.dart';
import '../viewModel/ConnectivityServiceViewModel.dart';
import 'shared/AppColorsView.dart';
import 'shared/AppRoutesView.dart';
import 'shared/GlassPanelView.dart';

class AddProductView extends StatefulWidget {
  const AddProductView({super.key});

  @override
  State<AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<AddProductView> {
  static const int _titleMaxLength = 60;
  static const int _brandMaxLength = 40;
  static const int _descriptionMaxLength = 280;
  static const int _locationMaxLength = 80;

  final _productRepository = AppServicesViewModel.instance.productRepository;
  final _title = TextEditingController();
  final _brand = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final List<String> _selectedImages = [];
  final Set<String> _styleTags = {};
  String _size = 'M';
  String _condition = 'Good';
  bool _hasMapSelection = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _error;
  bool _isLoading = false;

  final _mockImagePalette = const [
    '#6D8DA7',
    '#DCC4B8',
    '#4D7B63',
    '#8C684D',
    '#B3628A',
  ];

  final _availableTags = const [
    'Denim',
    'Old Money',
    'Y2K',
    'Vintage',
    'Streetwear',
    'Minimalist',
    'Coquette',
    'Gorpcore',
  ];

  @override
  void dispose() {
    _title.dispose();
    _brand.dispose();
    _price.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final connectivity = ConnectivityServiceViewModel();
    final hasInternet = await connectivity.isConnected;

    if (!hasInternet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. You cannot publish products offline.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_title.text.trim().isEmpty ||
        _price.text.trim().isEmpty ||
        _description.text.trim().isEmpty ||
        _location.text.trim().isEmpty) {
      setState(() {
        _error = 'Completa todos los campos obligatorios: titulo, precio, descripcion y ubicacion.';
      });
      return;
    }
    if (_selectedImages.isEmpty) {
      setState(() => _error = 'Debes agregar al menos 1 foto.');
      return;
    }
    if (!_hasMapSelection) {
      setState(() => _error = 'Selecciona una ubicacion valida en el mapa.');
      return;
    }

    final parsedPrice = double.tryParse(_price.text.replaceAll(',', '.'));
    if (parsedPrice == null || parsedPrice <= 0) {
      setState(() => _error = 'El precio debe ser un numero positivo mayor que cero.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _productRepository.createProduct(
        title: _title.text.trim(),
        brand: _brand.text.trim(),
        price: parsedPrice,
        size: _size,
        condition: _condition,
        description: _description.text.trim(),
        location: _location.text.trim(),
        tags: _styleTags.toList(),
        images: List<String>.from(_selectedImages),
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicacion creada correctamente.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutesView.home,
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addMockImage() {
    if (_selectedImages.length >= 3) return;
    setState(() {
      _selectedImages.add(
        _mockImagePalette[_selectedImages.length % _mockImagePalette.length],
      );
    });
  }

  void _selectMapLocation(Offset localPosition, Size size) {
    const minLat = 4.58;
    const maxLat = 4.78;
    const minLng = -74.18;
    const maxLng = -74.00;

    final normalizedX = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final normalizedY = (localPosition.dy / size.height).clamp(0.0, 1.0);

    final latitude = maxLat - ((maxLat - minLat) * normalizedY);
    final longitude = minLng + ((maxLng - minLng) * normalizedX);

    setState(() {
      _hasMapSelection = true;
      _selectedLatitude = latitude;
      _selectedLongitude = longitude;
    });
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Como publicar'),
        content: const Text(
          '1. Agrega al menos una foto.\n'
          '2. Completa titulo, precio, descripcion y ubicacion.\n'
          '3. Toca el mapa para fijar la ubicacion.\n'
          '4. Publica el item y vuelve al inicio automaticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'List an Item',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(onPressed: _showHelp, child: const Text('Help')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColorsView.danger.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColorsView.danger.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColorsView.danger,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _addMockImage,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Take Photo'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _addMockImage,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _PhotoSlot(
                                  filled: _selectedImages.isNotEmpty,
                                  label: 'Cover Photo',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: _PhotoSlot(
                                        filled: _selectedImages.length > 1,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: _PhotoSlot(
                                        filled: _selectedImages.length > 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _title,
                          inputFormatters: const [
                            LengthLimitingTextInputFormatter(_titleMaxLength),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'e.g. Vintage Denim Jacket',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _brand,
                          inputFormatters: const [
                            LengthLimitingTextInputFormatter(_brandMaxLength),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Brand (Optional)',
                            hintText: 'e.g. Levi\'s, Nike, Zara',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}$')),
                            LengthLimitingTextInputFormatter(12),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Price (COP)',
                            prefixText: '\$ ',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _size,
                                decoration: const InputDecoration(labelText: 'Size'),
                                items: const ['S', 'M', 'L', 'XL', 'Unique']
                                    .map(
                                      (item) => DropdownMenuItem(
                                        value: item,
                                        child: Text(item),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setState(() => _size = value ?? _size),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _condition,
                                decoration: const InputDecoration(labelText: 'Condition'),
                                items: const ['New with tags', 'Like New', 'Good', 'Fair']
                                    .map(
                                      (item) => DropdownMenuItem(
                                        value: item,
                                        child: Text(item),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setState(
                                  () => _condition = value ?? _condition,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Style Tags (Max 3)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableTags.map((tag) {
                            final selected = _styleTags.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  if (selected) {
                                    _styleTags.remove(tag);
                                  } else if (_styleTags.length < 3) {
                                    _styleTags.add(tag);
                                  }
                                });
                              },
                              selectedColor: AppColorsView.primary,
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : AppColorsView.textPrimary,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _description,
                          minLines: 4,
                          maxLines: 5,
                          inputFormatters: const [
                            LengthLimitingTextInputFormatter(_descriptionMaxLength),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Describe the item\'s condition, brand...',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Location', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _location,
                          inputFormatters: const [
                            LengthLimitingTextInputFormatter(_locationMaxLength),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Approximate area',
                            hintText: 'e.g. Chapinero, Bogota',
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassPanelView(
                          radius: 18,
                          padding: EdgeInsets.zero,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const mapHeight = 220.0;
                              return GestureDetector(
                                onTapDown: (details) => _selectMapLocation(
                                  details.localPosition,
                                  Size(constraints.maxWidth, mapHeight),
                                ),
                                child: SizedBox(
                                  height: mapHeight,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(18),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFB2DFDB),
                                                Color(0xFFE0F2F1),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _MapGridPainter(),
                                        ),
                                      ),
                                      if (_hasMapSelection &&
                                          _selectedLatitude != null &&
                                          _selectedLongitude != null)
                                        Positioned(
                                          left: (((_selectedLongitude! + 74.18) / 0.18) *
                                                  constraints.maxWidth) -
                                              16,
                                          top: (((4.78 - _selectedLatitude!) / 0.20) *
                                                  mapHeight) -
                                              32,
                                          child: const Icon(
                                            Icons.place_rounded,
                                            size: 32,
                                            color: AppColorsView.primary,
                                          ),
                                        ),
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _hasMapSelection
                                                    ? Icons.check_circle_rounded
                                                    : Icons.map_outlined,
                                                size: 40,
                                                color: AppColorsView.primary,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _hasMapSelection
                                                    ? 'Ubicacion seleccionada: ${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}'
                                                    : 'Toca el mapa para seleccionar la ubicacion exacta',
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('List Item'),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(0.18),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({this.filled = false, this.label});

  final bool filled;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GlassPanelView(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: filled
              ? const LinearGradient(colors: [Color(0xFF90CAF9), Color(0xFFE3F2FD)])
              : null,
        ),
        child: Center(
          child: filled
              ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 30)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: AppColorsView.primary),
                    if (label != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        label!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColorsView.primary,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..strokeWidth = 1;
    final routePaint = Paint()
      ..color = AppColorsView.primary.withOpacity(0.18)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var column = 1; column < 4; column++) {
      final x = (size.width / 4) * column;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var row = 1; row < 4; row++) {
      final y = (size.height / 4) * row;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.55,
        size.width * 0.4,
        size.height * 0.3,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.16,
        size.width * 0.82,
        size.height * 0.38,
      );
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
