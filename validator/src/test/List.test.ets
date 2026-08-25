import validatorTest from './Validator.test';
import schemaCoverageTest from './SchemaCoverage.test';
import chinaRulesTest from './ChinaRules.test';
import v050Test from './V050.test';
import v050StabilityTest from './V050Stability.test';

export default function testsuite(): void {
  validatorTest();
  schemaCoverageTest();
  chinaRulesTest();
  v050Test();
  v050StabilityTest();
}
