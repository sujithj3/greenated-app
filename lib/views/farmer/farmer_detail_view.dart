import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/api/api_models.dart';
import '../../services/auth_service.dart';
import '../../utils/field_fill_state.dart';
import '../../services/registration_form_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/snack_bar_helper.dart';
import '../../view_models/farmer/farmer_detail_view_model.dart';
import '../../widgets/dynamic_field_builder.dart';
import '../../widgets/shimmer_loading.dart';

class FarmerDetailView extends StatefulWidget {
  final int subcategoryId;
  final int submissionId;

  const FarmerDetailView({
    super.key,
    required this.subcategoryId,
    required this.submissionId,
  });

  @override
  State<FarmerDetailView> createState() => _FarmerDetailViewState();
}

class _FarmerDetailViewState extends State<FarmerDetailView> {
  late final FarmerDetailViewModel _vm;
  final Map<String, TextEditingController> _textCtrl = {};
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _vm = FarmerDetailViewModel(
      service: context.read<RegistrationFormService>(),
      authService: context.read<AuthService>(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) return;
    _isInit = true;

    _vm.addListener(_onVmChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _vm.loadFormDetail(
          subcategoryId: widget.subcategoryId,
          submissionId: widget.submissionId,
        );
      }
    });
  }

  void _onVmChanged() {
    if (!mounted) return;
    _syncTextControllers();
    setState(() {});
  }

  void _syncTextControllers() {
    final currentKeys = _vm.fields.map((df) => df.field.key).toSet();
    _textCtrl.removeWhere((key, ctrl) {
      if (!currentKeys.contains(key)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });

    for (final df in _vm.fields) {
      final f = df.field;
      if (f.fieldStyle == FieldStyle.text ||
          f.fieldStyle == FieldStyle.number ||
          f.fieldStyle == FieldStyle.date) {
        var initial = df.value?.toString() ?? '';
        if (f.fieldStyle == FieldStyle.date && initial.isNotEmpty) {
          initial = formatDateForDisplay(initial);
        }
        if (!_textCtrl.containsKey(f.key)) {
          _textCtrl[f.key] = TextEditingController(text: initial);
        } else if (_textCtrl[f.key]!.text != initial) {
          _textCtrl[f.key]!.text = initial;
        }
      }
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    for (final c in _textCtrl.values) {
      c.dispose();
    }
    _vm.dispose();
    super.dispose();
  }

  Future<void> _openViewOnlyPopupSheet(DynamicFieldModel df) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ViewOnlyPopupSheet(
        parentField: df.field,
        fields: df.value as List<DynamicFieldModel>? ?? [],
        onGenerateKml: (subDf) => _generateAndShareKml(subDf),
      ),
    );
  }

  Future<void> _openViewOnlyMap(DynamicFieldModel df) async {
    await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': df.value,
        'viewOnly': true,
      },
    );
  }

  Future<void> _generateAndShareKml(DynamicFieldModel df) async {
    try {
      final rawList = df.value is List ? df.value as List : null;
      if (rawList == null || rawList.isEmpty) {
        if (mounted) context.showSnack('Unable to generate kml file');
        return;
      }

      final coords = rawList
          .whereType<Map>()
          .map((e) {
            final lat = (e['lat'] as num?)?.toDouble();
            final lng = (e['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) return null;
            return (lat: lat, lng: lng);
          })
          .whereType<({double lat, double lng})>()
          .toList();

      if (coords.isEmpty) {
        if (mounted) context.showSnack('Unable to generate kml file');
        return;
      }

      // KML polygons must be closed — repeat first point at end.
      final closed = [...coords];
      if (closed.first.lat != closed.last.lat ||
          closed.first.lng != closed.last.lng) {
        closed.add(closed.first);
      }

      final coordLines =
          closed.map((c) => '              ${c.lng},${c.lat},0').join('\n');

      final now = DateTime.now();
      final dateStr = DateFormat('dd-MMM-yyyy').format(now);

      final packageInfo = await PackageInfo.fromPlatform();
      final appName =
          packageInfo.appName.isNotEmpty ? packageInfo.appName : 'App';
      final docName = '${appName}_KML_FormID(${widget.submissionId})_$dateStr';

      final kmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>$docName</name>
    <Placemark>
      <name>Land Polygon</name>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
$coordLines
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>''';

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$docName.kml');
      await file.writeAsString(kmlContent);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [
          XFile(file.path)
        ], // Removed strict mimeType so iOS auto-infers from .kml
        subject: docName,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null, // Required for iPads so the app doesn't crash
      );
    } catch (e) {
      debugPrint('Error generating KML: $e');
      if (mounted) context.showSnack('Unable to generate KML file. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_vm.formName.isNotEmpty ? _vm.formName : 'Detail'),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/edit-farmer-details',
                    arguments: {
                      'subcategoryId': widget.subcategoryId,
                      'submissionId': widget.submissionId,
                    },
                  );

                  if (result == true && context.mounted) {
                    // Small delay to allow iOS CupertinoPageRoute pop animation to complete
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    });
                  }
                },
                icon: const Icon(Icons.edit, size: 18, color: AppColors.white),
                label: const Text(
                  'Edit',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_vm.isLoading) {
      return const ShimmerFormSkeleton();
    }

    if (_vm.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 40, color: AppColors.textMedium),
              const SizedBox(height: 12),
              const Text(
                'Unable to load form detail',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(_vm.error!,
                  style: const TextStyle(color: AppColors.textMedium),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _vm.loadFormDetail(
                  subcategoryId: widget.subcategoryId,
                  submissionId: widget.submissionId,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_vm.fields.isEmpty && _vm.landDetails.isEmpty) {
      return const Center(
        child: Text('No data available',
            style: TextStyle(color: AppColors.textMedium, fontSize: 16)),
      );
    }

    final visibleFields =
        _vm.fields.where((df) => shouldShowField(df, _vm.fields)).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            ...visibleFields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildField(field),
              ),
            ),
            const SizedBox(height: 16),
            LandDetailsSection(
              lands: _vm.landDetails,
              onLandTap: (land) {
                // TODO: Navigate to land detail/edit screen using landId/submissionId.
              },
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: AddNewLandButton(
            onPressed: () {
              // TODO: Navigate to add new land flow.
            },
          ),
        ),
      ],
    );
  }

  Widget _buildField(DynamicFieldModel df) {
    final f = df.field;

    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isPopupForm) {
      final subFields = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = getTotalCount(subFields);
      popupFormFilled = getFilledCount(subFields);
    }

    final isCameraField = f.fieldStyle == FieldStyle.camera ||
        f.fieldStyle == FieldStyle.cameraFile;

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: AppColors.primary,
      onChanged: (_) {},
      isViewMode: true,
      onPopupFormPressed:
          f.isPopupForm ? () => _openViewOnlyPopupSheet(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openViewOnlyMap(df)
          : null,
      onGenerateKml: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _generateAndShareKml(df)
          : null,
      resolvedOptions:
          f.fieldStyle == FieldStyle.dropdown ? df.resolvedOptions : null,
      previewUrl: isCameraField ? df.previewUrl : null,
    );
  }
}

class LandDetailsSection extends StatelessWidget {
  const LandDetailsSection({
    super.key,
    required this.lands,
    required this.onLandTap,
  });

  final List<LandDetail> lands;
  final ValueChanged<LandDetail> onLandTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Land Details - (${lands.length})',
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        if (lands.isEmpty)
          const EmptyLandDetailsView()
        else
          ...lands.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LandDetailCard(
                land: entry.$2,
                index: entry.$1,
                onTap: () => onLandTap(entry.$2),
              ),
            ),
          ),
      ],
    );
  }
}

class LandDetailCard extends StatelessWidget {
  const LandDetailCard({
    super.key,
    required this.land,
    required this.index,
    required this.onTap,
  });

  final LandDetail land;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = land.landTitle?.trim().isNotEmpty == true
        ? land.landTitle!.trim()
        : 'Land ${_numberWord(index + 1)}';
    final code =
        land.landCode?.trim().isNotEmpty == true ? land.landCode!.trim() : '-';

    return Material(
      color: AppColors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      code,
                      style: const TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMedium,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyLandDetailsView extends StatelessWidget {
  const EmptyLandDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: AppColors.light,
        radius: 16,
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 360),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.veryLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Image.asset(
                'assets/images/ic-land-green.png',
                width: 78,
                height: 78,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) {
                  // TODO: Add assets/images/ic-land-green.png to project assets.
                  return const Icon(
                    Icons.landscape_outlined,
                    color: AppColors.primary,
                    size: 76,
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No land added yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below\nto add land.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddNewLandButton extends StatelessWidget {
  const AddNewLandButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/ic-land-green.png',
                  width: 30,
                  height: 30,
                  color: AppColors.white,
                  errorBuilder: (_, __, ___) {
                    // TODO: Add assets/images/ic-land-green.png to project assets.
                    return const Icon(
                      Icons.landscape_outlined,
                      color: AppColors.white,
                      size: 18,
                    );
                  },
                ),
                const SizedBox(width: 1),
                const Text(
                  'Add New Land',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final metric in metrics) {
      var distance = 0.0;
      const dashWidth = 8.0;
      const dashSpace = 6.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

String _numberWord(int value) {
  return switch (value) {
    1 => 'One',
    2 => 'Two',
    3 => 'Three',
    4 => 'Four',
    5 => 'Five',
    6 => 'Six',
    7 => 'Seven',
    8 => 'Eight',
    9 => 'Nine',
    10 => 'Ten',
    _ => value.toString(),
  };
}

// ─── View-Only Popup Sheet ────────────────────────────────────────────────────

class _ViewOnlyPopupSheet extends StatefulWidget {
  final ApiField parentField;
  final List<DynamicFieldModel> fields;
  final void Function(DynamicFieldModel df)? onGenerateKml;

  const _ViewOnlyPopupSheet({
    required this.parentField,
    required this.fields,
    this.onGenerateKml,
  });

  @override
  State<_ViewOnlyPopupSheet> createState() => _ViewOnlyPopupSheetState();
}

class _ViewOnlyPopupSheetState extends State<_ViewOnlyPopupSheet> {
  final Map<String, TextEditingController> _textCtrl = {};

  @override
  void initState() {
    super.initState();
    for (final df in widget.fields) {
      final f = df.field;
      if (f.fieldStyle == FieldStyle.text ||
          f.fieldStyle == FieldStyle.number ||
          f.fieldStyle == FieldStyle.date) {
        var initText = df.value?.toString() ?? '';
        if (f.fieldStyle == FieldStyle.date && initText.isNotEmpty) {
          initText = formatDateForDisplay(initText);
        }
        _textCtrl[f.key] = TextEditingController(text: initText);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openNestedPopup(DynamicFieldModel df) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ViewOnlyPopupSheet(
        parentField: df.field,
        fields: df.value as List<DynamicFieldModel>? ?? [],
        onGenerateKml: widget.onGenerateKml,
      ),
    );
  }

  Future<void> _openViewOnlyMap(DynamicFieldModel df) async {
    await Navigator.pushNamed(
      context,
      '/land-measurement',
      arguments: {
        'initialPolygon': df.value,
        'viewOnly': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.parentField.label,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: widget.fields
                      .where((df) => shouldShowField(df, widget.fields))
                      .map((df) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildSubField(df),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubField(DynamicFieldModel df) {
    final f = df.field;

    int? popupFormFilled;
    int? popupFormTotal;
    if (f.isPopupForm) {
      final subFields = df.value as List<DynamicFieldModel>? ?? [];
      popupFormTotal = getTotalCount(subFields);
      popupFormFilled = getFilledCount(subFields);
    }

    final isCameraField = f.fieldStyle == FieldStyle.camera ||
        f.fieldStyle == FieldStyle.cameraFile;

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: AppColors.primary,
      onChanged: (_) {},
      isViewMode: true,
      onPopupFormPressed: f.isPopupForm ? () => _openNestedPopup(df) : null,
      popupFormFilledCount: popupFormFilled,
      popupFormTotalCount: popupFormTotal,
      onMapPolygonPressed: f.fieldStyle == FieldStyle.mapPolygon
          ? () => _openViewOnlyMap(df)
          : null,
      onGenerateKml: f.fieldStyle == FieldStyle.mapPolygon
          ? () => widget.onGenerateKml?.call(df)
          : null,
      resolvedOptions:
          f.fieldStyle == FieldStyle.dropdown ? df.resolvedOptions : null,
      previewUrl: isCameraField ? df.previewUrl : null,
    );
  }
}
