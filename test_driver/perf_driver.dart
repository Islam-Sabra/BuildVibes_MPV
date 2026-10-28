// The host side of integration_test/busy_space_perf_test.dart (review 101
// K3): writes what the device reported to build/busy_space_perf.json.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final out = File('build/busy_space_perf.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    stdout.writeln('PERF ${jsonEncode(data)}');
    stdout.writeln('written to ${out.path}');
  },
);
