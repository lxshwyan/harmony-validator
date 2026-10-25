import { AnySchema } from './types';

/**
 * Replay a complete schema constructor for every create(). The constructor must
 * create its mutable children inside the callback; this is not a schema clone.
 */
export class SchemaFactory<S extends AnySchema<Object | null | undefined>> {
  private build: () => S;

  constructor(build: () => S) {
    this.build = build;
  }

  create(): S {
    return this.build();
  }

  /** Configuration is replayed on a fresh graph; deriving does not run it yet. */
  derive<R extends AnySchema<Object | null | undefined>>(configure: (schema: S) => R): SchemaFactory<R> {
    return new SchemaFactory<R>((): R => configure(this.create()));
  }
}
