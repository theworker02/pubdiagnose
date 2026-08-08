/// Scope for policy rules (package / workspace / inherit).
class PolicyScope {
  /// Creates a scope.
  const PolicyScope({
    this.package,
    this.inherit = true,
    this.overrideParent = false,
  });

  /// Package name this scope applies to (null = workspace root / all).
  final String? package;

  /// Whether child scopes inherit this rule.
  final bool inherit;

  /// Whether this scope overrides parent rules of the same id.
  final bool overrideParent;

  /// Root / default scope.
  static const root = PolicyScope();

  /// JSON representation.
  Map<String, Object?> toJson() => {
        if (package != null) 'package': package,
        'inherit': inherit,
        'overrideParent': overrideParent,
      };
}

/// Kind of policy rule.
enum PolicyRuleKind {
  /// Ban dependency_overrides.
  banOverrides,

  /// Minimum SDK constraint.
  sdkMinimum,

  /// Require direct declaration for imported packages.
  requireDirectDeclaration,

  /// Forbidden package names.
  forbiddenPackages,

  /// Allowed / required version ranges.
  versionRanges,

  /// Required packages.
  requiredPackages,

  /// Max age of locked packages (days).
  maxAge,

  /// No git/path deps outside workspace.
  noExternalGitPath,

  /// No wildcard version constraints.
  noWildcards,

  /// SDK constraint must be pinned (not any).
  pinnedSdk,

  /// Workspace members must use consistent versions.
  consistentWorkspaceVersions,
}

/// A single governance policy rule.
class PolicyRule {
  /// Creates a rule.
  const PolicyRule({
    required this.id,
    required this.kind,
    required this.scope,
    this.enabled = true,
    this.params = const {},
    this.description,
  });

  /// Stable rule id.
  final String id;

  /// Rule kind.
  final PolicyRuleKind kind;

  /// Scope.
  final PolicyScope scope;

  /// Whether enabled.
  final bool enabled;

  /// Kind-specific parameters.
  final Map<String, Object?> params;

  /// Optional description.
  final String? description;

  /// JSON representation.
  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'scope': scope.toJson(),
        'enabled': enabled,
        if (params.isNotEmpty) 'params': params,
        if (description != null) 'description': description,
      };
}
