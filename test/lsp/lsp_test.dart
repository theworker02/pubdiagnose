import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pubdiagnose/src/lsp/server.dart';
import 'package:test/test.dart';

int indexOfCrlfCrlf(List<int> bytes, int start) {
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

void main() {
  late Directory projectDir;
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('pubdoctor-lsp-');
    final fixture = p.join(
      Directory.current.path,
      'test',
      'fixtures',
      'basic_app',
    );
    await Process.run('cp', ['-r', fixture, tempRoot.path]);
    projectDir = Directory(p.join(tempRoot.path, 'basic_app'));
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<List<Map<String, dynamic>>> runSession(
    List<Map<String, Object?>> requests,
  ) async {
    final input = StreamController<List<int>>();
    final output = BytesBuilder();
    final server = PubDoctorLspServer(workspacePath: projectDir.path);

    final done = server.serve(
      input: input.stream,
      output: (frame) => output.add(utf8.encode(frame)),
    );

    for (final req in requests) {
      input.add(utf8.encode(encodeLspFrame(req)));
    }
    await input.close();
    await done;
    await server.close();

    final bytes = output.takeBytes();
    final frames = <Map<String, dynamic>>[];
    var offset = 0;
    while (offset < bytes.length) {
      final headerEnd = indexOfCrlfCrlf(bytes, offset);
      if (headerEnd < 0) break;
      final header = utf8.decode(bytes.sublist(offset, headerEnd));
      final match =
          RegExp(r'Content-Length:\s*(\d+)', caseSensitive: false).firstMatch(header);
      expect(match, isNotNull);
      final len = int.parse(match!.group(1)!);
      final bodyStart = headerEnd + 4;
      final bodyEnd = bodyStart + len;
      if (bytes.length < bodyEnd) break;
      final body = utf8.decode(bytes.sublist(bodyStart, bodyEnd));
      frames.add(jsonDecode(body) as Map<String, dynamic>);
      offset = bodyEnd;
    }
    return frames;
  }

  test('initialize and inspect', () async {
    final frames = await runSession([
      {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {}},
      {'jsonrpc': '2.0', 'id': 2, 'method': 'pubdoctor/inspect', 'params': {}},
      {'jsonrpc': '2.0', 'id': 3, 'method': 'shutdown', 'params': {}},
      {'jsonrpc': '2.0', 'method': 'exit', 'params': {}},
    ]);

    expect(frames.length, 3);
    expect(frames[0]['result'], isA<Map>());
    final caps = frames[0]['result'] as Map;
    expect(caps['serverInfo'], isA<Map>());
    expect(frames[1]['result'], isA<Map>());
    final inspect = frames[1]['result'] as Map;
    expect(inspect['tool'], 'pubdoctor');
    expect(frames[2]['result'], isNull);
  });

  test('check returns diagnostics shape', () async {
    final frames = await runSession([
      {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {}},
      {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'pubdoctor/check',
        'params': {'offline': true},
      },
    ]);

    expect(frames.length, greaterThanOrEqualTo(2));
    final result = frames[1]['result'] as Map;
    expect(result['status'], isA<String>());
    expect(result['diagnostics'], isA<List>());
  });

  test('why explains dependency path', () async {
    final frames = await runSession([
      {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {}},
      {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'pubdoctor/why',
        'params': {'package': 'collection'},
      },
    ]);

    final result = frames[1]['result'] as Map;
    expect(result['package'], 'collection');
    expect(result['pathCount'], greaterThan(0));
  });

  test('explain returns diagnostic catalog entry', () async {
    final frames = await runSession([
      {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {}},
      {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'pubdoctor/explain',
        'params': {'target': 'PD1001'},
      },
    ]);

    final result = frames[1]['result'] as Map;
    expect(result['kind'], 'diagnostic');
    expect(result['code'], 'PD1001');
  });
}
