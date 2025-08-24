/**
 * Core types for Motoko code parsing and analysis
 */

export interface MotokoMethod {
  name: string;
  isQuery: boolean;
  isPublic: boolean;
  parameters: MotokoParameter[];
  returnType: string;
  sourceLocation: SourceLocation;
  annotations?: string[];
}

export interface MotokoParameter {
  name: string;
  type: string;
  isOptional: boolean;
}

export interface SourceLocation {
  start: Position;
  end: Position;
  file: string;
}

export interface Position {
  line: number;
  column: number;
}

export interface MotokoActor {
  name?: string;
  methods: MotokoMethod[];
  imports: MotokoImport[];
  sourceFile: string;
}

export interface MotokoImport {
  name: string;
  path: string;
  isAlias: boolean;
}

export interface InspectCall {
  methodName: string;
  rules: ValidationRule[];
  sourceLocation: SourceLocation;
}

export interface GuardCall {
  methodName: string;
  rules: ValidationRule[];
  sourceLocation: SourceLocation;
}

export interface ValidationRule {
  type: 'textSize' | 'blobSize' | 'natValue' | 'intValue' | 'requireAuth' | 'requirePermission' | 'blockIngress' | 'blockAll' | 'custom' | 'dynamicAuth' | 'customCheck';
  accessor?: string;
  parameters?: any[];
}

export interface ParsedCanister {
  actor: MotokoActor;
  inspectCalls: InspectCall[];
  guardCalls: GuardCall[];
  hasInspectMoImport: boolean;
  inspectMoAlias?: string;
}

export interface CodeGenerationOptions {
  outputDirectory: string;
  generateAccessors: boolean;
  generateInspectFunction: boolean;
  generateMethodExtractor: boolean;
  generateValidationHelpers: boolean;
  templateCustomizations?: TemplateCustomizations;
}

export interface TemplateCustomizations {
  inspectFunctionName?: string;
  accessorPrefix?: string;
  methodExtractorName?: string;
  includeComments?: boolean;
  includeDebugLogging?: boolean;
}

export interface GeneratedCode {
  accessors?: string;
  inspectFunction?: string;
  methodExtractor?: string;
  validationHelpers?: string;
  types?: string;
}

export interface ParserError {
  message: string;
  location?: SourceLocation;
  severity: 'error' | 'warning' | 'info';
}

export interface ParserResult<T> {
  data?: T;
  errors: ParserError[];
  warnings: ParserError[];
}
