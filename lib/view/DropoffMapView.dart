import 'package:flutter/material.dart';

import '../model/DropoffPointModel.dart';
import '../viewModel/AppServicesViewModel.dart';
import 'shared/AppColorsView.dart';
import 'shared/AsyncStateView.dart';

class DropoffMapView extends StatefulWidget {
  const DropoffMapView({super.key});

  @override
  State<DropoffMapView> createState() => _DropoffMapViewState();
}

class _DropoffMapViewState extends State<DropoffMapView> {
  String? _selectedPointId;

  @override
  Widget build(BuildContext context) {
    final dropOffRepository = AppServicesViewModel.instance.dropOffRepository;

    return FutureBuilder<List<DropoffPointModel>>(
      future: dropOffRepository.getDropOffPoints(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AsyncStateView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final points = snapshot.data!;
        if (points.isEmpty) {
          return const AsyncStateView(
            message: 'No hay puntos de entrega disponibles.',
          );
        }
        final selectedPoint = points.firstWhere(
          (point) => point.id == _selectedPointId,
          orElse: () => points.first,
        );

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'Drop-off Map',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFB2DFDB), Color(0xFFE0F2F1)],
                                ),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _MapGridPainter(),
                                        ),
                                      ),
                                      ...points.map((point) {
                                        final isSelected = point.id == selectedPoint.id;
                                        final dx = ((point.longitude + 74.18) / 0.18) *
                                            constraints.maxWidth;
                                        final dy = ((4.78 - point.latitude) / 0.20) *
                                            constraints.maxHeight;
                                        return Positioned(
                                          left: dx - 16,
                                          top: dy - 32,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() => _selectedPointId = point.id);
                                            },
                                            child: Icon(
                                              Icons.place_rounded,
                                              size: isSelected ? 38 : 30,
                                              color: isSelected
                                                  ? const Color(0xFF0F766E)
                                                  : AppColorsView.primary,
                                            ),
                                          ),
                                        );
                                      }),
                                      Positioned(
                                        left: 16,
                                        right: 16,
                                        bottom: 16,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                selectedPoint.name,
                                                style: const TextStyle(fontWeight: FontWeight.w800),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                selectedPoint.address,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColorsView.textMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${selectedPoint.opensAt} - ${selectedPoint.closesAt}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColorsView.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: points.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final point = points[index];
                                final isSelected = point.id == selectedPoint.id;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    setState(() => _selectedPointId = point.id);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFDFF6F3)
                                          : Colors.white.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColorsView.primary.withOpacity(0.35)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: Color(0x1A077288),
                                          child: Icon(
                                            Icons.place_rounded,
                                            color: AppColorsView.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                point.name,
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                point.address,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColorsView.textMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${point.opensAt} - ${point.closesAt}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColorsView.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.my_location_rounded),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
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
      ..moveTo(size.width * 0.16, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.48,
        size.width * 0.42,
        size.height * 0.26,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.14,
        size.width * 0.8,
        size.height * 0.34,
      );
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
