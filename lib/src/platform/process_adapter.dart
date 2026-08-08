import 'dart:async';
import 'dart:io';

import 'capability_probe.dart';

/// Result of an external process run.
class ProcessRunResult {
  /// Creates a result.
  const ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
    this.error,
  });

  /// Exit code (-1 if failed to start / timed out).
  final int exitCode;

  /// Captured stdout.
  final String stdout;

  /// Captured stderr.
  final String stderr;

  /// Whether the process timed out.
  final bool timedOut;

  /// Start / spawn error message.
  final String? error;

  /// Whether the process completed successfully.
  bool get success => exitCode == 0 && !timedOut && error == null;
}

/// Portable process execution with timeouts and capability gating.
class ProcessAdapter {
  /// Creates a process adapter.
  ProcessAdapter({this.allowed = true});

  /// When false, [run] returns a capability error without spawning.
  final bool allowed;

  /// Run [executable] with [arguments].
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 30),
    bool runInShell = false,
  }) async {
    if (!allowed) {
      return const ProcessRunResult(
        exitCode: -1,
        stdout: '',
        stderr: '',
        error: 'Process execution is disabled by capability policy.',
      );
    }

    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        runInShell: runInShell,
      ).timeout(timeout);

      return ProcessRunResult(
        exitCode: result.exitCode,
        stdout: result.stdout?.toString() ?? '',
        stderr: result.stderr?.toString() ?? '',
      );
    } on TimeoutException {
      return const ProcessRunResult(
        exitCode: -1,
        stdout: '',
        stderr: '',
        timedOut: true,
        error: 'Process timed out.',
      );
    } on Object catch (e) {
      return ProcessRunResult(
        exitCode: -1,
        stdout: '',
        stderr: '',
        error: e.toString(),
      );
    }
  }

  /// Probe whether [executable] is available on PATH.
  Future<bool> isAvailable(String executable) async {
    if (!allowed) return false;
    return CapabilityProbe.which(executable) != null;
  }
}
