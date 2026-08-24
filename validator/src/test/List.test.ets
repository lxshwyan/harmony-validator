import validatorTest from './Validator.test';
import schemaCoverageTest from './SchemaCoverage.test';
import chinaRulesTest from './ChinaRules.test';

export default function testsuite(): void {
  validatorTest();
  schemaCoverageTest();
  chinaRulesTest();
}
