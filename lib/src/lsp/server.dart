import 'dart:async';
import 'dart:convert';

import '../analysis/package_explainer.dart';
import '../diagnostics/diagnostic_catalog.dart';
import '../kernel/operation_result.dart';
import '../kernel/pubdoctor_kernel.dart';
import '../kernel/pubdoctor_options.dart';
import '../models/exceptions.dart';
import '../workspace/workspace_loader.dart';

/// JSON-RPC 2.0 LSP-style stdio server for pubdoctor diagnostics.
///
/// Framing: `Content-Length: N\r\n\r\n{json}` per message.
class PubDoctorLspServer {
  /// Creates a server bound to [workspacePath].
  PubDoctorLspServer({
    required this.workspacePath,
    PubDoctorOptions options = PubDoctorOptions.defaults,
  }) : _options = options;

  /// Workspace root analyzed by custom pubdoctor/* methods.
  final String workspacePath;

  final PubDoctorOptions _options;

  bool _initialized = false;
  bool _shutdownRequested = false;
  PubDoctorKernel? _kernel;

  /// Run the server until `exit` or input closes.
  Future<void> serve({
    Stream<List<int>>? input,
    void Function(String message)? output,
  }) async {
    final inStream = input ?? const Stream<List<int>>.empty();
    final out = output ?? (_) {};
    final buffer = <int>[];

    await for (final chunk in inStream) {
      buffer.addAll(chunk);
      while (true) {
        final headerEnd = _indexOfCrlfCrlf(buffer, 0);
        if (headerEnd < 0) break;

        final header = utf8.decode(buffer.sublist(0, headerEnd));
        final lengthMatch =
            RegExp(r'Content-Length:\s*(\d+)', caseSensitive: false)
                .firstMatch(header);
        if (lengthMatch == null) {
          buffer.removeRange(0, headerEnd + 4);
          break;
        }
        final length = int.parse(lengthMatch.group(1)!);
        final bodyStart = headerEnd + 4;
        final bodyEnd = bodyStart + length;
        if (buffer.length < bodyEnd) break;

        final body = utf8.decode(buffer.sublist(bodyStart, bodyEnd));
        buffer.removeRange(0, bodyEnd);

        final response = await _handleMessage(body);
        if (response != null) {
          _writeFrame(out, response);
        }
        if (_shutdownRequested) {
          return;
        }
      }
    }
  }

  int _indexOfCrlfCrlf(List<int> bytes, int start) {
    for (var i = start; i + 3 < bytes.length; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  void _writeFrame(
      void Function(String message) output, Map<String, Object?> msg) {
    final json = jsonEncode(msg);
    output('Content-Length: ${utf8.encode(json).length}\r\n\r\n$json');
  }

  Future<Map<String, Object?>?> _handleMessage(String body) async {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final map = decoded.cast<String, dynamic>();
    final id = map['id'];
    final method = map['method'] as String?;
    final params = (map['params'] as Map?)?.cast<String, dynamic>() ?? {};

    if (method == null) return null;

    try {
      switch (method) {
        case 'initialize':
          _initialized = true;
          _kernel ??= await PubDoctorKernel.create(
            workspacePath: workspacePath,
            options: _options,
          );
          return _response(id, {
            'capabilities': {
              'pubdoctor': {
                'inspect': true,
                'check': true,
                'explain': true,
                'why': true,
              },
            },
            'serverInfo': {
              'name': 'pubdoctor',
              'version': '2.0.0',
            },
          });
        case 'shutdown':
          _shutdownRequested = true;
          return _response(id, null);
        case 'exit':
          return null;
        case 'pubdoctor/inspect':
          _requireInit();
          final payload = await _kernel!.inspect();
          return _response(id, payload);
        case 'pubdoctor/check':
          _requireInit();
          final offline = params['offline'] == true;
          final result = await _kernel!.check(offline: offline);
          return result.when<Map<String, Object?>>(
            ok: (report) => _response(id, {
              'status': report.status.name,
              'summary': report.summary,
              'diagnostics': [for (final d in report.diagnostics) d.toJson()],
            }),
            fail: (f) => _response(id, {
              'error': f.message,
              'code': f.code,
            }),
          );
        case 'pubdoctor/explain':
          _requireInit();
          final target =
              params['target'] as String? ?? params['package'] as String?;
          if (target == null || target.isEmpty) {
            return _errorResponse(id, -32602, 'missing target');
          }
          final codeInfo = DiagnosticCatalog.byCode(target);
          if (codeInfo != null) {
            return _response(id, {'kind': 'diagnostic', ...codeInfo.toJson()});
          }
          final loaded = await _kernel!.loadWorkspace();
          if (loaded is OperationFailure<PubWorkspace>) {
            return _errorResponse(id, -32000, loaded.message);
          }
          final ws = loaded.valueOrNull!;
          final explanation = await PackageExplainer(
            workspace: ws,
            repository: _kernel!.execution.repository,
          ).explain(target);
          return _response(id, {'kind': 'package', ...explanation.toJson()});
        case 'pubdoctor/why':
          _requireInit();
          final package = params['package'] as String?;
          if (package == null || package.isEmpty) {
            return _errorResponse(id, -32602, 'missing package');
          }
          final loaded = await _kernel!.loadWorkspace();
          return loaded.when<Map<String, Object?>>(
            ok: (ws) {
              final graph = ws.graph;
              final node = graph.package(package);
              if (node == null) {
                return _errorResponse(
                  id,
                  -32000,
                  'Package "$package" not found in graph',
                );
              }
              final shortest = graph.shortestPathTo(package);
              final allPaths = graph.pathsTo(package);
              return _response(id, {
                'package': package,
                'version': node.version?.toString(),
                'dependencyKind': node.dependencyKind,
                'shortestPath': shortest?.toJson(),
                'pathCount': allPaths.length,
                'paths': [for (final p in allPaths) p.toJson()],
              });
            },
            fail: (f) => _errorResponse(id, -32000, f.message),
          );
        default:
          if (id != null) {
            return _errorResponse(id, -32601, 'Method not found: $method');
          }
          return null;
      }
    } on InvalidProjectException catch (e) {
      return _errorResponse(id, -32000, e.message);
    } on Object catch (e) {
      return _errorResponse(id, -32000, e.toString());
    }
  }

  void _requireInit() {
    if (!_initialized) {
      throw StateError('server not initialized');
    }
  }

  Map<String, Object?> _response(Object? id, Object? result) => {
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      };

  Map<String, Object?> _errorResponse(Object? id, int code, String message) => {
        'jsonrpc': '2.0',
        'id': id,
        'error': {
          'code': code,
          'message': message,
        },
      };

  /// Release kernel resources.
  Future<void> close() async {
    await _kernel?.close();
    _kernel = null;
  }
}

/// Encode a JSON-RPC request frame for tests/clients.
String encodeLspFrame(Map<String, Object?> message) {
  final json = jsonEncode(message);
  return 'Content-Length: ${utf8.encode(json).length}\r\n\r\n$json';
}
