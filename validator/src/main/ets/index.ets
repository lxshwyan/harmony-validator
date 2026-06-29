import { StringSchema } from './schemas/StringSchema';
import { NumberSchema } from './schemas/NumberSchema';
import { ObjectSchema, SchemaShape } from './schemas/ObjectSchema';
import { ArraySchema } from './schemas/ArraySchema';
import { AnySchema } from './core/types';

/**
 * 校验器工厂。统一入口，用法：
 *   v.string().required().phone()
 *   v.object({ 'phone': v.string().phone(), 'age': v.number().min(18) })
 *   v.array(v.string().min(2)).min(1)
 */
export class v {
  static string(): StringSchema {
    return new StringSchema();
  }

  static number(): NumberSchema {
    return new NumberSchema();
  }

  static object(shape: SchemaShape): ObjectSchema {
    return new ObjectSchema(shape);
  }

  /** 数组校验：逐元素套用 element 校验器。 */
  static array(element: AnySchema): ArraySchema {
    return new ArraySchema(element);
  }
}
