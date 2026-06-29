import { StringSchema } from './schemas/StringSchema';
import { NumberSchema } from './schemas/NumberSchema';
import { ObjectSchema, SchemaShape } from './schemas/ObjectSchema';

/**
 * 校验器工厂。统一入口，用法：
 *   v.string().required().phone()
 *   v.object({ phone: v.string().phone(), age: v.number().min(18) })
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
}
