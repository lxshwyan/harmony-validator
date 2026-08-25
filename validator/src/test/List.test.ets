import validatorTest from './Validator.test';
import schemaCoverageTest from './SchemaCoverage.test';
import chinaRulesTest from './ChinaRules.test';
import v050Test from './V050.test';
import v050StabilityTest from './V050Stability.test';
import v060Test from './V060.test';
import v070Test from './V070.test';

export default function testsuite(): void {
  validatorTest();
  schemaCoverageTest();
  chinaRulesTest();
  v050Test();
  v050StabilityTest();
  v060Test();
  v070Test();
}
