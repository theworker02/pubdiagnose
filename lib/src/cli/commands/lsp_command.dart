import 'dart:io';

import '../../kernel/pubdoctor_options.dart';
import '../../lsp/server.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor lsp` — JSON-RPC 2.0 stdio language server.
class LspCommand extends PubDoctorCommand {
  @override
  String get name => 'lsp';

  @override
  String get description =>
      'Start the PubDoctor LSP server over stdio (Content-Length framed JSON-RPC).';

  @override
  Future<int> run() async {
    final project = pd.projectPath(argResults!);
    final minimal = pd.globalResults['minimal'] == true;
    final server = PubDoctorLspServer(
      workspacePath: project,
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
        minimal: minimal,
      ),
    );
    try {
      await server.serve(
        input: stdin,
        output: (frame) => stdout.write(frame),
      );
      return ExitCodes.ok;
    } finally {
      await server.close();
    }
  }
}
