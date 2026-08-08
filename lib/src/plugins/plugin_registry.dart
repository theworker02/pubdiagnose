import '../features/feature_registry.dart';
import '../resilience/analyzer_pipeline.dart';

/// Controlled plugin surface — register analyzers/diagnostics/fixes metadata.
///
/// Plugins cannot inject arbitrary code execution; they contribute descriptors
/// and optional [AnalyzerModule] instances that obey the same contracts as
/// built-ins.
class PubDoctorPlugin {
  /// Creates a plugin.
  const PubDoctorPlugin({
    required this.id,
    required this.description,
    this.features = const [],
    this.modules = const [],
  });

  /// Plugin id.
  final String id;

  /// Description.
  final String description;

  /// Additional feature descriptors.
  final List<FeatureDescriptor> features;

  /// Additional analyzer modules.
  final List<AnalyzerModule> modules;
}

/// Registry of plugins.
class PluginRegistry {
  final Map<String, PubDoctorPlugin> _plugins = {};
  final List<AnalyzerModule> _modules = [];

  /// Register built-in feature catalog as the core plugin.
  void registerBuiltins(FeatureRegistry features) {
    register(
      PubDoctorPlugin(
        id: 'pubdoctor.core',
        description: 'Built-in PubDoctor features',
        features: features.all,
      ),
    );
  }

  /// Register a plugin (controlled).
  void register(PubDoctorPlugin plugin) {
    _plugins[plugin.id] = plugin;
    _modules.addAll(plugin.modules);
  }

  /// Plugin ids.
  List<String> get ids => _plugins.keys.toList()..sort();

  /// Extra analyzer modules from plugins.
  List<AnalyzerModule> get extraModules => List.unmodifiable(_modules);
}
