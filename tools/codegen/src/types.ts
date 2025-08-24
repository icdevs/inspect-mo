/**
 * Type definitions for Candid parsing and code generation
 */

// Candid type representations
export interface CandidType {
  kind: 'text' | 'nat' | 'int' | 'bool' | 'blob' | 'principal' | 'record' | 'variant' | 'vec' | 'opt' | 'service' | 'null' | 'func' | 'custom';
  fields?: CandidField[];
  inner?: CandidType; // For vec, opt types
  options?: CandidVariant[]; // For variant types
  name?: string; // For custom types
}

export interface CandidField {
  name: string | null; // Allow null for unnamed fields
  type: CandidType;
}

export interface CandidVariant {
  name: string;
  type?: CandidType | null;
}

// Method representations
export interface CandidMethod {
  name: string;
  parameters: CandidParameter[];
  returnType: CandidType;
  isQuery: boolean;
  annotations?: string[]; // Make annotations optional
}

export interface CandidParameter {
  name?: string | null; // Allow null for unnamed parameters
  type: CandidType;
}

// Service definition
export interface CandidService {
  methods: CandidMethod[];
  types?: CandidTypeDefinition[]; // Make types optional
}

export interface CandidTypeDefinition {
  name: string;
  type: CandidType;
}

// Code generation context
export interface GenerationContext {
  serviceName: string;
  service: CandidService;
  outputPath: string;
  options: GenerationOptions;
}

export interface GenerationOptions {
  generateAccessors: boolean;
  generateInspectTemplate: boolean;
  generateGuardTemplate: boolean;
  generateMethodExtraction: boolean;
  includeComments: boolean;
  typescript?: boolean;  // For future TypeScript support
}

// Motoko code generation templates
export interface MotokoTemplates {
  accessorFunction: string;
  inspectFunction: string;
  guardFunction: string;
  methodExtraction: string;
  imports: string;
}

// Analysis results
export interface MethodAnalysis {
  method: CandidMethod;
  suggestedValidations: ValidationSuggestion[];
  complexity: 'simple' | 'medium' | 'complex';
  securityConsiderations: string[];
}

export interface ValidationSuggestion {
  type: 'textSize' | 'blobSize' | 'natRange' | 'intRange' | 'requireAuth' | 'requirePermission' | 'blockIngress' | 'blockAll' | 'custom';
  rule: string;
  reason: string;
  priority: 'high' | 'medium' | 'low';
}

// Parser result
export interface ParseResult {
  success: boolean;
  service?: CandidService | null;
  errors: string[];
  warnings: string[];
}
