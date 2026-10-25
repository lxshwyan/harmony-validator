/** Structural bridge types; no runtime dependency on @standard-schema/spec. */
export interface HmkitIssue { path: string; message: string; code?: string; }
export interface HmkitResult<T> { success: boolean; value?: T; errors: HmkitIssue[]; }
export interface HmkitSchema<T> {
  readonly __schemaType: T | null;
  validate(value: unknown, siblings?: unknown, options?: object): {valid: boolean; errors: HmkitIssue[]};
  validateAsync(value: unknown, siblings?: unknown, options?: object): Promise<{valid: boolean; errors: HmkitIssue[]}>;
  parse?(value: unknown, siblings?: unknown, options?: object): HmkitResult<T>;
  parseAsync?(value: unknown, siblings?: unknown, options?: object): Promise<HmkitResult<T>>;
}
export interface StandardIssue { readonly message: string; readonly path?: ReadonlyArray<PropertyKey | {readonly key: PropertyKey}>; }
export interface StandardBridge<T> {
  readonly '~standard': {
    readonly version: 1;
    readonly vendor: string;
    readonly validate: (value: unknown, options?: {libraryOptions?: Record<string, unknown>}) =>
      {value: T; issues?: undefined} | {issues: ReadonlyArray<StandardIssue>} |
      Promise<{value: T; issues?: undefined} | {issues: ReadonlyArray<StandardIssue>}>;
    readonly types?: {readonly input: unknown; readonly output: T};
  };
}
export interface BridgeOptions {
  /** Must be true if rules include asynchronous validation. */
  async?: boolean;
  validationOptions?: object;
  /** Override when a native dotted path is ambiguous (e.g. literal dotted keys). */
  mapPath?: (error: HmkitIssue) => ReadonlyArray<PropertyKey | {readonly key: PropertyKey}>;
}
export function toStandardSchema<T>(schema: HmkitSchema<T>, options?: BridgeOptions): StandardBridge<T>;
