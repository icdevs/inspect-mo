/**
 * Type definitions for Candid parsing and code generation
 */

// Enhanced Candid type representations with recursive type support
export interface CandidType {
  kind: 'text' | 'nat' | 'int' | 'bool' | 'blob' | 'principal' | 'record' | 'variant' | 'vec' | 'opt' | 'service' | 'null' | 'func' | 'custom' | 'tuple' | 'recursive';
  fields?: CandidField[];
  inner?: CandidType; // For vec, opt types
  options?: CandidVariant[]; // For variant types
  name?: string; // For custom types
  tupleTypes?: CandidType[]; // For tuple types
  isRecursive?: boolean; // For recursive type detection
  referenceName?: string; // For recursive type references
  depth?: number; // For tracking parsing depth
}

export interface CandidField {
  name: string | null; // Allow null for unnamed fields
  type: CandidType;
  index?: number; // For positional field access
}

export interface CandidVariant {
  name: string;
  type?: CandidType | null;
  index?: number; // For positional variant access
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

// Service definition with enhanced type tracking
export interface CandidService {
  methods: CandidMethod[];
  types?: CandidTypeDefinition[]; // Make types optional
  typeDefinitions?: Map<string, CandidType>; // Enhanced type tracking
  complexTypes?: string[]; // Track complex type names
  isActorClass?: boolean; // Whether this is an actor class pattern
  serviceTypeName?: string | null; // Name of the service type for actor classes
}

export interface CandidTypeDefinition {
  name: string;
  type: CandidType;
  isRecursive?: boolean; // Track if type is recursive
  dependencies?: string[]; // Track type dependencies
}

// Code generation context with enhanced options
export interface GenerationContext {
  serviceName: string;
  service: CandidService;
  outputPath: string;
  options: GenerationOptions;
  typeDefinitions?: Map<string, CandidType>; // Pass type definitions to generator
  recursiveTypes?: Set<string>; // Track recursive types
}

export interface GenerationOptions {
  generateAccessors: boolean;
  generateInspectTemplate: boolean;
  generateGuardTemplate: boolean;
  generateMethodExtraction: boolean;
  generateTypeDefinitions: boolean; // Generate missing type definitions
  includeComments: boolean;
  typescript?: boolean;  // For future TypeScript support
  handleRecursiveTypes?: boolean; // Handle recursive type generation
  maxDepth?: number; // Max depth for recursive type parsing
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

// Parser result with enhanced tracking
export interface ParseResult {
  success: boolean;
  service?: CandidService | null;
  errors: string[];
  warnings: string[];
  typeDefinitions?: Map<string, CandidType>; // Parsed type definitions
  missingTypes?: string[]; // Types referenced but not defined
  recursiveTypes?: string[]; // Types that are recursive
}

// New interfaces for enhanced functionality
export interface TypeParsingContext {
  typeDefinitions: Map<string, CandidType>;
  currentDepth: number;
  maxDepth: number;
  recursionStack: string[]; // Track current parsing path
  errors: string[];
  warnings: string[];
}

export interface AutoDiscoveryOptions {
  projectRoot: string;
  includePatterns: string[]; // Glob patterns for .did files
  excludePatterns: string[]; // Patterns to exclude
  scanMotokoFiles: boolean; // Scan .mo files for InspectMo usage
  generateMissingTypes: boolean; // Auto-generate missing type definitions
}

export interface ProjectAnalysis {
  didFiles: string[];
  motokoFiles: string[];
  inspectMoUsage: InspectMoUsage[];
  missingTypes: string[];
  suggestedIntegrations: IntegrationSuggestion[];
}

export interface InspectMoUsage {
  filePath: string;
  lineNumber: number;
  methodName: string;
  usageType: 'inspect' | 'guard';
  complexity: 'simple' | 'complex';
}

export interface IntegrationSuggestion {
  type: 'build-hook' | 'auto-generation' | 'missing-types';
  description: string;
  implementation: string;
  priority: 'high' | 'medium' | 'low';
}
