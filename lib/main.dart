import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'src/ui/one_tv_player_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const OneTvPlayerApp());
}
