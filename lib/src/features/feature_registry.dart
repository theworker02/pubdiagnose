/// Descriptor for a PubDoctor feature module.
class FeatureDescriptor {
  /// Creates a descriptor.
  const FeatureDescriptor({
    required this.id,
    required this.description,
    this.providesFix = false,
    this.requiresNetwork = false,
  });

  /// Feature id (check, why, conflicts, …).
  final String id;

  /// Short description.
  final String description;

  /// Whether the feature can provide fix plans.
  final bool providesFix;

  /// Whether network is required for full fidelity.
  final bool requiresNetwork;

  /// JSON.
  Map<String, Object?> toJson() => {
        'id': id,
        'description': description,
        'providesFix': providesFix,
        'requiresNetwork': requiresNetwork,
      };
}

/// Registry of built-in features (analyzers live in their own packages; this
/// catalog keeps ownership explicit and prevents orphan modules).
class FeatureRegistry {
  /// Creates an empty registry.
  FeatureRegistry();

  final Map<String, FeatureDescriptor> _features = {};

  /// Built-in feature set.
  factory FeatureRegistry.builtins() {
    final registry = FeatureRegistry();
    for (final f in _builtin) {
      registry.register(f);
    }
    return registry;
  }

  /// Register a feature.
  void register(FeatureDescriptor feature) {
    _features[feature.id] = feature;
  }

  /// Lookup.
  FeatureDescriptor? operator [](String id) => _features[id];

  /// All feature ids.
  List<String> get ids => _features.keys.toList()..sort();

  /// All descriptors.
  List<FeatureDescriptor> get all => _features.values.toList();

  static const _builtin = <FeatureDescriptor>[
    FeatureDescriptor(
      id: 'check',
      description: 'Unified dependency health report',
    ),
    FeatureDescriptor(
      id: 'why',
      description: 'Explain why a package is installed',
    ),
    FeatureDescriptor(
      id: 'conflicts',
      description: 'Constraint conflict analysis',
    ),
    FeatureDescriptor(
      id: 'outdated',
      description: 'Outdated packages with blockers',
      requiresNetwork: true,
    ),
    FeatureDescriptor(
      id: 'unlock',
      description: 'What must change to unlock a version',
      requiresNetwork: true,
    ),
    FeatureDescriptor(
      id: 'sdk',
      description: 'SDK upgrade blockers',
      requiresNetwork: true,
    ),
    FeatureDescriptor(
      id: 'unused',
      description: 'Possibly unused dependencies',
    ),
    FeatureDescriptor(
      id: 'imports',
      description: 'Undeclared direct imports',
    ),
    FeatureDescriptor(
      id: 'explain',
      description: 'Explain diagnostic codes or packages',
    ),
    FeatureDescriptor(
      id: 'workspace',
      description: 'Monorepo / workspace consistency',
    ),
    FeatureDescriptor(
      id: 'fixes',
      description: 'Safe remediation planning',
      providesFix: true,
    ),
    FeatureDescriptor(
      id: 'baseline',
      description: 'CI baseline management',
    ),
    FeatureDescriptor(
      id: 'risk',
      description: 'Evidence-driven dependency risk intelligence',
      requiresNetwork: true,
    ),
    FeatureDescriptor(
      id: 'migrate',
      description: 'Ordered SDK / package migration planning',
      requiresNetwork: true,
    ),
    FeatureDescriptor(
      id: 'policy',
      description: 'Workspace governance policy checks',
    ),
    FeatureDescriptor(
      id: 'impact',
      description: 'Change impact / reverse-dependency analysis',
    ),
    FeatureDescriptor(
      id: 'snapshot',
      description: 'Persistent project intelligence snapshots',
    ),
    FeatureDescriptor(
      id: 'drift',
      description: 'Compare current state to snapshots',
    ),
    FeatureDescriptor(
      id: 'debug',
      description: 'Profiling and incremental invalidation',
    ),
    FeatureDescriptor(
      id: 'health',
      description: 'Internal PubDoctor subsystem health',
    ),
    FeatureDescriptor(
      id: 'heal',
      description: 'Self-healing for PubDoctor internal state',
      providesFix: true,
    ),
    FeatureDescriptor(
      id: 'source',
      description: 'Dart source project-level diagnostics',
    ),
    FeatureDescriptor(
      id: 'repair',
      description: 'Deterministic transactional project repair',
      providesFix: true,
    ),
    FeatureDescriptor(
      id: 'upgrade',
      description: 'Sandbox upgrade simulation and heal reporting',
    ),
    FeatureDescriptor(
      id: 'environment',
      description: 'Runtime environment / capability detection',
    ),
    FeatureDescriptor(
      id: 'watch',
      description: 'Continuous integrity watch mode',
    ),
    FeatureDescriptor(
      id: 'audit',
      description: 'Repair history and internal architecture audit',
    ),
    FeatureDescriptor(
      id: 'distributed',
      description: 'Local/remote distributed analysis workers',
    ),
    FeatureDescriptor(
      id: 'reproduce',
      description: 'Environment reproducibility check and manifest export',
    ),
    FeatureDescriptor(
      id: 'migration',
      description: 'Semantic migration knowledge explanations',
    ),
    FeatureDescriptor(
      id: 'ecosystem',
      description: 'Pub ecosystem observatory with offline last-known cache',
      requiresNetwork: true,
    ),
    FeatureDescriptor(
      id: 'security',
      description: 'Supply-chain and lockfile integrity analysis',
    ),
    FeatureDescriptor(
      id: 'maintain',
      description: 'Bounded autonomous maintenance controller',
      providesFix: true,
    ),
    FeatureDescriptor(
      id: 'remote',
      description: 'Remote / constrained runtime workspace abstractions',
    ),
  ];
}
