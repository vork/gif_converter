import 'package:flutter_test/flutter_test.dart';
import 'package:gif_converter/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GifConverterApp());
    expect(find.text('GifDrop'), findsOneWidget);
  });
}
