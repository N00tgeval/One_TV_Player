import 'package:flutter_test/flutter_test.dart';
import 'package:one_tv_player/src/ui/one_tv_player_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows One TV Player shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const OneTvPlayerApp());
    await tester.pumpAndSettle();

    expect(find.text('One TV Player'), findsOneWidget);
    expect(find.text('Add a source'), findsOneWidget);
  });
}
