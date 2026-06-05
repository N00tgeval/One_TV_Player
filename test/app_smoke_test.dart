import 'dart:ui';

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
    expect(find.text('Enable demo FAST'), findsOneWidget);
  });

  testWidgets('fits compact Android-sized screens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OneTvPlayerApp());
    await tester.pumpAndSettle();

    expect(find.text('One TV Player'), findsOneWidget);
    expect(find.text('Add a source'), findsOneWidget);
    expect(find.text('Enable demo FAST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
