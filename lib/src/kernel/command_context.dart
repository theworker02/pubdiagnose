import '../cli/console.dart';
import 'execution_context.dart';
import 'pubdoctor_kernel.dart';

/// Per-CLI-invocation context (flags + kernel).
class CommandContext {
  /// Creates a command context.
  CommandContext({
    required this.kernel,
    required this.console,
    required this.json,
    required this.verbose,
    required this.jsonl,
    this.failOn,
  });

  /// Active kernel.
  final PubDoctorKernel kernel;

  /// Console writer.
  final ConsoleWriter console;

  /// JSON output mode.
  final bool json;

  /// Verbose mode.
  final bool verbose;

  /// Streaming JSONL mode.
  final bool jsonl;

  /// Optional fail-on severity name.
  final String? failOn;

  /// Shared execution context.
  ExecutionContext get execution => kernel.execution;
}
