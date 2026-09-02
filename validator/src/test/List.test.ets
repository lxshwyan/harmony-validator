import validatorTest from './Validator.test';
import schemaCoverageTest from './SchemaCoverage.test';
import chinaRulesTest from './ChinaRules.test';
import v050Test from './V050.test';
import v050StabilityTest from './V050Stability.test';
import v060Test from './V060.test';
import v070Test from './V070.test';
import v080Test from './V080.test';
import v100SchemasTest from './V100Schemas.test';
import v100ObjectTest from './V100Object.test';
import v100EffectsTest from './V100Effects.test';
import v100DescriptorTest from './V100Descriptor.test';
import v100StabilityTest from './V100Stability.test';
import v110CoreTest from './V110Core.test';
import v110InteropTest from './V110Interop.test';
import v110FormatsTest from './V110Formats.test';
import v110StressTest from './V110Stress.test';

export default function testsuite(): void {
  validatorTest();
  schemaCoverageTest();
  chinaRulesTest();
  v050Test();
  v050StabilityTest();
  v060Test();
  v070Test();
  v080Test();
  v100SchemasTest();
  v100ObjectTest();
  v100EffectsTest();
  v100DescriptorTest();
  v100StabilityTest();
  v110CoreTest();
  v110InteropTest();
  v110FormatsTest();
  v110StressTest();
}
