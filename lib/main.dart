import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/raq_audio_handler.dart';
import 'state/app_state.dart';
import 'ui/common.dart';
import 'ui/root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final handler = await AudioService.init(
    builder: () => RaqAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.berst.music.audio',
      androidNotificationChannelName: 'Berst',
      androidNotificationOngoing: true,
    ),
  );
  final app = AppState(handler);
  await app.init();
  runApp(RaqApp(app: app));
}

class RaqApp extends StatelessWidget {
  const RaqApp({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Berst',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: RootScreen(app: app),
    );
  }
}
