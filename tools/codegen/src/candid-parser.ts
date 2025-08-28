/**
 * Enhanced Candid (.did) file parser for InspectMo code generation
 * Supports complex types, recursive structures, and comprehensive type tracking
 */

import { readFileSync } from 'fs';
import { 
  CandidService, 
  CandidMethod, 
  CandidType, 
  CandidParameter, 
  ParseResult,
  TypeParsingContext,
  CandidTypeDefinition
} from './types';

export function parseCandidFile(filePath: string): ParseResult {
  try {
    const content = readFileSync(filePath, 'utf-8');
    return parseCandidContent(content);
  } catch (error) {
    return {
      success: false,
      errors: [`Failed to read file: ${error}`],
      warnings: [],
      service: null
    };
  }
}

export function parseCandidContent(content: string): ParseResult {
  const errors: string[] = [];
  const warnings: string[] = [];
  const typeDefinitions = new Map<string, CandidType>();
  const missingTypes: string[] = [];
  const recursiveTypes: string[] = [];
  
  try {
    // Remove comments and normalize whitespace
    const cleanContent = content
      .replace(/\/\/.*$/gm, '') // Remove line comments  
      .replace(/\/\*[\s\S]*?\*\//g, '') // Remove block comments
      .trim();

    // Parse type definitions first with enhanced context
    const context: TypeParsingContext = {
      typeDefinitions,
      currentDepth: 0,
      maxDepth: 50, // Prevent infinite recursion
      recursionStack: [],
      errors,
      warnings
    };

    parseTypeDefinitions(cleanContent, context);

    // Extract service definition - handle both direct service and actor class patterns using brace-depth parsing
    let serviceBody: string | null = null;
    let isActorClass = false;
    let serviceTypeName: string | null = null;

    // Direct service pattern: service : { ... }
    const directServiceIdx = cleanContent.search(/service\s*:\s*\{/);
    if (directServiceIdx !== -1) {
      const braceStart = cleanContent.indexOf('{', directServiceIdx);
      if (braceStart !== -1) {
        const extracted = extractBalancedBlock(cleanContent, braceStart);
        if (extracted) {
          serviceBody = extracted.block;
        }
      }
    }

    if (!serviceBody) {
      // Actor class pattern: service : (...) -> ServiceType
      const actorClassMatch = cleanContent.match(/service\s*:\s*\([^)]*\)\s*->\s*(\w+)/);
      if (actorClassMatch) {
        isActorClass = true;
        serviceTypeName = actorClassMatch[1];

        // Find the typedef start: type <ServiceTypeName> = service { ... }
        const typedefRegex = new RegExp(`type\\s+${serviceTypeName}\\s*=\\s*service\\s*\\{`, 'i');
        const typedefMatch = cleanContent.match(typedefRegex);
        if (typedefMatch && typedefMatch.index !== undefined) {
          const braceStart = cleanContent.indexOf('{', typedefMatch.index);
          if (braceStart !== -1) {
            const extracted = extractBalancedBlock(cleanContent, braceStart);
            if (extracted) {
              serviceBody = extracted.block;
            }
          }
        } else {
          return {
            success: false,
            errors: [`Actor class service type '${serviceTypeName}' definition not found`],
            warnings: [],
            service: null,
            typeDefinitions,
            missingTypes,
            recursiveTypes
          };
        }
      }
    }

    if (!serviceBody) {
      return {
        success: false,
        errors: ['No service definition found'],
        warnings: [],
        service: null,
        typeDefinitions,
        missingTypes,
        recursiveTypes
      };
    }

    const serviceContent = serviceBody;
    const methods: CandidMethod[] = [];

    // Parse methods - split by semicolon at top-level only (records/variants can contain semicolons)
    const methodDeclarations = splitMethodDeclarations(serviceContent)
      .map(line => line.trim())
      .filter(line => line && !line.match(/^\s*$/));
    
    for (const methodDecl of methodDeclarations) {
      const method = parseMethodDeclaration(methodDecl, context);
      if (method) {
        methods.push(method);
      }
    }

    if (methods.length === 0) {
      warnings.push('No methods found in service definition');
    }

    // Track missing types
    const allReferencedTypes = new Set<string>();
    methods.forEach(method => {
      collectReferencedTypes(method.returnType, allReferencedTypes);
      method.parameters.forEach(param => collectReferencedTypes(param.type, allReferencedTypes));
    });

    for (const typeName of allReferencedTypes) {
      if (!typeDefinitions.has(typeName) && !isBuiltinType(typeName)) {
        missingTypes.push(typeName);
      }
    }

    return {
      success: true,
      errors: context.errors,
      warnings: context.warnings,
      service: { 
        methods, 
        types: Array.from(typeDefinitions.entries()).map(([name, type]) => ({ name, type })),
        typeDefinitions,
        complexTypes: Array.from(allReferencedTypes),
        isActorClass,
        serviceTypeName
      },
      typeDefinitions,
      missingTypes,
      recursiveTypes
    };

  } catch (error) {
    return {
      success: false,
      errors: [`Parse error: ${error}`],
      warnings: [],
      service: null,
      typeDefinitions,
      missingTypes,
      recursiveTypes
    };
  }
}

// Split service method declarations by ';' but ignore semicolons inside parentheses or braces
function splitMethodDeclarations(content: string): string[] {
  const decls: string[] = [];
  let current = '';
  let paren = 0;  // () depth
  let brace = 0;  // {} depth
  let bracket = 0; // [] depth (rare in candid signatures)

  for (let i = 0; i < content.length; i++) {
    const ch = content[i];
    if (ch === '(') paren++;
    else if (ch === ')') paren = Math.max(0, paren - 1);
    else if (ch === '{') brace++;
    else if (ch === '}') brace = Math.max(0, brace - 1);
    else if (ch === '[') bracket++;
    else if (ch === ']') bracket = Math.max(0, bracket - 1);

    if (ch === ';' && paren === 0 && brace === 0 && bracket === 0) {
      const trimmed = current.trim();
      if (trimmed) decls.push(trimmed);
      current = '';
      continue;
    }
    current += ch;
  }

  const tail = current.trim();
  if (tail) decls.push(tail);
  return decls;
}

// Extract a balanced {...} block starting at the given '{' index; returns block contents without outer braces and end index
function extractBalancedBlock(text: string, openIndex: number): { block: string; end: number } | null {
  if (text[openIndex] !== '{') return null;
  let depth = 0;
  for (let i = openIndex; i < text.length; i++) {
    const ch = text[i];
    if (ch === '{') depth++;
    else if (ch === '}') {
      depth--;
      if (depth === 0) {
        const block = text.substring(openIndex + 1, i);
        return { block, end: i };
      }
    }
  }
  return null;
}

// Helper function to split parameters correctly, handling nested structures
function splitParameters(paramsStr: string): string[] {
  const params: string[] = [];
  let current = '';
  let depth = 0;
  
  for (let i = 0; i < paramsStr.length; i++) {
    const char = paramsStr[i];
    
    if (char === '(' || char === '{' || char === '<') {
      depth++;
    } else if (char === ')' || char === '}' || char === '>') {
      depth--;
    } else if (char === ',' && depth === 0) {
      if (current.trim()) {
        params.push(current.trim());
      }
      current = '';
      continue;
    }
    
    current += char;
  }
  
  if (current.trim()) {
    params.push(current.trim());
  }
  
  return params;
}

function splitRecordFields(fieldsStr: string): string[] {
  const fields: string[] = [];
  let current = '';
  let depth = 0;
  
  for (let i = 0; i < fieldsStr.length; i++) {
    const char = fieldsStr[i];
    
    if (char === '(' || char === '{' || char === '<') {
      depth++;
    } else if (char === ')' || char === '}' || char === '>') {
      depth--;
    } else if (char === ';' && depth === 0) {
      if (current.trim()) {
        fields.push(current.trim());
      }
      current = '';
      continue;
    }
    
    current += char;
  }
  
  if (current.trim()) {
    fields.push(current.trim());
  }
  
  return fields;
}

function parseType(typeStr: string, typeDefinitions?: Map<string, string>): CandidType {
  const trimmed = typeStr.trim();
  
  // Handle empty type (unit type)
  if (trimmed === '' || trimmed === '()') {
    return { kind: 'null' };
  }
  
  // Handle basic types
  if (trimmed === 'text') {
    return { kind: 'text' };
  } else if (trimmed === 'nat') {
    return { kind: 'nat' };
  } else if (trimmed === 'int') {
    return { kind: 'int' };
  } else if (trimmed === 'bool') {
    return { kind: 'bool' };
  } else if (trimmed === 'blob') {
    return { kind: 'blob' };
  } else if (trimmed === 'principal') {
    return { kind: 'principal' };
  }
  
  // Handle vec types
  const vecMatch = trimmed.match(/^vec\s+(.+)$/);
  if (vecMatch) {
    return {
      kind: 'vec',
      inner: parseType(vecMatch[1], typeDefinitions)
    };
  }
  
  // Handle record types
  const recordMatch = trimmed.match(/^record\s*\{([^}]+)\}$/);
  if (recordMatch) {
    const fields: { name: string | null; type: CandidType }[] = [];
    const fieldContent = recordMatch[1];
    const fieldParts = splitParameters(fieldContent);
    
    for (const field of fieldParts) {
      const colonIndex = field.indexOf(':');
      if (colonIndex > 0) {
        const fieldName = field.substring(0, colonIndex).trim();
        const fieldType = field.substring(colonIndex + 1).trim();
        fields.push({
          name: fieldName,
          type: parseType(fieldType, typeDefinitions)
        });
      } else {
        // Unnamed field: just type
        fields.push({
          name: null,
          type: parseType(field.trim(), typeDefinitions)
        });
      }
    }
    
    return {
      kind: 'record',
      fields
    };
  }
  
  // Handle variant types
  const variantMatch = trimmed.match(/^variant\s*\{([^}]+)\}$/);
  if (variantMatch) {
    const options: { name: string; type: CandidType | null }[] = [];
    const variantContent = variantMatch[1];
    const optionParts = splitRecordFields(variantContent); // Variants also use semicolons
    
    for (const option of optionParts) {
      const colonIndex = option.indexOf(':');
      if (colonIndex > 0) {
        const optionName = option.substring(0, colonIndex).trim();
        const optionType = option.substring(colonIndex + 1).trim();
        options.push({
          name: optionName,
          type: parseType(optionType, typeDefinitions)
        });
      } else {
        // Option without type
        options.push({
          name: option.trim(),
          type: null
        });
      }
    }
    
    return {
      kind: 'variant',
      options
    };
  }
  
  // Handle opt types
  const optMatch = trimmed.match(/^opt\s+(.+)$/);
  if (optMatch) {
    return {
      kind: 'opt',
      inner: parseType(optMatch[1], typeDefinitions)
    };
  }
  
  // Handle function types
  if (trimmed.includes('->')) {
    return { kind: 'func' };
  }
  
  // Check for custom/named types in type definitions
  if (typeDefinitions && typeDefinitions.has(trimmed)) {
    // For now, treat custom types as their own kind and let the code generator handle them
    return { 
      kind: 'custom',
      name: trimmed
    };
  }
  
  // Custom/named types - check if it matches known custom types
  if (trimmed === 'Result') {
    return { 
      kind: 'variant',
      options: [
        { name: 'ok', type: { kind: 'text' } },
        { name: 'err', type: { kind: 'text' } }
      ]
    };
  }
  
  // Default fallback
  console.log(`Unknown type: ${trimmed}, defaulting to text`);
  return { kind: 'text' };
}

/**
 * Enhanced type parsing with context support
 */
function parseTypeWithContext(typeStr: string, context: TypeParsingContext): CandidType {
  const trimmed = typeStr.trim();
  
  // Prevent infinite recursion
  if (context.currentDepth > context.maxDepth) {
    context.errors.push(`Maximum parsing depth exceeded for type: ${trimmed}`);
    return { kind: 'text' };
  }

  context.currentDepth++;

  try {
    // Handle empty type (unit type)
    if (trimmed === '' || trimmed === '()') {
      return { kind: 'null' };
    }
    
    // Handle basic types
    const basicTypes = ['text', 'nat', 'int', 'bool', 'blob', 'principal'];
    if (basicTypes.includes(trimmed)) {
      return { kind: trimmed as any };
    }
    
    // Handle vec types
    const vecMatch = trimmed.match(/^vec\s+(.+)$/);
    if (vecMatch) {
      return {
        kind: 'vec',
        inner: parseTypeWithContext(vecMatch[1], context)
      };
    }
    
    // Handle opt types
    const optMatch = trimmed.match(/^opt\s+(.+)$/);
    if (optMatch) {
      return {
        kind: 'opt',
        inner: parseTypeWithContext(optMatch[1], context)
      };
    }

    // Handle record types with improved parsing
    const recordMatch = trimmed.match(/^record\s*\{([\s\S]*)\}$/);
    if (recordMatch) {
      const fields: { name: string | null; type: CandidType; index?: number }[] = [];
      const fieldContent = recordMatch[1].trim();
      
      if (fieldContent) {
        // Record fields are separated by semicolons, not commas
        const fieldParts = splitRecordFields(fieldContent);
        
        for (let i = 0; i < fieldParts.length; i++) {
          const field = fieldParts[i].trim();
          const colonIndex = field.indexOf(':');
          
          if (colonIndex > 0) {
            const fieldName = field.substring(0, colonIndex).trim();
            const fieldType = field.substring(colonIndex + 1).trim();
            fields.push({
              name: fieldName,
              type: parseTypeWithContext(fieldType, context),
              index: i
            });
          } else {
            // Unnamed field: just type (tuple-like record)
            fields.push({
              name: null,
              type: parseTypeWithContext(field, context),
              index: i
            });
          }
        }
      }
      
      return {
        kind: 'record',
        fields
      };
    }
    
    // Handle variant types
    const variantMatch = trimmed.match(/^variant\s*\{([\s\S]*)\}$/);
    if (variantMatch) {
      const options: { name: string; type: CandidType | null; index?: number }[] = [];
      const variantContent = variantMatch[1].trim();
      
      if (variantContent) {
        const optionParts = splitRecordFields(variantContent); // Variants use semicolons
        
        for (let i = 0; i < optionParts.length; i++) {
          const option = optionParts[i].trim();
          const colonIndex = option.indexOf(':');
          
          if (colonIndex > 0) {
            const optionName = option.substring(0, colonIndex).trim();
            const optionType = option.substring(colonIndex + 1).trim();
            options.push({
              name: optionName,
              type: parseTypeWithContext(optionType, context),
              index: i
            });
          } else {
            // Option without type
            options.push({
              name: option.trim(),
              type: null,
              index: i
            });
          }
        }
      }
      
      return {
        kind: 'variant',
        options
      };
    }

    // Handle tuple types (anonymous records)
    const tupleMatch = trimmed.match(/^record\s*\{\s*([^:}]+(?:\s*;\s*[^:}]+)*)\s*\}$/);
    if (tupleMatch) {
      const tupleTypes: CandidType[] = [];
      const typeContent = tupleMatch[1].trim();
      const typeParts = typeContent.split(';').map(part => part.trim());
      
      for (const typeStr of typeParts) {
        tupleTypes.push(parseTypeWithContext(typeStr, context));
      }
      
      return {
        kind: 'tuple',
        tupleTypes
      };
    }
    
    // Handle function types
    if (trimmed.includes('->')) {
      return { kind: 'func' };
    }
    
    // Check for custom/named types in type definitions
    if (context.typeDefinitions.has(trimmed)) {
      const existingType = context.typeDefinitions.get(trimmed)!;
      
      // Check for circular reference
      if (context.recursionStack.includes(trimmed)) {
        context.warnings.push(`Circular reference detected for type: ${trimmed}`);
        return { 
          kind: 'recursive',
          name: trimmed,
          referenceName: trimmed
        };
      }
      
      return existingType;
    }
    
    // Handle known Result types
    if (trimmed.startsWith('Result')) {
      return { 
        kind: 'variant',
        options: [
          { name: 'ok', type: { kind: 'text' } },
          { name: 'err', type: { kind: 'text' } }
        ]
      };
    }
    
    // Custom/named type not yet defined
    context.warnings.push(`Unknown type referenced: ${trimmed}`);
    return { 
      kind: 'custom',
      name: trimmed
    };

  } finally {
    context.currentDepth--;
  }
}

/**
 * Parse type definitions from the Candid content
 */
function parseTypeDefinitions(content: string, context: TypeParsingContext): void {
  // Improved regex that properly matches complete type definitions
  const typeRegex = /type\s+(\w+)\s*=\s*((?:record\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}|variant\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}|[^;]+))\s*;/g;
  
  let match;
  while ((match = typeRegex.exec(content)) !== null) {
    const [, typeName, typeDefinition] = match;
    const cleanDefinition = typeDefinition.trim();
    
    try {
      // Check for recursive reference
      if (context.recursionStack.includes(typeName)) {
        context.warnings.push(`Recursive type detected: ${typeName}`);
        context.typeDefinitions.set(typeName, { kind: 'recursive', name: typeName, referenceName: typeName });
        continue;
      }

      context.recursionStack.push(typeName);
      const parsedType = parseTypeWithContext(cleanDefinition, context);
      context.typeDefinitions.set(typeName, parsedType);
      context.recursionStack.pop();
      
    } catch (error) {
      context.errors.push(`Failed to parse type ${typeName}: ${error}`);
    }
  }
}

/**
 * Parse a method declaration
 */
function parseMethodDeclaration(methodDecl: string, context: TypeParsingContext): CandidMethod | null {
  try {
    // Use a more flexible parsing approach
    const colonIndex = methodDecl.indexOf(':');
    if (colonIndex === -1) return null;
    
    const methodName = methodDecl.substring(0, colonIndex).trim();
    const signaturePart = methodDecl.substring(colonIndex + 1).trim();
    
    // Check if it's a query method
    const isQuery = signaturePart.includes('query');
    const cleanSignature = signaturePart.replace(/\s+query\s*$/, '').trim();
    
    // Parse signature: (params) -> returnType
    const arrowIndex = cleanSignature.indexOf('->');
    if (arrowIndex === -1) return null;
    
    const paramsPart = cleanSignature.substring(0, arrowIndex).trim();
    const returnPart = cleanSignature.substring(arrowIndex + 2).trim();
    
    // Extract parameters from (...) - use multiline flag for records spanning multiple lines
    const paramsMatch = paramsPart.match(/^\(([\s\S]*)\)$/);
    if (!paramsMatch) return null;
    
    const paramsStr = paramsMatch[1].trim();
    const parameters: CandidParameter[] = [];
    
    if (paramsStr) {
      // Split parameters, being careful with nested structures
      const paramParts = splitParameters(paramsStr);
      
      for (const param of paramParts) {
        const colonIndex = param.indexOf(':');
        if (colonIndex > 0) {
          // Named parameter: name: type
          const paramName = param.substring(0, colonIndex).trim();
          const paramType = param.substring(colonIndex + 1).trim();
          parameters.push({
            name: paramName,
            type: parseTypeWithContext(paramType, context)
          });
        } else {
          // Unnamed parameter: just type
          parameters.push({
            name: null,
            type: parseTypeWithContext(param.trim(), context)
          });
        }
      }
    }

    return {
      name: methodName,
      parameters,
      returnType: parseTypeWithContext(returnPart.replace(/^\(|\)$/g, '').trim(), context), // Remove outer parentheses if present
      isQuery,
      annotations: []
    };
  } catch (error) {
    context.errors.push(`Failed to parse method ${methodDecl}: ${error}`);
    return null;
  }
}

/**
 * Collect all type names referenced in a CandidType
 */
function collectReferencedTypes(type: CandidType, collector: Set<string>): void {
  switch (type.kind) {
    case 'custom':
      if (type.name) {
        collector.add(type.name);
      }
      break;
    case 'vec':
    case 'opt':
      if (type.inner) {
        collectReferencedTypes(type.inner, collector);
      }
      break;
    case 'record':
      if (type.fields) {
        type.fields.forEach(field => collectReferencedTypes(field.type, collector));
      }
      break;
    case 'variant':
      if (type.options) {
        type.options.forEach(option => {
          if (option.type) {
            collectReferencedTypes(option.type, collector);
          }
        });
      }
      break;
    case 'tuple':
      if (type.tupleTypes) {
        type.tupleTypes.forEach(tupleType => collectReferencedTypes(tupleType, collector));
      }
      break;
  }
}

/**
 * Check if a type name is a builtin Candid type
 */
function isBuiltinType(typeName: string): boolean {
  const builtins = ['text', 'nat', 'int', 'bool', 'blob', 'principal', 'null', 'empty', 'reserved'];
  return builtins.includes(typeName.toLowerCase());
}
