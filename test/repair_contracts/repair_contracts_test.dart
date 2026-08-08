import 'package:pubdoctor/src/cli/runner.dart';
import 'package:pubdoctor/src/repair_contracts/proof_result.dart';
import 'package:pubdoctor/src/repair_contracts/repair_contract.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('repair contracts', () {
    test('preconditions enforced; postconditions required for success', () {
      final contract = RepairContract.devToRuntimeDependency('foo');
      final validator = ContractValidator();
      final preFail = validator.validate(
        contract: contract,
        preState: {
          'importedByRuntime': false,
          'inDevDependencies': true,
        },
      );
      expect(preFail.ok, isFalse);

      final preOk = {
        'importedByRuntime': true,
        'inDevDependencies': true,
        'sdkConstraint': '>=3.5.0 <4.0.0',
        'unrelatedKeys': ['name'],
      };
      final postOk = {
        'inDependencies': true,
        'resolvable': true,
        'duplicateDeclaration': false,
        'sdkConstraint': '>=3.5.0 <4.0.0',
        'unrelatedKeys': ['name'],
      };
      final proof = validator.validate(
        contract: contract,
        preState: preOk,
        postState: postOk,
      );
      expect(proof.ok, isTrue);

      final cert = RepairCertificate(
        issue: contract.issue,
        repair: 'move-foo',
        contract: contract,
        preState: preOk,
        postState: postOk,
        proof: proof,
        outcome: 'success',
      );
      expect(cert.toJson()['verified'], isTrue);
    });

    test('negative verification fails certificate', () {
      final contract = RepairContract.devToRuntimeDependency('foo');
      final proof = ContractValidator().validate(
        contract: contract,
        preState: {
          'importedByRuntime': true,
          'inDevDependencies': true,
          'sdkConstraint': 'x',
          'unrelatedKeys': const <String>[],
        },
        postState: {
          'inDependencies': true,
          'resolvable': true,
          'duplicateDeclaration': false,
          'sdkConstraint': 'x',
          'unrelatedKeys': const <String>[],
        },
        negativeFindings: ['no new diagnostics'],
      );
      expect(proof.ok, isFalse);
    });

    test('repair --certificate json', () async {
      final out = StringBuffer();
      final code = await runPubDoctor(
        [
          'repair',
          '--certificate',
          '--json',
          '--project',
          fixturePath('basic_app'),
        ],
        out: out,
      );
      expect(code, 0);
      expect(out.toString(), contains('certificate'));
      expect(out.toString(), contains('pubdoctor.repair.certificate'));
    });
  });
}
