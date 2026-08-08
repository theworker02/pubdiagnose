import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/diagnostics.dart';
import '../models/exceptions.dart';
import '../models/pubspec_document.dart';
import '../pubspec/pubspec_parser.dart';

/// A member of a Dart pub workspace / monorepo.
class WorkspaceMember {
  /// Creates a member.
  const WorkspaceMember({
    required this.name,
    required this.directory,
    required this.pubspec,
    this.relativePath = '.',
  });

  /// Package name.
  final String name;

  /// Absolute directory.
  final Directory directory;

  /// Path relative to workspace root.
  final String relativePath;

  /// Parsed pubspec.
  final PubspecDocument pubspec;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'name': name,
        'path': relativePath,
        'sdk': pubspec.environment.sdk?.toString(),
      };
}

/// Report for `pubdoctor workspace`.
class WorkspaceReport {
  /// Creates a report.
  const WorkspaceReport({
    required this.rootPath,
    required this.members,
    required this.diagnostics,
    this.isWorkspace = false,
  });

  /// Workspace root.
  final String rootPath;

  /// Whether a pub `workspace:` was detected.
  final bool isWorkspace;

  /// Members.
  final List<WorkspaceMember> members;

  /// Findings.
  final List<Diagnostic> diagnostics;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'root': rootPath,
        'isWorkspace': isWorkspace,
        'members': [for (final m in members) m.toJson()],
        'diagnostics': [for (final d in diagnostics) d.toJson()],
      };
}

/// Analyzes Dart/pub workspaces and simple monorepos.
class MonorepoAnalyzer {
  /// Creates an analyzer.
  MonorepoAnalyzer({PubspecParser? parser})
      : _parser = parser ?? PubspecParser();

  final PubspecParser _parser;

  /// Analyzes the directory tree starting at [directory].
  Future<WorkspaceReport> analyze(String directory) async {
    final root = Directory(p.normalize(p.absolute(directory)));
    if (!root.existsSync()) {
      throw InvalidProjectException(
        'Directory does not exist: ${root.path}',
        code: 'PD0004',
      );
    }

    final rootPubspecFile = File(p.join(root.path, 'pubspec.yaml'));
    if (!rootPubspecFile.existsSync()) {
      throw MissingPubspecException(root.path);
    }

    final rootContent = rootPubspecFile.readAsStringSync();
    final rootPubspec =
        _parser.parse(rootContent, source: rootPubspecFile.path);
    final workspacePaths = _readWorkspacePaths(rootContent);
    final isWorkspace = workspacePaths != null;

    final members = <WorkspaceMember>[
      WorkspaceMember(
        name: rootPubspec.name,
        directory: root,
        pubspec: rootPubspec,
      ),
    ];

    final paths = workspacePaths ?? _discoverPackages(root);
    for (final rel in paths) {
      if (rel == '.' || rel.isEmpty) continue;
      final memberDir = Directory(p.join(root.path, rel));
      final file = File(p.join(memberDir.path, 'pubspec.yaml'));
      if (!file.existsSync()) continue;
      final doc = _parser.parse(file.readAsStringSync(), source: file.path);
      members.add(
        WorkspaceMember(
          name: doc.name,
          directory: memberDir,
          pubspec: doc,
          relativePath: rel.replaceAll('\\', '/'),
        ),
      );
    }

    final seen = <String>{};
    final unique = <WorkspaceMember>[];
    for (final m in members) {
      final key = p.normalize(m.directory.path);
      if (seen.add(key)) unique.add(m);
    }

    return WorkspaceReport(
      rootPath: root.path,
      isWorkspace: isWorkspace,
      members: unique,
      diagnostics: [
        ..._versionInconsistencies(unique),
        ..._sdkInconsistencies(unique),
        ..._overrideConflicts(unique),
        ..._circularWorkspaceDeps(unique),
      ],
    );
  }

  List<String>? _readWorkspacePaths(String content) {
    final doc = loadYaml(content);
    if (doc is! YamlMap) return null;
    final workspace = doc['workspace'];
    if (workspace is! YamlList) return null;
    return [
      for (final item in workspace)
        if (item != null) item.toString(),
    ];
  }

  List<String> _discoverPackages(Directory root) {
    final result = <String>[];
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final base = p.basename(entity.path);
      if (base.startsWith('.') || base == 'build' || base == '.dart_tool') {
        continue;
      }
      if (File(p.join(entity.path, 'pubspec.yaml')).existsSync()) {
        result.add(base);
      }
      if (base == 'packages' ||
          base == 'apps' ||
          base == 'examples' ||
          base == 'melos_packages') {
        for (final child in entity.listSync(followLinks: false)) {
          if (child is! Directory) continue;
          if (File(p.join(child.path, 'pubspec.yaml')).existsSync()) {
            result.add(
              p.join(base, p.basename(child.path)).replaceAll('\\', '/'),
            );
          }
        }
      }
    }
    return result;
  }

  List<Diagnostic> _versionInconsistencies(List<WorkspaceMember> members) {
    final byPackage = <String, Map<String, String>>{};
    for (final m in members) {
      for (final d in m.pubspec.allDependencies) {
        final isWorkspacePkg = members.any((other) => other.name == d.name);
        if (isWorkspacePkg) continue;
        byPackage.putIfAbsent(d.name, () => {})[m.name] =
            d.constraint.toString();
      }
    }
    final result = <Diagnostic>[];
    for (final entry in byPackage.entries) {
      if (entry.value.length < 2) continue;
      if (entry.value.values.toSet().length <= 1) continue;
      result.add(
        Diagnostic(
          code: DiagnosticCodes.workspaceVersionInconsistent,
          title: 'Inconsistent dependency versions',
          message: 'Workspace members declare different constraints for '
              '"${entry.key}".',
          severity: DiagnosticSeverity.warning,
          package: entry.key,
          evidence: [
            for (final e in entry.value.entries)
              '${e.key} → ${entry.key} ${e.value}',
          ],
          remediation:
              'Align "${entry.key}" constraints across workspace packages.',
        ),
      );
    }
    return result;
  }

  List<Diagnostic> _sdkInconsistencies(List<WorkspaceMember> members) {
    final sdks = <String, String>{
      for (final m in members)
        if (m.pubspec.environment.sdk != null)
          m.name: m.pubspec.environment.sdk.toString(),
    };
    if (sdks.values.toSet().length <= 1) return const [];
    return [
      Diagnostic(
        code: DiagnosticCodes.workspaceSdkInconsistent,
        title: 'Inconsistent SDK constraints',
        message:
            'Workspace members declare different environment.sdk constraints.',
        severity: DiagnosticSeverity.warning,
        evidence: [for (final e in sdks.entries) '${e.key}: sdk ${e.value}'],
        remediation: 'Align SDK constraints where practical.',
      ),
    ];
  }

  List<Diagnostic> _overrideConflicts(List<WorkspaceMember> members) {
    final byPackage = <String, Map<String, String>>{};
    for (final m in members) {
      for (final o in m.pubspec.dependencyOverrides) {
        byPackage
            .putIfAbsent(o.name, () => {})
            .putIfAbsent(m.name, () => '${o.source.name}:${o.constraint}');
      }
    }
    final result = <Diagnostic>[];
    for (final entry in byPackage.entries) {
      if (entry.value.values.toSet().length <= 1) continue;
      result.add(
        Diagnostic(
          code: DiagnosticCodes.workspaceOverrideConflict,
          title: 'Conflicting workspace overrides',
          message: 'Members declare conflicting overrides for "${entry.key}".',
          severity: DiagnosticSeverity.error,
          package: entry.key,
          evidence: [
            for (final e in entry.value.entries) '${e.key}: ${e.value}',
          ],
          remediation:
              'Consolidate overrides, preferably at the workspace root.',
        ),
      );
    }
    return result;
  }

  List<Diagnostic> _circularWorkspaceDeps(List<WorkspaceMember> members) {
    final names = {for (final m in members) m.name};
    final edges = <String, Set<String>>{
      for (final m in members)
        m.name: {
          for (final d in m.pubspec.allDependencies)
            if (names.contains(d.name)) d.name,
        },
    };

    final cycles = <List<String>>[];
    final visiting = <String>{};
    final visited = <String>{};
    final stack = <String>[];

    void dfs(String node) {
      if (visited.contains(node)) return;
      if (!visiting.add(node)) {
        final idx = stack.indexOf(node);
        if (idx >= 0) cycles.add([...stack.sublist(idx), node]);
        return;
      }
      stack.add(node);
      for (final next in edges[node] ?? const <String>{}) {
        dfs(next);
      }
      stack.removeLast();
      visiting.remove(node);
      visited.add(node);
    }

    for (final name in names) {
      dfs(name);
    }

    return [
      for (final cycle in cycles.take(10))
        Diagnostic(
          code: DiagnosticCodes.workspaceCircularDependency,
          title: 'Circular workspace dependency',
          message: 'Workspace packages form a cycle: ${cycle.join(' → ')}.',
          severity: DiagnosticSeverity.warning,
          evidence: ['cycle: ${cycle.join(' → ')}'],
          remediation:
              'Extract shared code or invert a dependency to break the cycle.',
        ),
    ];
  }
}
