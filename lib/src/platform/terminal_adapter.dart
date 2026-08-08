import 'dart:io';

import 'environment_adapter.dart';
import 'platform_info.dart';

/// Terminal / TTY capabilities and ANSI fallbacks.
class TerminalAdapter {
  /// Creates a terminal adapter.
  TerminalAdapter({
    required this.platform,
    required this.environment,
    this.stdoutHandle,
    this.stderrHandle,
    bool? forceColor,
    bool? forceInteractive,
  })  : _forceColor = forceColor,
        _forceInteractive = forceInteractive;

  /// Platform info.
  final PlatformInfo platform;

  /// Environment.
  final EnvironmentAdapter environment;

  /// Optional stdout override (tests).
  final Stdout? stdoutHandle;

  /// Optional stderr override (tests).
  final Stdout? stderrHandle;

  final bool? _forceColor;
  final bool? _forceInteractive;

  Stdout get _out => stdoutHandle ?? stdout;

  /// Whether stdout is an interactive TTY.
  bool get isInteractive {
    if (_forceInteractive != null) return _forceInteractive;
    if (platform.isCi) return false;
    try {
      return stdioType(_out) == StdioType.terminal;
    } on Object {
      return false;
    }
  }

  /// Whether ANSI colors should be used.
  bool get supportsAnsi {
    if (_forceColor != null) return _forceColor;
    if (platform.isCi) {
      // Many CI systems support ANSI; still respect NO_COLOR.
      if (environment.has('NO_COLOR')) return false;
      if (environment['TERM'] == 'dumb') return false;
      return environment.has('FORCE_COLOR') ||
          environment.has('GITHUB_ACTIONS') ||
          environment.has('CI');
    }
    if (environment.has('NO_COLOR')) return false;
    if (environment['TERM'] == 'dumb') return false;
    if (environment.has('FORCE_COLOR')) return true;
    try {
      return _out.supportsAnsiEscapes && isInteractive;
    } on Object {
      return false;
    }
  }

  /// Terminal width (fallback 80).
  int get width {
    try {
      final w = _out.terminalColumns;
      if (w > 0) return w;
    } on Object {
      // non-TTY
    }
    final cols = environment['COLUMNS'];
    if (cols != null) {
      final n = int.tryParse(cols);
      if (n != null && n > 0) return n;
    }
    return 80;
  }

  /// Shell hint for messaging.
  String get shell => environment.shellHint();

  /// Progress-friendly: interactive non-CI TTY.
  bool get supportsProgress => isInteractive && !platform.isCi;

  /// Prefer ASCII when Unicode is risky (legacy Windows code pages).
  bool get preferAscii {
    if (environment.has('PUBDOCTOR_ASCII')) return true;
    if (platform.isWindows && !supportsAnsi) return true;
    return false;
  }

  /// Bullet character with fallback.
  String get bullet => preferAscii ? '-' : '•';

  /// Checkmark with fallback.
  String get checkMark => preferAscii ? 'OK' : '✓';
}
