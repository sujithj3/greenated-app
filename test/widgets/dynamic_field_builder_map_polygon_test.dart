import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenated/models/api/api_models.dart';
import 'package:greenated/utils/app_colors.dart';
import 'package:greenated/widgets/dynamic_field_builder.dart';

/// Renders the MAP_POLYGON branch of [DynamicFieldBuilder] in a realistic
/// phone-width surface so any RenderFlex overflow surfaces as a test failure,
/// and asserts the mode-specific label / button / metrics text.
void main() {
  const label = 'Polygon boundary (GPS)';

  final polygonField = ApiField(
    fieldId: 1,
    label: label,
    key: 'polygon',
    fieldType: FieldType.arrayDict,
    fieldStyle: FieldStyle.mapPolygon,
    required: false,
  );

  // A small square (~4 vertices) so LandPolygonMetrics yields area/perimeter.
  final squarePolygon = <Map<String, dynamic>>[
    {'lat': 12.0000, 'lng': 77.0000},
    {'lat': 12.0010, 'lng': 77.0000},
    {'lat': 12.0010, 'lng': 77.0010},
    {'lat': 12.0000, 'lng': 77.0010},
  ];

  Future<void> pumpField(
    WidgetTester tester, {
    dynamic value,
    String? mapPolygonActionLabel,
    bool isViewMode = false,
    VoidCallback? onGenerateKml,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DynamicFieldBuilder(
              field: polygonField,
              value: value,
              isViewMode: isViewMode,
              onChanged: (_) {},
              onMapPolygonPressed: () {},
              onGenerateKml: onGenerateKml,
              mapPolygonActionLabel: mapPolygonActionLabel,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('registration empty shows label title + "Measure Land"',
      (tester) async {
    await pumpField(tester, value: null, mapPolygonActionLabel: 'Measure Land');

    expect(find.text(label), findsOneWidget); // floating label
    expect(find.text('Measure Land'), findsOneWidget);
    expect(find.textContaining('Area', findRichText: true), findsNothing);
  });

  testWidgets('registration with polygon shows point count but no metrics',
      (tester) async {
    await pumpField(
      tester,
      value: squarePolygon,
      mapPolygonActionLabel: 'Measure Land',
    );

    expect(find.text(label), findsOneWidget);
    // With a polygon captured the CTA turns into a green "View Measured Land".
    expect(find.text('View Measured Land (4 pts)'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('View Measured Land (4 pts)')).style?.color,
      AppColors.primary,
    );
    // Area / Perimeter are detail-page only.
    expect(find.textContaining('Area:', findRichText: true), findsNothing);
    expect(find.textContaining('Perimeter:', findRichText: true), findsNothing);
  });

  testWidgets('view mode with polygon keeps View Map + Export KML in section',
      (tester) async {
    await pumpField(
      tester,
      value: squarePolygon,
      isViewMode: true,
      onGenerateKml: () {},
    );

    expect(find.text(label), findsOneWidget);
    expect(find.text('View Land Map'), findsOneWidget);
    expect(find.text('Export KML'), findsOneWidget);
    expect(find.textContaining('Area:', findRichText: true), findsOneWidget);
    expect(find.textContaining('Perimeter:', findRichText: true), findsOneWidget);
    expect(find.textContaining('Ac', findRichText: true), findsOneWidget);
    expect(find.textContaining('Acres', findRichText: true), findsNothing);
  });

  testWidgets('edit with polygon (no KML) shows action but no metrics',
      (tester) async {
    await pumpField(tester, value: squarePolygon);

    expect(find.text(label), findsOneWidget);
    expect(find.text('View Measured Land (4 pts)'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('View Measured Land (4 pts)')).style?.color,
      AppColors.primary,
    );
    expect(find.text('Export KML'), findsNothing);
    // Area / Perimeter are detail-page only.
    expect(find.textContaining('Area:', findRichText: true), findsNothing);
  });
}
