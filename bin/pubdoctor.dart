import 'dart:io';

import 'package:pubdoctor/src/cli/runner.dart';

Future<void> main(List<String> args) async {
  final code = await runPubDoctor(args);
  exit(code);
}
