import 'dart:convert';
import 'dart:io';

import '../models/diagnostics.dart';
import '../models/graph_models.dart';

/// Terminal output helpers (library-agnostic of command parsing).
class ConsoleWriter {
  /// Creates a console writer.
  ConsoleWriter({
    this.json = false,
    this.verbose = false,
    this.color = true,
    StringSink? out,
    StringSink? err,
  })  : out = out ?? stdout,
        err = err ?? stderr;

  /// Emit JSON instead of text.
  final bool json;

  /// Verbose mode.
  final bool verbose;

  /// ANSI color.
  final bool color;

  /// stdout.
  final StringSink out;

  /// stderr.
  final StringSink err;

  /// Writes a JSON payload and newline.
  void writeJson(Object? value) {
    out.writeln(const JsonEncoder.withIndent('  ').convert(value));
  }

  /// Title line.
  void title(String text) {
    if (json) return;
    out.writeln(_bold(text));
  }

  /// Normal line.
  void line([String text = '']) {
    if (json) return;
    out.writeln(text);
  }

  /// Dim/secondary line.
  void muted(String text) {
    if (json) return;
    out.writeln(color ? '\x1b[2m$text\x1b[0m' : text);
  }

  /// Error to stderr.
  void error(String text) {
    err.writeln(color ? '\x1b[31m$text\x1b[0m' : text);
  }

  /// Warning line.
  void warning(String text) {
    if (json) return;
    out.writeln(color ? '\x1b[33m$text\x1b[0m' : text);
  }

  /// Success / emphasis.
  void success(String text) {
    if (json) return;
    out.writeln(color ? '\x1b[32m$text\x1b[0m' : text);
  }

  String _bold(String text) => color ? '\x1b[1m$text\x1b[0m' : text;

  /// Formats a diagnostic for text output.
  void diagnostic(Diagnostic d) {
    if (json) return;
    final tag = d.severity.name.toUpperCase();
    line('[$tag ${d.code}] ${d.title}');
    line('  ${d.message}');
    if (d.package != null) muted('  package: ${d.package}');
    for (final e in d.evidence.take(6)) {
      muted('  • $e');
    }
    for (final p in d.paths.take(3)) {
      muted('  path: ${p.display}');
    }
    if (d.remediation != null) {
      line('  → ${d.remediation}');
    }
    line();
  }

  /// Formats a dependency path.
  void path(DependencyPath path, {String? prefix}) {
    if (json) return;
    line('${prefix ?? ''}${path.display}');
  }
}

/// Process exit codes.
abstract final class ExitCodes {
  /// Success / no issues.
  static const ok = 0;

  /// Diagnostics / conflicts / blockers found.
  static const diagnostics = 1;

  /// Invalid project or input.
  static const invalid = 2;
}
