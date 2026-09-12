import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  Widget app(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('NoResultsWidget', () {
    testWidgets('shows only title when no actions provided', (tester) async {
      await tester.pumpWidget(app(const NoResultsWidget()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Scan a barcode or create a custom food instead.'), findsNothing);
      expect(find.bySemanticsLabel('empty-search-scan-barcode'), findsNothing);
      expect(find.bySemanticsLabel('empty-search-create-custom'), findsNothing);
    });

    testWidgets('shows subtitle and both actions when both provided', (tester) async {
      await tester.pumpWidget(app(
        NoResultsWidget(
          onBarcodePressed: () {},
          onCustomFoodPressed: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Scan a barcode or create a custom food instead.'), findsOneWidget);
      expect(find.bySemanticsIdentifier('empty-search-scan-barcode'), findsOneWidget);
      expect(find.bySemanticsIdentifier('empty-search-create-custom'), findsOneWidget);
    });

    testWidgets('shows only barcode action when only barcode provided', (tester) async {
      await tester.pumpWidget(app(
        NoResultsWidget(
          onBarcodePressed: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('empty-search-scan-barcode'), findsOneWidget);
      expect(find.bySemanticsIdentifier('empty-search-create-custom'), findsNothing);
    });

    testWidgets('shows only custom food action when only custom food provided', (tester) async {
      await tester.pumpWidget(app(
        NoResultsWidget(
          onCustomFoodPressed: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('empty-search-scan-barcode'), findsNothing);
      expect(find.bySemanticsIdentifier('empty-search-create-custom'), findsOneWidget);
    });
  });
}
