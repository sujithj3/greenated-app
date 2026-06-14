import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/api/api_models.dart';
import '../../utils/app_colors.dart';
import '../../utils/field_fill_state.dart';
import '../../utils/snack_bar_helper.dart';
import '../../widgets/dynamic_field_builder.dart';

class LandDetailView extends StatefulWidget {
  const LandDetailView({
    super.key,
    required this.land,
    required this.title,
  });

  final LandDetail land;
  final String title;

  @override
  State<LandDetailView> createState() => _LandDetailViewState();
}

class _LandDetailViewState extends State<LandDetailView> {
  final Map<String, TextEditingController> _textCtrl = {};

  List<DynamicFieldModel> get _fields => widget.land.fields;

  @override
  void initState() {
    super.initState();
    _syncTextControllers();
  }

  void _syncTextControllers() {
    for (final df in _fields) {
      final f = df.field;
      if (f.fieldStyle == FieldStyle.text ||
          f.fieldStyle == FieldStyle.number ||
          f.fieldStyle == FieldStyle.date) {
        var initial = df.value?.toString() ?? '';
        if (f.fieldStyle == FieldStyle.date && initial.isNotEmpty) {
          initial = formatDateForDisplay(initial);
        }
        _textCtrl[f.key] = TextEditingController(text: initial);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _textCtrl.values) {
      controller.dispose();
    }
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
        onGenerateKml: _generateAndShareKml,
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

      final closed = [...coords];
      if (closed.first.lat != closed.last.lat ||
          closed.first.lng != closed.last.lng) {
        closed.add(closed.first);
      }

      final coordLines =
          closed.map((c) => '              ${c.lng},${c.lat},0').join('\n');
      final packageInfo = await PackageInfo.fromPlatform();
      final appName =
          packageInfo.appName.isNotEmpty ? packageInfo.appName : 'App';
      final dateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());
      final docName =
          '${appName}_KML_LandID(${widget.land.landId ?? '-'})_$dateStr';
      final kmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>$docName</name>
    <Placemark>
      <name>${widget.title}</name>
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
        [XFile(file.path)],
        subject: docName,
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      debugPrint('Error generating KML: $e');
      if (mounted) context.showSnack('Unable to generate KML file. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleFields =
        _fields.where((df) => shouldShowField(df, _fields)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: visibleFields.isEmpty
          ? const Center(
              child: Text(
                'No data available',
                style: TextStyle(color: AppColors.textMedium, fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visibleFields.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _buildField(visibleFields[index]),
            ),
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

    final isCameraField = f.fieldStyle == FieldStyle.camera;

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

class _ViewOnlyPopupSheet extends StatefulWidget {
  const _ViewOnlyPopupSheet({
    required this.parentField,
    required this.fields,
    this.onGenerateKml,
  });

  final ApiField parentField;
  final List<DynamicFieldModel> fields;
  final void Function(DynamicFieldModel df)? onGenerateKml;

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
    for (final controller in _textCtrl.values) {
      controller.dispose();
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
          color: AppColors.white,
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
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                      .map(
                        (df) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildSubField(df),
                        ),
                      )
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
    final subFields = f.isPopupForm
        ? (df.value as List<DynamicFieldModel>? ?? [])
        : <DynamicFieldModel>[];
    final isCameraField = f.fieldStyle == FieldStyle.camera;

    return DynamicFieldBuilder(
      field: f,
      value: _textCtrl.containsKey(f.key) ? _textCtrl[f.key]!.text : df.value,
      textController: _textCtrl[f.key],
      accentColor: AppColors.primary,
      onChanged: (_) {},
      isViewMode: true,
      onPopupFormPressed: f.isPopupForm ? () => _openNestedPopup(df) : null,
      popupFormFilledCount: f.isPopupForm ? getFilledCount(subFields) : null,
      popupFormTotalCount: f.isPopupForm ? getTotalCount(subFields) : null,
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
