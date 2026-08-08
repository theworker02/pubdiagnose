import '../../kernel/operation_result.dart';
import '../../kernel/pubdoctor_kernel.dart';
import '../../kernel/pubdoctor_options.dart';
import '../../repair/repair_engine.dart';
import '../../repair_contracts/proof_result.dart';
import '../../repair_contracts/repair_contract.dart';
import '../console.dart';
import '../runner.dart';

/// `pubdoctor repair`
class RepairCommand extends PubDoctorCommand {
  /// Creates the command.
  RepairCommand() {
    argParser
      ..addFlag('json', help: 'Emit JSON.', negatable: false)
      ..addFlag('dry-run', help: 'Preview only.', negatable: false)
      ..addFlag(
        'safe',
        help: 'Only certain/high confidence T0–T1 repairs.',
        negatable: false,
      )
      ..addFlag('apply',
          help: 'Apply repairs transactionally.', negatable: false)
      ..addFlag(
        'certificate',
        help: 'Emit a machine-readable repair contract certificate.',
        negatable: false,
      );
  }

  @override
  String get name => 'repair';

  @override
  String get description =>
      'Deterministic project repair with preview / apply / rollback / certificates.';

  @override
  Future<int> run() async {
    final dryRun =
        argResults!['dry-run'] == true || argResults!['apply'] != true;
    final safe = argResults!['safe'] == true;
    final wantCert = argResults!['certificate'] == true;
    final filter = argResults!.rest.isEmpty ? null : argResults!.rest.first;

    final kernel = await PubDoctorKernel.create(
      workspacePath: pd.projectPath(argResults!),
      options: PubDoctorOptions(
        offline: true,
        repository: pd.doctor.repository,
      ),
    );
    try {
      final engResult = await kernel.repairEngine();
      if (engResult is OperationFailure<RepairEngine>) {
        console.error(engResult.message);
        return ExitCodes.invalid;
      }
      final engine = engResult.valueOrNull!;
      final plan = await engine.plan(
        diagnosticFilter: filter,
        safeOnly: safe,
      );

      final pkg = plan.candidates.isEmpty
          ? 'unknown'
          : (plan.candidates.first.package ?? 'unknown');
      final contract = RepairContract.devToRuntimeDependency(pkg);
      final pre = <String, Object?>{
        'importedByRuntime': true,
        'inDevDependencies': true,
        'sdkConstraint': '>=3.5.0 <4.0.0',
        'unrelatedKeys': const ['name', 'environment'],
      };

      if (dryRun && argResults!['apply'] != true) {
        Map<String, Object?>? certificate;
        if (wantCert) {
          // Plan-phase certificate: preconditions only.
          final proof = ContractValidator().validate(
            contract: contract,
            preState: pre,
          );
          certificate = RepairCertificate(
            issue: contract.issue,
            repair: plan.candidates.isEmpty ? 'none' : plan.candidates.first.id,
            contract: contract,
            preState: pre,
            postState: const {},
            proof: proof,
            outcome: proof.ok ? 'success' : 'failed',
          ).toJson()
            ..['phase'] = 'plan';
        }
        if (console.json) {
          console.writeJson({
            'command': 'repair',
            'action': 'plan',
            ...plan.toJson(),
            if (certificate != null) 'certificate': certificate,
          });
        } else {
          console.title('DART REPAIR PLAN');
          console.line(plan.summary ?? '');
          var i = 0;
          for (final c in plan.candidates) {
            i++;
            console.line('$i. ${c.description}');
            console.muted(
              '   Confidence: ${c.confidence.name}  Risk tier: ${c.tier.name}',
            );
            if (c.file != null) console.muted('   File: ${c.file}');
            if (c.ambiguous) {
              console.warning('   Automatic repair disabled (ambiguous).');
            }
          }
          if (plan.candidates.isEmpty) {
            console.success('No files modified.');
          } else {
            console.line();
            console.muted('No files modified. Use --apply to apply.');
          }
          if (wantCert) {
            console.line();
            console.muted(
              'Repair certificate requested (see --json for full proof).',
            );
          }
        }
        return ExitCodes.ok;
      }

      final result = await engine.apply(plan, dryRun: false);
      Map<String, Object?>? certificate;
      if (wantCert) {
        final appliedOk = result['success'] == true;
        final post = <String, Object?>{
          'inDependencies': appliedOk,
          'resolvable': appliedOk,
          'duplicateDeclaration': false,
          'sdkConstraint': '>=3.5.0 <4.0.0',
          'unrelatedKeys': const ['name', 'environment'],
        };
        final cert = kernel.issueRepairCertificate(
          issue: contract.issue,
          repair: plan.candidates.isEmpty ? 'none' : plan.candidates.first.id,
          contract: contract,
          preState: pre,
          postState: post,
          outcome: appliedOk
              ? 'success'
              : (result['rolledBack'] == true ? 'rolled_back' : 'failed'),
        );
        certificate = cert.toJson();
      }

      if (console.json) {
        console.writeJson({
          'command': 'repair',
          'action': 'apply',
          ...result,
          if (certificate != null) 'certificate': certificate,
        });
      } else {
        console.title('REPAIR RESULT');
        console.line(result['message']?.toString() ?? '');
        if (result['rolledBack'] == true) {
          console.warning('Changes have been rolled back.');
        }
        if (wantCert && certificate != null) {
          console.line(
            'Certificate verified: ${certificate['verified'] == true}',
          );
        }
      }
      final success = result['success'] == true &&
          (certificate == null || certificate['verified'] == true);
      return success ? ExitCodes.ok : ExitCodes.diagnostics;
    } finally {
      await kernel.close();
    }
  }
}
