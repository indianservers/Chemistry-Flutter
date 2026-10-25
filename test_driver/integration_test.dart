import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final directory =
          Platform.environment['CHEMISTRY_SCREENSHOT_DIR'] ??
          'docs/screenshots';
      final file = File('$directory/$name.png');
      await file.create(recursive: true);
      final staging = File('${file.path}.pending');
      await staging.writeAsBytes(bytes);
      if (await file.exists()) {
        await file.delete();
      }
      await staging.rename(file.path);
      return true;
    },
  );
}
