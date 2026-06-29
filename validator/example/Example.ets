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

// ---------------------------------------------------------------------------
// 3. v0.2 数组校验 + 深层嵌套：错误路径自动带下标，如 items.0.name
// ---------------------------------------------------------------------------
function arrayAndNestedDemo(): void {
  // 数组：逐元素校验 + 长度约束
  const tags = v.array(v.string().min(2)).min(1, '至少一个标签');
  console.info(`tags -> ${JSON.stringify(tags.validate(['ok', 'x']).errors)}`); // path "1"

  // 深嵌套：对象 → 数组 → 对象,路径拼成 items.0.name
  const orderSchema = v.object({
    'items': v.array(v.object({
      'name': v.string().required('请输入商品名'),
      'qty': v.number().required().min(1, '数量至少为1'),
    })).nonEmpty('至少一件商品'),
  });
  const order: Record<string, Object> = {
    'items': [{ 'name': '', 'qty': 0 } as Record<string, Object>],
  };
  for (const e of orderSchema.validate(order).errors) {
    console.info(`  ${e.path}: ${e.message}`); // items.0.name / items.0.qty
  }
}

// ---------------------------------------------------------------------------
// 4. v0.2 异步校验：远程查重等场景,用 customAsync + validateAsync
// ---------------------------------------------------------------------------
async function asyncDemo(): Promise<void> {
  // 模拟远程查重:用户名是否已被占用
  const checkUsername: (name: string) => Promise<boolean> = (name: string): Promise<boolean> =>
    Promise.resolve(name !== 'taken');

  const userSchema = v.string().required().min(3).customAsync(checkUsername, '用户名已被占用');

  const r1 = await userSchema.validateAsync('taken');
  console.info(`taken -> ${r1.errors[0]?.message}`); // 用户名已被占用

  const r2 = await userSchema.validateAsync('freeuser');
  console.info(`freeuser -> valid=${r2.valid}`); // true
}

export function runValidatorExamples(): void {
  singleValueDemo();
  formDemo();
  arrayAndNestedDemo();
  asyncDemo();
}
