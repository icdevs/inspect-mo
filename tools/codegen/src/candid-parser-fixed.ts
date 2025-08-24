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
      .replace(/\s+/g, ' ') // Normalize whitespace
      .trim();

    // Extract service definition - improved to handle complex formatting
    const serviceMatch = cleanContent.match(/service\s*:\s*\{([^}]+)\}/);
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

    // Parse methods - improved to handle multi-line and various formats
    // Split by semicolons first to handle each method separately
    const methodLines = serviceContent.split(';').map(line => line.trim()).filter(line => line);
    
    for (const methodLine of methodLines) {
      // Match method pattern: methodName: (params) -> (return) [query]
      const methodMatch = methodLine.match(/(\w+)\s*:\s*\(([^)]*)\)\s*->\s*\(([^)]*)\)\s*(query)?/);
      if (methodMatch) {
        const [, name, paramsStr, returnStr, queryFlag] = methodMatch;
        
        // Parse parameters
        const parameters: CandidParameter[] = [];
        if (paramsStr.trim()) {
          // Split parameters, handling nested structures
          const paramParts = splitParameters(paramsStr);
          for (const param of paramParts) {
            const colonIndex = param.indexOf(':');
            if (colonIndex > 0) {
              // Named parameter: name: type
              const paramName = param.substring(0, colonIndex).trim();
              const paramType = param.substring(colonIndex + 1).trim();
              parameters.push({
                name: paramName,
                type: parseType(paramType)
              });
            } else {
              // Unnamed parameter: just type
              parameters.push({
                name: null,
                type: parseType(param.trim())
              });
            }
          }
        }

        methods.push({
          name,
          parameters,
          returnType: parseType(returnStr.trim()),
          isQuery: !!queryFlag
        });
      }
    }

    if (methods.length === 0) {
      warnings.push('No methods found in service definition');
    }

    return {
      success: true,
      errors: [],
      warnings,
      service: { methods }
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

function parseType(typeStr: string): CandidType {
  const trimmed = typeStr.trim();
  
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
  } else if (trimmed === '()') {
    return { kind: 'null' };
  }
  
  // Handle vec types
  const vecMatch = trimmed.match(/^vec\s+(.+)$/);
  if (vecMatch) {
    return {
      kind: 'vec',
      inner: parseType(vecMatch[1])
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
          type: parseType(fieldType)
        });
      } else {
        // Unnamed field
        fields.push({
          name: null,
          type: parseType(field.trim())
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
          type: parseType(optionType)
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
      inner: parseType(optMatch[1])
    };
  }
  
  // Handle function types
  if (trimmed.includes('->')) {
    return { kind: 'func' };
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
