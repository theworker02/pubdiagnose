import '../metadata/package_repository.dart';
import '../platform/platform_service.dart';

/// Construction options for [PubDoctorKernel] / [PubDoctor.open].
class PubDoctorOptions {
  /// Creates options.
  const PubDoctorOptions({
    this.offline = false,
    this.enrichFromCache = true,
    this.allowProcess = true,
    this.allowNetwork = true,
    this.httpTimeout = const Duration(seconds: 12),
    this.moduleTimeout = const Duration(seconds: 60),
    this.forceColor,
    this.forceInteractive,
    this.repository,
    this.platform,
    this.minimal = false,
    this.workers,
  });

  /// Defaults.
  static const defaults = PubDoctorOptions();

  /// Skip network features.
  final bool offline;

  /// Enrich lockfile edges from the pub cache.
  final bool enrichFromCache;

  /// Allow spawning processes.
  final bool allowProcess;

  /// Allow HTTP (ignored when [offline] is true).
  final bool allowNetwork;

  /// HTTP timeout.
  final Duration httpTimeout;

  /// Per analyzer-module timeout.
  final Duration moduleTimeout;

  /// Force ANSI color on/off.
  final bool? forceColor;

  /// Force interactive terminal on/off.
  final bool? forceInteractive;

  /// Injected package repository.
  final PackageRepository? repository;

  /// Injected platform service (tests).
  final PlatformService? platform;

  /// Minimal / constrained runtime — disable expensive optional systems.
  final bool minimal;

  /// Optional distributed worker count for check.
  final int? workers;

  /// Effective network permission.
  bool get networkEnabled => allowNetwork && !offline && !minimal;

  /// Copy with overrides.
  PubDoctorOptions copyWith({
    bool? offline,
    bool? enrichFromCache,
    bool? allowProcess,
    bool? allowNetwork,
    Duration? httpTimeout,
    Duration? moduleTimeout,
    bool? forceColor,
    bool? forceInteractive,
    PackageRepository? repository,
    PlatformService? platform,
    bool? minimal,
    int? workers,
  }) {
    return PubDoctorOptions(
      offline: offline ?? this.offline,
      enrichFromCache: enrichFromCache ?? this.enrichFromCache,
      allowProcess: allowProcess ?? this.allowProcess,
      allowNetwork: allowNetwork ?? this.allowNetwork,
      httpTimeout: httpTimeout ?? this.httpTimeout,
      moduleTimeout: moduleTimeout ?? this.moduleTimeout,
      forceColor: forceColor ?? this.forceColor,
      forceInteractive: forceInteractive ?? this.forceInteractive,
      repository: repository ?? this.repository,
      platform: platform ?? this.platform,
      minimal: minimal ?? this.minimal,
      workers: workers ?? this.workers,
    );
  }
}
