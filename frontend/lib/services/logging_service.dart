import 'package:logging/logging.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class LoggingService {
  static final Logger _logger = Logger('ApiService');

  static void setup() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      final message =
          '${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}';

      // Print to console for flutter run (debug mode only)
      if (kDebugMode) {
        print(message);
      }

      // Also send to developer log for IDE debugging
      developer.log(
        '${record.level.name}: ${record.message}',
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
      );
    });
  }

  static Logger get logger => _logger;
}
