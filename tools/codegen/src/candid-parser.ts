/**
 * Candid (.did) file parser for InspectMo code generation
 */

import { readFileSync } from 'fs';
import { 
  CandidService, 
  CandidMethod, 
  CandidType, 
  CandidParameter, 
  ParseResult
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
  
  try {
    // Remove comments and normalize whitespace
    const cleanContent = content
      .replace(/\/\/.*$/gm, '') // Remove line comments  
      .replace(/\/\*[\s\S]*?\*\//g, '') // Remove block comments
      .trim();

    // Parse type definitions first
    const typeDefinitions = new Map<string, string>();
    const typeMatches = cleanContent.matchAll(/type\s+(\w+)\s*=\s*([\s\S]*?)(?=(?:type\s+\w+|service\s*:))/g);
    for (const match of typeMatches) {
      const [, typeName, typeDefinition] = match;
      typeDefinitions.set(typeName, typeDefinition.trim());
    }

    // Extract service definition - handle multiline properly
    const serviceMatch = cleanContent.match(/service\s*:\s*\{([\s\S]*)\}/);
    if (!serviceMatch) {
      return {
        success: false,
        errors: ['No service definition found'],
        warnings: [],
        service: null
      };
    }

    const serviceContent = serviceMatch[1];
    const methods: CandidMethod[] = [];

    // Parse methods - split by semicolon and handle each method
    const methodDeclarations = serviceContent.split(';')
      .map(line => line.trim())
      .filter(line => line && !line.match(/^\s*$/));
    
    for (const methodDecl of methodDeclarations) {
      // Use a more flexible parsing approach
      const colonIndex = methodDecl.indexOf(':');
      if (colonIndex === -1) continue;
      
      const methodName = methodDecl.substring(0, colonIndex).trim();
      const signaturePart = methodDecl.substring(colonIndex + 1).trim();
      
      // Check if it's a query method
      const isQuery = signaturePart.includes('query');
      const cleanSignature = signaturePart.replace(/\s+query\s*$/, '').trim();
      
      // Parse signature: (params) -> returnType
      const arrowIndex = cleanSignature.indexOf('->');
      if (arrowIndex === -1) continue;
      
      const paramsPart = cleanSignature.substring(0, arrowIndex).trim();
      const returnPart = cleanSignature.substring(arrowIndex + 2).trim();
      
      // Extract parameters from (...)
      const paramsMatch = paramsPart.match(/^\((.*)\)$/);
      if (!paramsMatch) continue;
      
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
              type: parseType(paramType, typeDefinitions)
            });
          } else {
            // Unnamed parameter: just type
            parameters.push({
              name: null,
              type: parseType(param.trim(), typeDefinitions)
            });
          }
        }
      }

      methods.push({
        name: methodName,
        parameters,
        returnType: parseType(returnPart.replace(/^\(|\)$/g, '').trim(), typeDefinitions), // Remove outer parentheses if present
        isQuery,
        annotations: []
      });
    }

    if (methods.length === 0) {
      warnings.push('No methods found in service definition');
    }

    return {
      success: true,
      errors: [],
      warnings,
      service: { methods, types: [] }
    };

  } catch (error) {
    return {
      success: false,
      errors: [`Parse error: ${error}`],
      warnings: [],
      service: null
    };
  }
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
    const optionParts = splitParameters(variantContent);
    
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
