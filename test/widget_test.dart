import 'package:flutter_test/flutter_test.dart';

import 'package:product_scanner/main.dart';

void main() {
  testWidgets('App builds and shows the three item steps plus the upload button', (WidgetTester tester) async {
    await tester.pumpWidget(const ProductScannerApp());
    await tester.pump();

    expect(find.text('Barcode Details'), findsOneWidget);
    expect(find.text('Product Photo'), findsOneWidget);
    expect(find.text('Barcode Photo'), findsOneWidget);
    expect(find.textContaining('Upload item'), findsOneWidget);
  });
}
