import { AnySchema } from '../core/types';

/**
 * 表单联动控制器。把一组「字段名 -> 校验器」包起来，给 ArkUI 表单提供：
 *   - validateField(name, value)       输入时实时校验单个字段
 *   - validateFieldAsync(name, value)  异步校验单个字段(支持 customAsync 远程查重)
 *   - validateAll(values)              提交时整体校验，返回 字段->错误 的 map
 *
 * 与具体 UI 解耦：UI 只负责把值传进来、把错误显示出去，因此可配合任意
 * ArkUI 组件(TextInput / Checkbox / 自定义组件)使用。用法见 README。
 */
export class FormValidator {
  private shape: Record<string, AnySchema>;

  constructor(shape: Record<string, AnySchema>) {
    this.shape = shape;
  }

  /** 校验单个字段，返回首条错误信息；通过则返回 null。 */
  validateField(name: string, value: Object | null | undefined): string | null {
    const schema: AnySchema = this.shape[name];
    if (schema === undefined) {
      return null;
    }
    const r = schema.validate(value);
    return r.valid ? null : r.errors[0].message;
  }

  /** 异步校验单个字段(支持 customAsync 远程查重)。 */
  async validateFieldAsync(name: string, value: Object | null | undefined): Promise<string | null> {
    const schema: AnySchema = this.shape[name];
    if (schema === undefined) {
      return null;
    }
    const r = await schema.validateAsync(value);
    return r.valid ? null : r.errors[0].message;
  }

  /** 整体校验，返回只含出错字段的 map(字段名 -> 错误信息)。 */
  validateAll(values: Record<string, Object>): Record<string, string> {
    const errors: Record<string, string> = {};
    const keys = Object.keys(this.shape);
    for (const key of keys) {
      // 传入整组值作为 siblings，使字段的 requiredWhen 条件能读取兄弟字段
      const r = this.shape[key].validate(values[key], values);
      if (!r.valid) {
        errors[key] = r.errors[0].message;
      }
    }
    return errors;
  }

  /** 整体是否通过。 */
  isValid(values: Record<string, Object>): boolean {
    return Object.keys(this.validateAll(values)).length === 0;
  }
}
