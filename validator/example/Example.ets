/**
 * @hmkit/validator 使用示例
 *
 * 运行方式：把本文件的逻辑拷到任意 ArkTS Ability/Page 里调用，
 * 或在 Previewer 中渲染下面的 ValidatorExample 组件查看结果。
 *
 * 安装：ohpm i @hmkit/validator
 */
import { v, ValidateResult } from '@hmkit/validator';

// ---------------------------------------------------------------------------
// 1. 单值校验：链式声明规则，再 .validate(value)
// ---------------------------------------------------------------------------
function singleValueDemo(): void {
  // 手机号：通过
  const ok: ValidateResult = v.string().required().phone().validate('13800138000');
  console.info(`phone ok -> valid=${ok.valid}`); // valid=true

  // 手机号：不通过，errors[].message 给用户看
  const bad: ValidateResult = v.string().required().phone().validate('123');
  console.info(`phone bad -> ${bad.errors[0]?.message}`); // 请输入正确的手机号

  // 中国本地化规则：身份证（含校验位）、银行卡（Luhn）
  console.info(`idCard -> ${v.string().idCard().validate('11010519491231002X').valid}`);
  console.info(`bankCard -> ${v.string().bankCard().validate('6259650871772098').valid}`);

  // 数字规则 + 自定义错误提示
  const age: ValidateResult = v.number().min(18, '需年满18岁').validate(16);
  console.info(`age -> ${age.errors[0]?.message}`); // 需年满18岁
}

// ---------------------------------------------------------------------------
// 2. 对象整体校验：逐字段校验，错误带字段路径
// ---------------------------------------------------------------------------
function formDemo(): void {
  // 注意：ArkTS 中 Record 字面量的 key 必须加引号
  const schema = v.object({
    'name': v.string().required('请输入姓名').min(2),
    'phone': v.string().required().phone(),
    'age': v.number().required().integer().min(18, '需年满18岁'),
  });

  const form: Record<string, Object> = {
    'name': '张',          // 太短
    'phone': '123',        // 非法手机号
    'age': 16,             // 未满 18
  };

  const result: ValidateResult = schema.validate(form);
  console.info(`form valid=${result.valid}`); // false
  for (const e of result.errors) {
    console.info(`  ${e.path}: ${e.message}`); // 形如  phone: 请输入正确的手机号
  }
}

export function runValidatorExamples(): void {
  singleValueDemo();
  formDemo();
}
