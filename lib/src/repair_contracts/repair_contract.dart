/// A repair precondition that must hold before mutation.
class RepairPrecondition {
  /// Creates a precondition.
  const RepairPrecondition({
    required this.id,
    required this.description,
    required this.check,
  });

  /// Id.
  final String id;

  /// Description.
  final String description;

  /// Predicate over a pre-state map.
  final bool Function(Map<String, Object?> preState) check;

  /// Evaluate.
  bool evaluate(Map<String, Object?> preState) => check(preState);

  /// JSON (without function).
  Map<String, Object?> toJson() => {
        'id': id,
        'description': description,
      };
}

/// Expected postcondition after mutation.
class RepairPostcondition {
  /// Creates a postcondition.
  const RepairPostcondition({
    required this.id,
    required this.description,
    required this.check,
  });

  /// Id.
  final String id;

  /// Description.
  final String description;

  /// Predicate over pre + post state.
  final bool Function(
    Map<String, Object?> preState,
    Map<String, Object?> postState,
  ) check;

  /// Evaluate.
  bool evaluate(
    Map<String, Object?> preState,
    Map<String, Object?> postState,
  ) =>
      check(preState, postState);

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'description': description,
      };
}

/// Invariant that must hold across the mutation.
class RepairInvariant {
  /// Creates an invariant.
  const RepairInvariant({
    required this.id,
    required this.description,
    required this.check,
  });

  /// Id.
  final String id;

  /// Description.
  final String description;

  /// Predicate over pre + post.
  final bool Function(
    Map<String, Object?> preState,
    Map<String, Object?> postState,
  ) check;

  /// Evaluate.
  bool evaluate(
    Map<String, Object?> preState,
    Map<String, Object?> postState,
  ) =>
      check(preState, postState);

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'description': description,
      };
}

/// Machine-verifiable repair contract.
class RepairContract {
  /// Creates a contract.
  const RepairContract({
    required this.id,
    required this.issue,
    required this.mutation,
    this.preconditions = const [],
    this.postconditions = const [],
    this.invariants = const [],
    this.forbiddenRegressions = const [],
    this.validationStrategy = const [],
  });

  /// Contract id.
  final String id;

  /// Issue being repaired.
  final String issue;

  /// Expected mutation description.
  final String mutation;

  /// Preconditions.
  final List<RepairPrecondition> preconditions;

  /// Postconditions.
  final List<RepairPostcondition> postconditions;

  /// Invariants.
  final List<RepairInvariant> invariants;

  /// Forbidden regressions (negative verification descriptions).
  final List<String> forbiddenRegressions;

  /// Validation strategy steps.
  final List<String> validationStrategy;

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'issue': issue,
        'mutation': mutation,
        'preconditions': [for (final p in preconditions) p.toJson()],
        'postconditions': [for (final p in postconditions) p.toJson()],
        'invariants': [for (final i in invariants) i.toJson()],
        'forbiddenRegressions': forbiddenRegressions,
        'validationStrategy': validationStrategy,
      };

  /// Standard contract: move package from dev_dependencies → dependencies.
  factory RepairContract.devToRuntimeDependency(String package) {
    return RepairContract(
      id: 'dev-to-runtime-$package',
      issue: 'Package $package is imported by runtime source but declared in '
          'dev_dependencies.',
      mutation:
          'Move $package declaration without changing version constraint.',
      preconditions: [
        RepairPrecondition(
          id: 'imported-by-runtime',
          description: 'Package is imported by runtime source.',
          check: (pre) => pre['importedByRuntime'] == true,
        ),
        RepairPrecondition(
          id: 'in-dev-dependencies',
          description: 'Package is declared in dev_dependencies.',
          check: (pre) => pre['inDevDependencies'] == true,
        ),
      ],
      postconditions: [
        RepairPostcondition(
          id: 'in-dependencies',
          description: 'Package is declared in dependencies.',
          check: (_, post) => post['inDependencies'] == true,
        ),
        RepairPostcondition(
          id: 'resolvable',
          description: 'Dependency remains resolvable.',
          check: (_, post) => post['resolvable'] != false,
        ),
      ],
      invariants: [
        RepairInvariant(
          id: 'no-duplicate',
          description: 'No duplicate declaration.',
          check: (_, post) => post['duplicateDeclaration'] != true,
        ),
        RepairInvariant(
          id: 'sdk-unchanged',
          description: 'No SDK constraint change.',
          check: (pre, post) =>
              pre['sdkConstraint']?.toString() ==
              post['sdkConstraint']?.toString(),
        ),
        RepairInvariant(
          id: 'yaml-scoped',
          description: 'No unrelated YAML mutation.',
          check: (pre, post) {
            final preKeys = (pre['unrelatedKeys'] as List?) ?? const [];
            final postKeys = (post['unrelatedKeys'] as List?) ?? const [];
            return preKeys.toString() == postKeys.toString();
          },
        ),
      ],
      forbiddenRegressions: const [
        'unrelated dependencies unchanged',
        'SDK constraint untouched',
        'no new diagnostics',
        'no tests newly failing',
      ],
      validationStrategy: const [
        'precondition-check',
        'apply-mutation',
        'postcondition-check',
        'invariant-check',
        'negative-verification',
      ],
    );
  }
}
