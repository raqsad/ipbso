import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'common.dart';

/// Pilih timer tidur: musik dijeda otomatis setelah sekian menit.
Future<void> showSleepDialog(BuildContext context, AppState app) {
  return showBlurCard<void>(context, (c) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final end = app.sleepEnd;
        final remain = end == null ? 0 : (end.difference(DateTime.now()).inMinutes + 1).clamp(1, 9999);
        return CardShell(
          maxWidth: 340,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Sleep Timer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              remain > 0 ? 'Musik berhenti sekitar $remain menit lagi.' : 'Musik berhenti otomatis setelah:',
              style: TextStyle(fontSize: 13, color: wh(.7)),
            ),
            const SizedBox(height: 8),
            for (final m in const [15, 30, 45, 60, 90])
              Pressable(
                scale: 0.98,
                onTap: () {
                  app.startSleep(m);
                  Navigator.of(c).pop();
                  toast(context, 'Timer tidur $m menit');
                },
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('$m menit', style: const TextStyle(fontSize: 17, color: Colors.white))),
                ),
              ),
            const SizedBox(height: 6),
            if (remain > 0)
              Pressable(
                onTap: () {
                  app.cancelSleep();
                  Navigator.of(c).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: wh(.14), borderRadius: BorderRadius.circular(50)),
                  alignment: Alignment.center,
                  child: const Text('Matikan timer', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
          ]),
        );
      },
    );
  });
}
