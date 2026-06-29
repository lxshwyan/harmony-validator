/**
 * 用法示例 + 自测。
 * 在 DevEco Studio 里把 runExamples() 接到一个按钮或 aboutToAppear 调用，
 * 看 console 输出是否符合预期，即可快速验证库行为。
 */
import { v } from '../src/main/ets/index';
import { ValidateResult } from '../src/main/ets/core/types';

function show(title: string, result: ValidateResult): void {
  if (result.valid) {
    console.info(`[PASS] ${title}`);
  } else {
    const msgs = result.errors.map((e) => `${e.path || '值'}:${e.message}`).join('; ');
    console.warn(`[FAIL] ${title} -> ${msgs}`);
  }
}

export function runExamples(): void {
  // 1. 手机号：合法 / 非法
  show('手机号 13800138000', v.string().required().phone().validate('13800138000'));
  show('手机号 123（应失败）', v.string().required().phone().validate('123'));

  // 2. 身份证校验位（末位 X）
  show('身份证 11010519491231002X', v.string().idCard().validate('11010519491231002X'));

  // 3. 银行卡 Luhn
  show('银行卡 6259650871772098', v.string().bankCard().validate('6259650871772098'));

  // 4. 数字范围
  show('年龄 16（应失败，min 18）', v.number().min(18, '需年满18岁').validate(16));

  // 5. 对象整体校验 + 错误路径
  const schema = v.object({
    'name': v.string().required('请输入姓名').min(2),
    'phone': v.string().required().phone(),
    'age': v.number().required().integer().min(18, '需年满18岁'),
  });
  const form: Record<string, Object> = {
    'name': '张',          // 长度不足
    'phone': '139000',     // 非法手机号
    'age': 16,             // 不满 18
  };
  show('表单（预期 3 处错误）', schema.validate(form));
}
