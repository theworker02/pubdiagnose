import 'repair_contract.dart';

/// Outcome of validating a repair contract.
class ProofResult {
  /// Creates a proof result.
  const ProofResult({
    required this.ok,
    required this.contractId,
    this.failedPreconditions = const [],
    this.failedPostconditions = const [],
    this.failedInvariants = const [],
    this.negativeVerification = const [],
    this.message,
  });

  /// Overall success — only true when postconditions + invariants pass.
  final bool ok;

  /// Contract id.
  final String contractId;

  /// Failed precondition ids.
  final List<String> failedPreconditions;

  /// Failed postcondition ids.
  final List<String> failedPostconditions;

  /// Failed invariant ids.
  final List<String> failedInvariants;

  /// Negative verification findings.
  final List<String> negativeVerification;

  /// Message.
  final String? message;

  /// JSON.
  Map<String, Object?> toJson() => {
        'ok': ok,
        'contractId': contractId,
        'failedPreconditions': failedPreconditions,
        'failedPostconditions': failedPostconditions,
        'failedInvariants': failedInvariants,
        'negativeVerification': negativeVerification,
        if (message != null) 'message': message,
      };
}

/// Validates repair contracts (pre / post / invariants / negatives).
class ContractValidator {
  /// Validate [contract] against [preState] and optional [postState].
  ///
  /// When [postState] is null, only preconditions are checked (plan phase).
  ProofResult validate({
    required RepairContract contract,
    required Map<String, Object?> preState,
    Map<String, Object?>? postState,
    List<String> negativeFindings = const [],
  }) {
    final failedPre = <String>[];
    for (final p in contract.preconditions) {
      if (!p.evaluate(preState)) failedPre.add(p.id);
    }
    if (postState == null) {
      return ProofResult(
        ok: failedPre.isEmpty,
        contractId: contract.id,
        failedPreconditions: failedPre,
        message: failedPre.isEmpty
            ? 'Preconditions satisfied'
            : 'Preconditions failed',
      );
    }

    final failedPost = <String>[];
    for (final p in contract.postconditions) {
      if (!p.evaluate(preState, postState)) failedPost.add(p.id);
    }
    final failedInv = <String>[];
    for (final i in contract.invariants) {
      if (!i.evaluate(preState, postState)) failedInv.add(i.id);
    }

    final negatives = <String>[
      ...negativeFindings,
      for (final f in contract.forbiddenRegressions)
        if (postState['regression:$f'] == true) f,
    ];

    final ok = failedPre.isEmpty &&
        failedPost.isEmpty &&
        failedInv.isEmpty &&
        negatives.isEmpty;
    return ProofResult(
      ok: ok,
      contractId: contract.id,
      failedPreconditions: failedPre,
      failedPostconditions: failedPost,
      failedInvariants: failedInv,
      negativeVerification: negatives,
      message: ok
          ? 'Repair contract satisfied'
          : 'Repair contract verification failed',
    );
  }
}

/// Machine-readable repair certificate for CI / audit.
class RepairCertificate {
  /// Creates a certificate.
  const RepairCertificate({
    required this.issue,
    required this.repair,
    required this.contract,
    required this.preState,
    required this.postState,
    required this.proof,
    required this.outcome,
    this.issuedAt,
  });

  /// Issue.
  final String issue;

  /// Repair description / id.
  final String repair;

  /// Contract.
  final RepairContract contract;

  /// Pre-state.
  final Map<String, Object?> preState;

  /// Post-state.
  final Map<String, Object?> postState;

  /// Proof.
  final ProofResult proof;

  /// Outcome: success | failed | rolled_back.
  final String outcome;

  /// Issued at.
  final DateTime? issuedAt;

  /// JSON.
  Map<String, Object?> toJson() => {
        'kind': 'pubdoctor.repair.certificate',
        'schemaVersion': 1,
        'issuedAt': (issuedAt ?? DateTime.now().toUtc()).toIso8601String(),
        'issue': issue,
        'repair': repair,
        'contract': contract.toJson(),
        'preState': preState,
        'postState': postState,
        'validations': proof.toJson(),
        'outcome': outcome,
        // Success requires proof.ok — exit code alone is never enough.
        'verified': proof.ok && outcome == 'success',
      };
}
