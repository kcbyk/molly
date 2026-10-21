import 'package:flutter_test/flutter_test.dart';
import 'package:solenz_mu/main.dart';

void main() {
  testWidgets('Music app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SolenzMusicApp());

    // Verify Header
    expect(find.text('Keşfet'), findsWidgets);
    expect(find.textContaining('Bugün ne dinlemek istersin?'), findsOneWidget);

    // Verify Bottom Tabs
    expect(find.text('Kütüphane'), findsWidgets);
    expect(find.text('Beğenilen'), findsWidgets);

    // Verify songs are loaded
    expect(find.text('Şımarık'), findsWidgets);
  });
}
