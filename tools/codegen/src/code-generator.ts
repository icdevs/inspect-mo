/**
 * Code generator for InspectMo boilerplate from Candid interfaces
 */

import { 
  CandidService, 
  CandidMethod, 
  CandidType, 
  CandidParameter,
  GenerationContext,
  MethodAnalysis,
  ValidationSuggestion
} from './types';
import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

export class MotokoCodeGenerator {

  /**
   * Generate Motoko types file using didc and return the module name for import
   */
  private generateTypesFile(candidFilePath: string, outputPath: string): string {
    try {
      // Convert to absolute path to avoid working directory issues
      const absolutePath = path.resolve(candidFilePath);
      
  // Use didc to generate Motoko bindings (allow overriding path via DIDC env)
  const didcBin = process.env.DIDC || 'didc';
  const didcOutput = execSync(`${didcBin} bind --target mo "${absolutePath}"`, { 
        encoding: 'utf8'
      });

      // Extract only the type definitions (everything before the Self type)
      const lines = didcOutput.split('\n');
      const typeDefinitions: string[] = [];
      let inModule = false;
      
      for (const line of lines) {
        if (line.trim() === 'module {') {
          inModule = true;
          typeDefinitions.push(line);
          continue;
        }
        
        if (inModule) {
          // Stop when we reach the Self actor definition
          if (line.includes('public type Self = actor')) {
            typeDefinitions.push('}'); // Close the module
            break;
          }
          
          // Include all type definitions
          typeDefinitions.push(line);
        }
      }

  // Generate the types file path (ensure absolute)
  const absOutputPath = path.resolve(outputPath);
  const outputDir = path.dirname(absOutputPath);
      const baseName = path.basename(outputPath, '.mo');
      const typesFileName = `${baseName}_types.mo`;
      const typesFilePath = path.join(outputDir, typesFileName);

      // Ensure the output directory exists (handles absolute -o like /src/generated/...)
      if (!fs.existsSync(outputDir)) {
        try {
          fs.mkdirSync(outputDir, { recursive: true });
        } catch (e) {
          throw new Error(`Failed to create directory '${outputDir}': ${e}`);
        }
      }

      // Write the types file
      const typesContent = typeDefinitions.join('\n');
  fs.writeFileSync(typesFilePath, typesContent, 'utf-8');
      
      console.log(`📄 Generated types file: ${typesFilePath}`);
      
      return typesFileName.replace('.mo', ''); // Return module name for import

    } catch (error) {
      console.warn(`Warning: Could not generate types using didc: ${error}`);
      return '';
    }
  }

  /**
   * Generate complete InspectMo boilerplate for a service using ErasedValidator pattern
   */
  public generateBoilerplate(context: GenerationContext, candidFilePath?: string): string {
    const { service, options } = context;
    const parts: string[] = [];

    // Generate types file first if we have candidFilePath
    let typesModuleName = '';
    if (candidFilePath) {
      typesModuleName = this.generateTypesFile(candidFilePath, context.outputPath);
    }

    // Header and imports - updated for ErasedValidator pattern
    parts.push(this.generateHeader(typesModuleName));
    parts.push('');
    parts.push('module {');
    parts.push('');

    // Type aliases if we generated types
    if (typesModuleName) {
      parts.push(this.generateTypeAliases(service));
      parts.push('');
    }

    // Args union type for ErasedValidator pattern
    if (options.generateMethodExtraction) {
      parts.push(this.generateArgsUnionType(service));
      parts.push('');
    }

    // Type-safe accessor functions for ErasedValidator pattern
    if (options.generateAccessors) {
      parts.push(this.generateErasedValidatorAccessors(service));
      parts.push('');
    }

    // Usage examples and templates (commented out)
    parts.push(this.generateUsageExamples(service));

    parts.push('}'); // Close module

    return parts.join('\n');
  }

  /**
   * Generate usage examples and templates as commented code
   */
  private generateUsageExamples(service: CandidService): string {
    const parts: string[] = [];
    
    parts.push('  /// Usage Examples (copy and customize as needed):');
    parts.push('  /*');
    parts.push('  /// Step 1: Create InspectMo instance');
    parts.push('  let inspectMo = InspectMo.InspectMo(');
    parts.push('    null, // stored state');
    parts.push('    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"), // instantiator');
    parts.push('    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), // canister');
    parts.push('    ?{');
    parts.push('      allowAnonymous = ?false;');
    parts.push('      defaultMaxArgSize = ?1048576;');
    parts.push('      authProvider = null;');
    parts.push('      rateLimit = null;');
    parts.push('      queryDefaults = null;');
    parts.push('      updateDefaults = null;');
    parts.push('      developmentMode = ?false;');
    parts.push('      auditLog = ?false;');
    parts.push('    }, // init args');
    parts.push('    null, // environment');
    parts.push('    func(state) {} // storage changed callback');
    parts.push('  );');
    parts.push('');
    parts.push('  /// Step 2: Create inspector with Args type');
    parts.push('  let inspector = inspectMo.createInspector<Args>();');
    parts.push('');
    parts.push('  /// Step 3: Register method validations based on Candid analysis');
    
    // Generate actual method registrations with real validation rules
    const analysis = this.analyzeService(service);
    for (const method of service.methods) {
      const methodAnalysis = analysis.find(a => a.method.name === method.name);
      parts.push(`  // Register ${method.name} method`);
      
      // Determine the parameter type for the generic
      let parameterType = '()';
      let messageAccessor = 'unit_accessor';
      
      if (method.parameters.length === 1) {
        parameterType = this.inferParameterType(
          method.parameters[0],
          method.name,
          service.typeDefinitions || new Map()
        );
        const cleanMethodName = this.toCamelCase(method.name);
        const cleanParamName = this.capitalize(method.parameters[0].name || 'param');
        const accessorName = `get${this.capitalize(cleanMethodName)}${cleanParamName}`;
        messageAccessor = `${accessorName}`;
      } else if (method.parameters.length > 1) {
        const paramTypes = method.parameters
          .map(p => this.inferParameterType(p, method.name, service.typeDefinitions || new Map()))
          .join(', ');
        parameterType = `(${paramTypes})`;
        messageAccessor = 'func(args: Args): () { () } // TODO: Multi-parameter accessor';
      }
      
      parts.push(`  inspector.inspect(inspector.createMethodGuardInfo<${parameterType}>(`);
      parts.push(`    "${method.name}",`);
      parts.push(`    ${method.isQuery}, // isQuery`);
      parts.push(`    [`);
      
      // Add validation rules based on analysis
      const rules: string[] = [];
      if (methodAnalysis?.suggestedValidations) {
        for (const validation of methodAnalysis.suggestedValidations) {
          switch (validation.type) {
            case 'textSize':
              rules.push('      InspectMo.textSize(identity, ?1, ?1000)');
              break;
            case 'natRange':
              const cleanMethodName = this.toCamelCase(method.name);
              const cleanParamName = this.capitalize(method.parameters[0]?.name || 'param');
              const accessorName = `get${this.capitalize(cleanMethodName)}${cleanParamName}`;
              rules.push(`      InspectMo.natValue(${accessorName}_identity, ?0, ?1000000)`);
              break;
          }
        }
      }
      
      // Always add auth requirement for sensitive methods
      if (!method.isQuery || method.name.includes('create') || method.name.includes('update') || method.name.includes('delete')) {
        rules.push('      InspectMo.requireAuth()');
      }
      
      if (rules.length === 0) {
        rules.push('      InspectMo.requireAuth() // Add appropriate validation rules');
      }
      
      parts.push(rules.join(',\n'));
      parts.push(`    ],`);
      parts.push(`    ${messageAccessor} // Message accessor`);
      parts.push(`  ));`);
      parts.push('');
    }
    parts.push('');
    parts.push('  /// Example: System inspect function');
    parts.push('  system func inspect({');
    parts.push('    arg : Blob;');
    parts.push('    caller : Principal;');
    parts.push('    msg : {');
    
  for (const method of service.methods) {
      if (method.parameters.length === 0) {
        parts.push(`      #${method.name} : () -> ();`);
      } else if (method.parameters.length === 1) {
    const paramType = this.enhancedTypeToMotokoString(method.parameters[0].type, service.typeDefinitions || new Map());
        parts.push(`      #${method.name} : () -> (${paramType});`);
      } else {
    const paramTypes = method.parameters.map(p => this.enhancedTypeToMotokoString(p.type, service.typeDefinitions || new Map())).join(', ');
        parts.push(`      #${method.name} : () -> (${paramTypes});`);
      }
    }
    
    parts.push('    }');
    parts.push('  }) : Bool {');
    parts.push('    // Your validation logic here');
    parts.push('    true');
    parts.push('  };');
    parts.push('  */');
    
    return parts.join('\n');
  }

  /**
   * Generate analysis for each method with validation suggestions
   */
  public analyzeService(service: CandidService): MethodAnalysis[] {
    return service.methods.map(method => this.analyzeMethod(method));
  }

  /**
   * Generate header with imports and documentation
   */
  private generateHeader(typesModuleName?: string): string {
    let header = `/// Auto-generated InspectMo integration module using ErasedValidator pattern
/// Generated from Candid interface
/// 
/// This module contains:
/// - Args union type for ErasedValidator pattern
/// - Type-safe accessor functions for method parameters  
/// - ErasedValidator initialization template
/// - System inspect function template
///
/// Usage:
/// 1. Import this module in your canister
/// 2. Copy the Args union type to your canister
/// 3. Use the ErasedValidator initialization code
/// 4. Customize validation rules as needed

import Principal "mo:core/Principal";
import Result "mo:core/Result";
import Runtime "mo:core/Runtime";`;

    // Add types import if available
    if (typesModuleName) {
      header += `\nimport Types "./${typesModuleName}";`;
    }

    return header;
  }

  /**
   * Generate type-safe accessor functions for each parameter type
   */
  private generateAccessorFunctions(service: CandidService): string {
    const accessors = new Set<string>();
    const parts: string[] = ['  /// Type-safe accessor functions'];

    for (const method of service.methods) {
      for (const param of method.parameters) {
        const accessor = this.generateBasicAccessorForType(param.type, param.name || undefined);
        if (accessor && !accessors.has(accessor)) {
          accessors.add(accessor);
          parts.push(`  ${accessor}`); // Add module indentation
        }
      }
    }

    return parts.join('\n');
  }

  /**
   * Generate basic accessor function for simple types (legacy method)
   */
  private generateBasicAccessorForType(type: CandidType, paramName?: string): string | null {
    const name = paramName || 'value';
    
    switch (type.kind) {
      case 'text':
        return `public func get${this.capitalize(name)}Text(args: (Text)) : Text { args.0 };`;
      
      case 'nat':
        return `public func get${this.capitalize(name)}Nat(args: (Nat)) : Nat { args.0 };`;
      
      case 'int':
        return `public func get${this.capitalize(name)}Int(args: (Int)) : Int { args.0 };`;
      
      case 'bool':
        return `public func get${this.capitalize(name)}Bool(args: (Bool)) : Bool { args.0 };`;
      
      case 'blob':
        return `public func get${this.capitalize(name)}Blob(args: (Blob)) : Blob { args.0 };`;
      
      case 'principal':
        return `func get${this.capitalize(name)}Principal(args: (Principal)) : Principal { args.0 };`;
      
      // For complex types, generate comment
      case 'record':
      case 'variant':
      case 'vec':
      case 'opt':
        return `// TODO: Use delegated accessors for ${type.kind} type`;
      
      default:
        return null;
    }
  }

  /**
   * Generate delegated accessor functions for complex types (MVP approach)
   * Instead of trying to parse nested structures, generate helper functions
   * that delegate field extraction to the user
   */
  private generateDelegatedAccessors(service: CandidService): string {
    const parts: string[] = [];
    const complexTypes = new Set<string>();
    
    // Collect all complex record types used in methods
    for (const method of service.methods) {
      for (const param of method.parameters) {
        this.collectComplexTypes(param.type, complexTypes);
      }
    }
    
    // Filter out malformed type names
    const validComplexTypes = Array.from(complexTypes).filter(typeName => {
      return this.isValidTypeName(typeName) && !this.isMalformedTypeName(typeName);
    });
    
    // If no valid complex types, return simple message
    if (validComplexTypes.length === 0) {
      return '  /// No complex types detected - only simple parameter accessors needed';
    }
    
    parts.push('  /// Delegated accessor functions for complex types');
    parts.push('  /// Users implement the field extraction logic themselves');
    parts.push('  ///');
    parts.push('  /// Example usage:');
    parts.push('  /// let userEmail = getUserProfileText(userProfile, func(p: UserProfile) : Text { p.email });');
    parts.push('  /// let userAge = getUserProfileNat(userProfile, func(p: UserProfile) : Nat { p.age });');
    parts.push('');
    
    for (const typeName of validComplexTypes) {
      parts.push(this.generateTypeAccessors(typeName));
      parts.push('');
    }
    
    return parts.join('\n');
  }

  /**
   * Generate accessor functions for a specific complex type
   */
  private generateTypeAccessors(typeName: string): string {
    const parts: string[] = [];
    const capitalizedType = this.capitalize(typeName);
    
    parts.push(`  /// Delegated accessors for ${typeName} type`);
    parts.push(`  /// User provides extraction logic for each field type`);
    parts.push('');
    
    // Generate Text accessor
    parts.push(`  public func get${capitalizedType}Text(`);
    parts.push(`    record: ${typeName},`);
    parts.push(`    extractor: (${typeName}) -> Text`);
    parts.push(`  ): Text {`);
    parts.push(`    extractor(record)`);
    parts.push(`  };`);
    parts.push('');
    
    // Generate Nat accessor  
    parts.push(`  public func get${capitalizedType}Nat(`);
    parts.push(`    record: ${typeName},`);
    parts.push(`    extractor: (${typeName}) -> Nat`);
    parts.push(`  ): Nat {`);
    parts.push(`    extractor(record)`);
    parts.push(`  };`);
    parts.push('');
    
    // Generate Int accessor
    parts.push(`  public func get${capitalizedType}Int(`);
    parts.push(`    record: ${typeName},`);
    parts.push(`    extractor: (${typeName}) -> Int`);
    parts.push(`  ): Int {`);
    parts.push(`    extractor(record)`);
    parts.push(`  };`);
    parts.push('');
    
    // Generate Bool accessor
    parts.push(`  public func get${capitalizedType}Bool(`);
    parts.push(`    record: ${typeName},`);
    parts.push(`    extractor: (${typeName}) -> Bool`);
    parts.push(`  ): Bool {`);
    parts.push(`    extractor(record)`);
    parts.push(`  };`);
    parts.push('');
    
    // Generate Blob accessor
    parts.push(`  public func get${capitalizedType}Blob(`);
    parts.push(`    record: ${typeName},`);
    parts.push(`    extractor: (${typeName}) -> Blob`);
    parts.push(`  ): Blob {`);
    parts.push(`    extractor(record)`);
    parts.push(`  };`);
    parts.push('');
    
    // Generate Principal accessor
    parts.push(`  public func get${capitalizedType}Principal(`);
    parts.push(`    record: ${typeName},`);
    parts.push(`    extractor: (${typeName}) -> Principal`);
    parts.push(`  ): Principal {`);
    parts.push(`    extractor(record)`);
    parts.push(`  };`);
    parts.push('');
    
    // Generate optional Text accessor
    parts.push(`  public func get${capitalizedType}OptText(`);
    parts.push(`    record: ${typeName},`);
    parts.push(`    extractor: (${typeName}) -> ?Text`);
    parts.push(`  ): ?Text {`);
    parts.push(`    extractor(record)`);
    parts.push(`  };`);
    parts.push('');
    
    // Generate array accessors
    parts.push(`  public func get${capitalizedType}TextArray(`);
    parts.push(`    record: ${typeName},`);
    parts.push(`    extractor: (${typeName}) -> [Text]`);
    parts.push(`  ): [Text] {`);
    parts.push(`    extractor(record)`);
    parts.push(`  };`);
    parts.push('');
    
    parts.push(`  public func get${capitalizedType}NatArray(`);
    parts.push(`    record: ${typeName},`);
    parts.push(`    extractor: (${typeName}) -> [Nat]`);
    parts.push(`  ): [Nat] {`);
    parts.push(`    extractor(record)`);
    parts.push(`  };`);
    
    return parts.join('\n');
  }

  /**
   * Generate type aliases for convenience - only for types that actually exist
   */
  private generateTypeAliases(service: CandidService): string {
    const aliases: string[] = [];
    const typeDefinitions = service.typeDefinitions || new Map();
    
    // Add aliases for all parsed type definitions, but keep it small and safe
    const names = Array.from(typeDefinitions.keys());
    for (const typeName of names) {
      if (this.isValidTypeName(typeName)) {
        aliases.push(`  public type ${typeName} = Types.${typeName};`);
      }
    }
    
    // If no aliases, return empty comment
    if (aliases.length === 0) {
      return '  /// No type aliases needed for this service';
    }
    
    return `  /// Type aliases for convenience\n${aliases.join('\n')}`;
  }

  /**
   * Sort type definitions to handle dependencies (simple topological sort)
   */
  private sortTypeDefinitionsByDependencies(typeDefinitions: Map<string, CandidType>): [string, CandidType][] {
    const sorted: [string, CandidType][] = [];
    const visited = new Set<string>();
    const visiting = new Set<string>();
    
    const visit = (typeName: string) => {
      if (visited.has(typeName)) return;
      if (visiting.has(typeName)) {
        // Circular dependency - just add it
        return;
      }
      
      visiting.add(typeName);
      const type = typeDefinitions.get(typeName);
      if (type) {
        // Visit dependencies first (simplified)
        this.getTypeDependencies(type).forEach(dep => {
          if (typeDefinitions.has(dep)) {
            visit(dep);
          }
        });
        
        sorted.push([typeName, type]);
        visited.add(typeName);
      }
      visiting.delete(typeName);
    };
    
    // Visit all types
    for (const typeName of typeDefinitions.keys()) {
      visit(typeName);
    }
    
    return sorted;
  }

  /**
   * Get type dependencies for sorting
   */
  private getTypeDependencies(type: CandidType): string[] {
    const deps: string[] = [];
    
    switch (type.kind) {
      case 'custom':
        if (type.name) deps.push(type.name);
        break;
      case 'vec':
      case 'opt':
        if (type.inner) {
          deps.push(...this.getTypeDependencies(type.inner));
        }
        break;
      case 'record':
        if (type.fields) {
          type.fields.forEach(field => {
            deps.push(...this.getTypeDependencies(field.type));
          });
        }
        break;
      case 'variant':
        if (type.options) {
          type.options.forEach(option => {
            if (option.type) {
              deps.push(...this.getTypeDependencies(option.type));
            }
          });
        }
        break;
      case 'tuple':
        if (type.tupleTypes) {
          type.tupleTypes.forEach(tupleType => {
            deps.push(...this.getTypeDependencies(tupleType));
          });
        }
        break;
    }
    
    return deps.filter(dep => dep !== 'text' && dep !== 'nat' && dep !== 'int' && dep !== 'bool' && dep !== 'blob' && dep !== 'principal');
  }

  /**
   * Convert a Candid type to Motoko type syntax
   */
  private convertCandidTypeToMotoko(type: CandidType, typeDefinitions: Map<string, CandidType>): string {
    switch (type.kind) {
      case 'text': return 'Text';
      case 'nat': return 'Nat';
      case 'int': return 'Int';
      case 'bool': return 'Bool';
      case 'blob': return 'Blob';
      case 'principal': return 'Principal';
      case 'null': return '()';
      
      case 'vec':
        return `[${type.inner ? this.convertCandidTypeToMotoko(type.inner, typeDefinitions) : 'Text'}]`;
        
      case 'opt':
        return `?${type.inner ? this.convertCandidTypeToMotoko(type.inner, typeDefinitions) : 'Text'}`;
        
      case 'custom':
        return type.name || 'Text';
        
      case 'record':
        if (type.fields && type.fields.length > 0) {
          const fields = type.fields.map(field => {
            if (field.name) {
              // Named field
              return `    ${field.name}: ${this.convertCandidTypeToMotoko(field.type, typeDefinitions)}`;
            } else {
              // Tuple-style record (positional) - this should be rare
              return `    ${this.convertCandidTypeToMotoko(field.type, typeDefinitions)}`;
            }
          });
          return `{\n${fields.join(';\n')};\n  }`;
        }
        return '{}';
        
      case 'variant':
        if (type.options && type.options.length > 0) {
          const options = type.options.map(option => {
            if (option.type && option.type.kind !== 'null') {
              return `    #${option.name}: ${this.convertCandidTypeToMotoko(option.type, typeDefinitions)}`;
            } else {
              return `    #${option.name}`;
            }
          });
          return `{\n${options.join(';\n')};\n  }`;
        }
        return '{}';
        
      case 'tuple':
        if (type.tupleTypes && type.tupleTypes.length > 0) {
          const types = type.tupleTypes.map(t => this.convertCandidTypeToMotoko(t, typeDefinitions));
          return `(${types.join(', ')})`;
        }
        return '()';
        
      default:
        return 'Text'; // Safe fallback
    }
  }

  /**
   * Collect custom type names that need to be defined
   */
  private collectCustomTypeNames(type: CandidType, collector: Set<string>): void {
    switch (type.kind) {
      case 'custom':
        // Only add well-formed custom type names (not inline type definitions)
        if (type.name && 
            !this.isBuiltinType(type.name) && 
            this.isValidTypeName(type.name)) {
          collector.add(type.name);
        }
        break;
      case 'vec':
      case 'opt':
        if (type.inner) {
          this.collectCustomTypeNames(type.inner, collector);
        }
        break;
      case 'record':
        // Don't add inline record types to the collector
        if (type.fields) {
          type.fields.forEach(field => this.collectCustomTypeNames(field.type, collector));
        }
        break;
      case 'variant':
        // Don't add inline variant types to the collector
        if (type.options) {
          type.options.forEach(option => {
            if (option.type) {
              this.collectCustomTypeNames(option.type, collector);
            }
          });
        }
        break;
    }
  }

  /**
   * Check if a string is a valid Motoko type name (not a complex type definition)
   */
  private isValidTypeName(name: string): boolean {
    // Type names should be alphanumeric and underscore only, starting with a letter
    // Reject names that contain special characters indicating they're actually inline type definitions
    return /^[A-Za-z][A-Za-z0-9_]*$/.test(name) && 
           !name.includes(':') && 
           !name.includes(';') && 
           !name.includes('{') && 
           !name.includes('}') && 
           !name.includes('(') && 
           !name.includes(')') && 
           !name.includes('record') && 
           !name.includes('variant') && 
           !name.includes('vec') && 
           !name.includes('opt') && 
           name.length < 50; // Reject very long names that are likely malformed
  }

  /**
   * Check if a type is a built-in Motoko type
   */
  private isBuiltinType(typeName: string): boolean {
    const builtins = ['Text', 'Nat', 'Int', 'Bool', 'Blob', 'Principal', 'Result', 'Option'];
    return builtins.includes(typeName);
  }

  /**
   * Collect complex type names that need delegated accessors
   */
  private collectComplexTypes(type: CandidType, collector: Set<string>): void {
    switch (type.kind) {
      case 'custom':
        // Only add custom types that have valid names and are known types
        if (type.name && this.isValidTypeName(type.name) && !this.isMalformedTypeName(type.name)) {
          // Only add types that are in our known types list or look like proper type names
          if (this.isKnownCustomType(type.name) || (type.name.length < 20 && !type.name.includes('{'))) {
            collector.add(type.name);
          }
        }
        break;
      case 'vec':
        if (type.inner) {
          this.collectComplexTypes(type.inner, collector);
        }
        break;
      case 'opt':
        if (type.inner) {
          this.collectComplexTypes(type.inner, collector);
        }
        break;
      // Don't collect generic record/variant types since they're undefined
      case 'record':
      case 'variant':
        // Skip these - they should be named custom types
        break;
    }
  }

  /**
   * Generate method name extraction utilities
   */
  private generateMethodExtraction(service: CandidService): string {
    const parts: string[] = [
      '  /// MessageAccessor type for method discrimination',
      '  public type MessageAccessor = {',
    ];

    // Generate variant type for all methods
    for (const method of service.methods) {
      const paramTypes = method.parameters
        .map(p => this.enhancedTypeToMotokoString(p.type, service.typeDefinitions || new Map()))
        .join(', ');
      const params = paramTypes ? `(${paramTypes})` : '()';
      parts.push(`    #${method.name} : ${params};`);
    }

    parts.push('  };');
    parts.push('');
    
    // Generate method name extraction function
    parts.push('  public func extractMethodName(call: MessageAccessor) : Text {');
    parts.push('    switch (call) {');
    
    for (const method of service.methods) {
      parts.push(`      case (#${method.name} _) { "${method.name}" };`);
    }
    
    parts.push('    }');
    parts.push('  };');

    return parts.join('\n');
  }

  /**
   * Generate inspect function template with pattern matching
   */
  private generateInspectTemplate(service: CandidService): string {
    const parts: string[] = [
      '  /// Helper function for integration with your system inspect',
      '  /// Call this from your system func inspect with the inspector object',
      '  public func inspectHelper(',
      '    msg: MessageAccessor,',
      '    inspector: InspectMo.Inspector<MessageAccessor>',
      '  ) : Bool {',
      '    let methodName = extractMethodName(msg);',
      '    ',
      '    // Use InspectMo to check the method',
      '    switch (inspector.inspectCheck({',
      '      caller = ?inspector.getCaller(); // Get from context',
      '      arg = ?inspector.getArgBlob(); // Get from context', 
      '      methodName = methodName;',
      '      isQuery = ?isQueryMethod(methodName);',
      '      msg = msg;',
      '      isIngress = true;',
      '      parsedArgs = null;',
      '      argSizes = [];',
      '      argTypes = [];',
      '    })) {',
      '      case (true) { true };',
      '      case (false) { false };',
      '    }',
      '  };',
      '',
      '  /// Helper to determine if a method is a query',
      '  public func isQueryMethod(methodName: Text) : Bool {',
      '    switch (methodName) {'
    ];

    // Add query method detection
    for (const method of service.methods) {
      if (method.isQuery) {
        parts.push(`      case ("${method.name}") { true };`);
      }
    }

    parts.push('      case (_) { false };');
    parts.push('    }');
    parts.push('  };');
    parts.push('');
    parts.push('  /// Usage example:');
    parts.push('  /// In your actor:');
    parts.push('  /// system func inspect({');
    parts.push('  ///   caller : Principal;');
    parts.push('  ///   arg : Blob;');
    parts.push('  ///   msg : MessageAccessor');
    parts.push('  /// }) : Bool {');
    parts.push('  ///   // Your custom pre-validation here');
    parts.push('  ///   ');
    parts.push('  ///   // Use the helper');
    parts.push('  ///   MyInspectModule.inspectHelper(msg, myInspector)');
    parts.push('  /// };');

    return parts.join('\n');
  }

  /**
   * Generate guard function helpers
   */
  private generateGuardTemplate(service: CandidService): string {
    const parts: string[] = [
      '  /// Guard function helpers for runtime validation',
      '  /// Use these in your method implementations for business logic validation',
      ''
    ];

    const updateMethods = service.methods.filter(m => !m.isQuery);
    
    for (const method of updateMethods) {
      const analysis = this.analyzeMethod(method);
  const argsType = this.generateMethodArgsType(method, service.typeDefinitions || new Map());
      
      parts.push(`  // Guard helper for ${method.name}`);
      parts.push(`  public func guard${this.capitalize(method.name)}(args: ${argsType}, caller: Principal) : Result.Result<(), Text> {`);
      parts.push(`    // TODO: Implement runtime business logic validation`);
      
      if (analysis.securityConsiderations.length > 0) {
        parts.push(`    // Security considerations:`);
        for (const consideration of analysis.securityConsiderations) {
          parts.push(`    //   - ${consideration}`);
        }
      }
      
      parts.push(`    #ok(())`);
      parts.push(`  };`);
      parts.push('');
    }

    return parts.join('\n');
  }

  /**
   * Generate the proper args type for a method's parameters
   */
  private generateMethodArgsType(method: CandidMethod, defs?: Map<string, CandidType>): string {
    if (method.parameters.length === 0) {
      return '()';
    }
    
    if (method.parameters.length === 1) {
      return this.enhancedTypeToMotokoString(method.parameters[0].type, defs || new Map());
    }
    
    // Multiple parameters - create a tuple
  const paramTypes = method.parameters.map(p => this.enhancedTypeToMotokoString(p.type, defs || new Map()));
    return `(${paramTypes.join(', ')})`;
  }

  /**
   * Analyze a method and suggest validations
   */
  private analyzeMethod(method: CandidMethod): MethodAnalysis {
    const suggestions: ValidationSuggestion[] = [];
    const securityConsiderations: string[] = [];

    // Analyze parameters for validation suggestions
    for (const param of method.parameters) {
      const paramSuggestions = this.analyzeParameter(param);
      suggestions.push(...paramSuggestions);
    }

    // Smart method name-based suggestions
    const methodNameSuggestions = this.analyzeMethodName(method);
    suggestions.push(...methodNameSuggestions);

    // Security analysis
    if (!method.isQuery) {
      securityConsiderations.push('Consider requiring authentication');
      if (method.parameters.length > 0) {
        securityConsiderations.push('Validate all input parameters');
      }
    }

    // Method-specific security considerations
    const methodSecuritySuggestions = this.analyzeMethodSecurity(method);
    securityConsiderations.push(...methodSecuritySuggestions);

    // Determine complexity
    let complexity: 'simple' | 'medium' | 'complex' = 'simple';
    if (method.parameters.length > 2) complexity = 'medium';
    if (method.parameters.some(p => p.type.kind === 'record' || p.type.kind === 'variant')) {
      complexity = 'complex';
    }

    return {
      method,
      suggestedValidations: suggestions,
      complexity,
      securityConsiderations
    };
  }

  /**
   * Analyze a parameter and suggest validations
   */
  private analyzeParameter(param: CandidParameter): ValidationSuggestion[] {
    const suggestions: ValidationSuggestion[] = [];
    const paramName = param.name || 'parameter';

    switch (param.type.kind) {
      case 'text':
        suggestions.push({
          type: 'textSize',
          rule: `InspectMo.textSize(get${this.capitalize(paramName)}Text, ?1, ?1000)`,
          reason: 'Validate text length to prevent DoS attacks',
          priority: 'high'
        });
        break;

      case 'blob':
        suggestions.push({
          type: 'blobSize',
          rule: `InspectMo.blobSize(get${this.capitalize(paramName)}Blob, ?1, ?1048576)`,
          reason: 'Validate blob size to prevent memory exhaustion',
          priority: 'high'
        });
        break;

      case 'nat':
        suggestions.push({
          type: 'natRange',
          rule: `InspectMo.natValue(get${this.capitalize(paramName)}Nat, ?0, ?1000000)`,
          reason: 'Validate numeric range to prevent overflow',
          priority: 'medium'
        });
        break;

      case 'int':
        suggestions.push({
          type: 'intRange',
          rule: `InspectMo.intValue(get${this.capitalize(paramName)}Int, ?-1000000, ?1000000)`,
          reason: 'Validate numeric range to prevent overflow',
          priority: 'medium'
        });
        break;
    }

    return suggestions;
  }

  /**
   * Analyze method name for smart validation suggestions
   */
  private analyzeMethodName(method: CandidMethod): ValidationSuggestion[] {
    const suggestions: ValidationSuggestion[] = [];
    const methodName = method.name.toLowerCase();

    // Message/communication patterns
    if (methodName.includes('send') || methodName.includes('message') || methodName.includes('post')) {
      if (method.parameters.some(p => p.type.kind === 'text')) {
        suggestions.push({
          type: 'textSize',
          rule: `InspectMo.textSize(getMessageText, ?1, ?500)`,
          reason: 'Message methods should validate text length to prevent spam',
          priority: 'high'
        });
      }
    }

    // Upload/file patterns
    if (methodName.includes('upload') || methodName.includes('store') || methodName.includes('save')) {
      if (method.parameters.some(p => p.type.kind === 'blob')) {
        suggestions.push({
          type: 'blobSize',
          rule: `InspectMo.blobSize(getDataBlob, ?1, ?1048576)`,
          reason: 'Upload methods should limit file sizes to prevent DoS',
          priority: 'high'
        });
      }
      suggestions.push({
        type: 'requireAuth',
        rule: `InspectMo.requireAuth()`,
        reason: 'Upload methods typically require authentication',
        priority: 'high'
      });
    }

    // Admin/management patterns
    if (methodName.includes('admin') || methodName.includes('manage') || methodName.includes('config')) {
      suggestions.push({
        type: 'requirePermission',
        rule: `InspectMo.requirePermission("admin")`,
        reason: 'Admin methods should require special permissions',
        priority: 'high'
      });
    }

    // Internal/system patterns
    if (methodName.includes('internal') || methodName.includes('system')) {
      suggestions.push({
        type: 'blockIngress',
        rule: `InspectMo.blockIngress()`,
        reason: 'Internal methods should only be callable from other canisters',
        priority: 'high'
      });
    }

    // Delete/clear patterns
    if (methodName.includes('delete') || methodName.includes('clear') || methodName.includes('remove')) {
      suggestions.push({
        type: 'requireAuth',
        rule: `InspectMo.requireAuth()`,
        reason: 'Destructive operations should require authentication',
        priority: 'high'
      });
    }

    // Update/modify patterns
    if (methodName.includes('update') || methodName.includes('modify') || methodName.includes('edit')) {
      suggestions.push({
        type: 'requireAuth',
        rule: `InspectMo.requireAuth()`,
        reason: 'Modification methods should require authentication',
        priority: 'medium'
      });
    }

    // Payment/transfer patterns
    if (methodName.includes('pay') || methodName.includes('transfer') || methodName.includes('deposit')) {
      suggestions.push({
        type: 'requireAuth',
        rule: `InspectMo.requireAuth()`,
        reason: 'Financial operations must require authentication',
        priority: 'high'
      });
      if (method.parameters.some(p => p.type.kind === 'nat')) {
        suggestions.push({
          type: 'natRange',
          rule: `InspectMo.natValue(getAmountNat, ?1, ?1000000000)`,
          reason: 'Financial amounts should be validated for reasonable ranges',
          priority: 'high'
        });
      }
    }

    return suggestions;
  }

  /**
   * Analyze method for security considerations based on name and pattern
   */
  private analyzeMethodSecurity(method: CandidMethod): string[] {
    const considerations: string[] = [];
    const methodName = method.name.toLowerCase();

    // Public API considerations
    if (methodName.includes('public') || methodName.includes('api')) {
      considerations.push('Public API - consider rate limiting');
      considerations.push('Add comprehensive input validation');
    }

    // Sensitive data patterns
    if (methodName.includes('profile') || methodName.includes('user') || methodName.includes('account')) {
      considerations.push('Handles user data - ensure privacy compliance');
      considerations.push('Consider data access controls');
    }

    // Batch operation patterns
    if (methodName.includes('batch') || methodName.includes('bulk') || methodName.includes('mass')) {
      considerations.push('Batch operations - consider resource limits');
      considerations.push('Implement pagination for large datasets');
    }

    // Query vs Update mismatch warnings
    if (method.isQuery && (methodName.includes('set') || methodName.includes('update') || methodName.includes('create'))) {
      considerations.push('WARNING: Method name suggests mutation but declared as query');
    }

    if (!method.isQuery && (methodName.includes('get') || methodName.includes('list') || methodName.includes('fetch'))) {
      considerations.push('Consider if this method should be a query instead of update');
    }

    // Expensive operation patterns
    if (methodName.includes('compute') || methodName.includes('calculate') || methodName.includes('process')) {
      considerations.push('Computational method - consider instruction limits');
      considerations.push('May need async patterns for complex calculations');
    }

    return considerations;
  }

  /**
   * Convert Candid type to Motoko type string (simplified for compilation)
   */
  private typeToMotokoString(type: CandidType): string {
    switch (type.kind) {
      case 'text': return 'Text';
      case 'nat': return 'Nat';
      case 'int': return 'Int';
      case 'bool': return 'Bool';
      case 'blob': return 'Blob';
      case 'principal': return 'Principal';
      case 'null': return '()';
      case 'vec':
        // For generated code, simplify vec types to avoid compilation issues
        return '[Any]';
      case 'opt':
        const innerType = type.inner ? this.typeToMotokoString(type.inner) : 'Any';
        return `?${innerType}`;
      case 'record':
        // Simplify records to a generic type to avoid inline type compilation issues
        return 'Any';
      case 'variant':
        // Simplify variants to a generic type to avoid inline type compilation issues
        return 'Any';
      case 'custom':
        // Check if the custom type name is malformed (contains problematic characters)
        if (type.name && this.isMalformedTypeName(type.name)) {
          return 'Any';
        }
        return type.name || 'Any';
      default:
        return 'Any';
    }
  }

  /**
   * Check if a type name is malformed (contains characters that would break Motoko compilation)
   */
  private isMalformedTypeName(name: string): boolean {
    // Check for characters that indicate this is not a proper type name
    return name.includes(';') || 
           name.includes('\n') || 
           name.includes('{') || 
           name.includes('}') || 
           name.includes('record') || 
           name.includes('variant') || 
           name.includes('vec') || 
           name.includes('opt') || 
           name.length > 100; // Very long names are likely malformed
  }

  /**
   * Generate Args union type for ErasedValidator pattern with proper type names
   * This should exactly match the message type structure from system inspect function
   */
  private generateArgsUnionType(service: CandidService): string {
    const parts: string[] = [];
    const defs = service.typeDefinitions || new Map<string, CandidType>();
    
    parts.push('  /// Args union type for ErasedValidator pattern');
    parts.push('  /// This matches the message type structure from system inspect function');
    parts.push('  public type Args = {');
    
    for (const method of service.methods) {
      // Preserve original method name case
      const methodName = method.name;
      
      if (method.parameters.length === 0) {
        parts.push(`    #${methodName} : () -> ();`);
      } else if (method.parameters.length === 1) {
        // For single parameter, use intelligent type inference
        const paramType = this.inferParameterType(method.parameters[0], method.name, defs);
        parts.push(`    #${methodName} : () -> (${paramType});`);
      } else {
        // For multiple parameters, use tuple of parameter types
        const paramTypes = method.parameters.map(p => this.inferParameterType(p, method.name, defs)).join(', ');
        parts.push(`    #${methodName} : () -> (${paramTypes});`);
      }
    }
    
    parts.push('  };');
    
    return parts.join('\n');
  }

  /**
   * Intelligent parameter type inference that uses parameter names and context
   */
  private inferParameterType(
    parameter: CandidParameter,
    _methodName?: string,
    typeDefinitions?: Map<string, CandidType>
  ): string {
    // Strictly derive the type from the parsed Candid type; do not guess from names
    return this.enhancedTypeToMotokoString(parameter.type, typeDefinitions);
  }

  /**
   * Enhanced type conversion that preserves custom type names
   */
  private enhancedTypeToMotokoString(type: CandidType, typeDefinitions?: Map<string, CandidType>): string {
    const defs = typeDefinitions || new Map<string, CandidType>();
    switch (type.kind) {
      case 'text': return 'Text';
      case 'nat': return 'Nat';
      case 'int': return 'Int';
      case 'bool': return 'Bool';
      case 'blob': return 'Blob';
      case 'principal': return 'Principal';
      case 'null': return '()';
      case 'vec':
        return `[${type.inner ? this.enhancedTypeToMotokoString(type.inner, defs) : 'Blob'}]`;
      case 'opt':
        return `?${type.inner ? this.enhancedTypeToMotokoString(type.inner, defs) : 'Blob'}`;
      case 'custom':
        if (type.name && this.isValidTypeName(type.name)) {
          return type.name;
        }
        return 'Blob';
      case 'record': {
        const name = this.resolveNominalTypeName(type, defs);
        return name || this.convertCandidTypeToMotoko(type, defs);
      }
      case 'variant': {
        const name = this.resolveNominalTypeName(type, defs);
        return name || this.convertCandidTypeToMotoko(type, defs);
      }
      case 'tuple':
        if (type.tupleTypes && type.tupleTypes.length > 0) {
          const types = type.tupleTypes.map(t => this.enhancedTypeToMotokoString(t, defs));
          return `(${types.join(', ')})`;
        }
        return '()';
      default:
        return 'Blob';
    }
  }

  /**
   * Check if a type name is a known custom type that should be available
   */
  private isKnownCustomType(typeName: string): boolean {
  // Known types are exactly those present in the parsed definitions; callers gate via typeDefinitions
  return true;
  }

  /**
   * Try to resolve an inline record/variant/tuple to a nominal typedef name
   */
  private resolveNominalTypeName(type: CandidType, typeDefinitions: Map<string, CandidType>): string | null {
    for (const [name, def] of typeDefinitions.entries()) {
      if (this.equalsCandidTypes(type, def) && this.isValidTypeName(name)) {
        return name;
      }
    }
    return null;
  }

  /**
   * Structural equality for CandidType trees
   */
  private equalsCandidTypes(a: CandidType, b: CandidType): boolean {
    if (a.kind !== b.kind) return false;
    switch (a.kind) {
      case 'text':
      case 'nat':
      case 'int':
      case 'bool':
      case 'blob':
      case 'principal':
      case 'null':
        return true;
      case 'custom':
        return a.name === b.name;
      case 'vec':
        return (!!a.inner) === (!!b.inner) && (!a.inner || this.equalsCandidTypes(a.inner as CandidType, (b as any).inner));
      case 'opt':
        return (!!a.inner) === (!!b.inner) && (!a.inner || this.equalsCandidTypes(a.inner as CandidType, (b as any).inner));
      case 'tuple':
        if (!a.tupleTypes || !(b as any).tupleTypes || a.tupleTypes.length !== (b as any).tupleTypes.length) return false;
        for (let i = 0; i < a.tupleTypes.length; i++) {
          if (!this.equalsCandidTypes(a.tupleTypes[i], (b as any).tupleTypes[i])) return false;
        }
        return true;
      case 'record':
        if (!a.fields || !(b as any).fields || a.fields.length !== (b as any).fields.length) return false;
        for (let i = 0; i < a.fields.length; i++) {
          const fa = a.fields[i]!;
          const fb = (b as any).fields[i]!;
          if ((fa.name || '') !== (fb.name || '')) return false;
          if (!this.equalsCandidTypes(fa.type, fb.type)) return false;
        }
        return true;
      case 'variant':
        if (!a.options || !(b as any).options || a.options.length !== (b as any).options.length) return false;
        for (let i = 0; i < a.options.length; i++) {
          const oa = a.options[i]!;
          const ob = (b as any).options[i]!;
          if (oa.name !== ob.name) return false;
          const at = oa.type as CandidType | undefined;
          const bt = ob.type as CandidType | undefined;
          if (!!at !== !!bt) return false;
          if (at && bt && !this.equalsCandidTypes(at, bt)) return false;
        }
        return true;
      default:
        return false;
    }
  }

  /**
   * Generate accessor functions for ErasedValidator pattern with enhanced type support
   */
  private generateErasedValidatorAccessors(service: CandidService): string {
    const parts: string[] = [];
    
    parts.push('  /// Accessor functions for ErasedValidator pattern');
    parts.push('  /// For complex types, use the delegated accessor functions below');
    parts.push('');
    parts.push('  /// Unit accessor for methods with no parameters');
    parts.push('  public func unit_accessor(args: Args): () { () };');
    parts.push('');
    
    for (const method of service.methods) {
      if (method.parameters.length === 0) continue;
      
      // Preserve original method name case
      const methodName = method.name;
      
      for (let i = 0; i < method.parameters.length; i++) {
  const param = method.parameters[i];
  const paramType = this.inferParameterType(param, method.name, service.typeDefinitions || new Map());
        const paramName = param.name || `param${i}`;
        // Convert method name to camelCase and combine with parameter name
        const cleanMethodName = this.toCamelCase(method.name);
        const cleanParamName = this.capitalize(paramName);
        const accessorName = `get${this.capitalize(cleanMethodName)}${cleanParamName}`;
        const defaultValue = this.getDefaultValueForType(paramType);
        
        if (method.parameters.length === 1) {
          parts.push(`  public func ${accessorName}(args: Args): ${paramType} {`);
          parts.push(`    switch (args) {`);
          parts.push(`      case (#${methodName}(value)) value(); // Call the function to get the actual value`);
          parts.push(`      case (_) ${defaultValue};`);
          parts.push(`    };`);
          parts.push(`  };`);
          
          // Generate identity function for primitive types
          if (this.isPrimitiveType(paramType)) {
            parts.push('');
            parts.push(`  /// Identity function for ${paramType} validation`);
            parts.push(`  public func ${accessorName}_identity(value: ${paramType}): ${paramType} { value };`);
          }
          
        } else {
          parts.push(`  public func ${accessorName}(args: Args): ${paramType} {`);
          parts.push(`    switch (args) {`);
          parts.push(`      case (#${methodName}(params)) params().${i}; // Call the function to get the tuple, then select index ${i}`);
          parts.push(`      case (_) ${defaultValue};`);
          parts.push(`    };`);
          parts.push(`  };`);
        }
        parts.push('');
      }
    }
    
    return parts.join('\n');
  }

  /**
   * Generate ErasedValidator initialization template
   */
  private generateErasedValidatorTemplate(service: CandidService): string {
    const parts: string[] = [];
    
    parts.push('  /// ErasedValidator initialization template');
    parts.push('  public func createValidatorInspector() : InspectMo.InspectMo {');
    parts.push('    let inspector = InspectMo.InspectMo(');
    parts.push('      {');
    parts.push('        supportAudit = false;');
    parts.push('        supportTimer = false;');
    parts.push('        supportAdvanced = false;');
    parts.push('      },');
    parts.push('      func(state: InspectMo.State) {}');
    parts.push('    );');
    parts.push('');
    parts.push('    // Setup validation rules using ErasedValidator pattern');
    
    for (const method of service.methods) {
      // Preserve original method name case  
      const methodName = method.name;
      // Use the actual method return type from Candid interface
      const returnType = method.returnType ? this.typeToMotokoString(method.returnType) : '()';
      
      parts.push(`    // ${method.name} validation`);
      parts.push(`    inspector.inspect(inspector.createMethodGuardInfo<${returnType}>(`);
      parts.push(`      "${method.name}",`);
      parts.push(`      ${method.isQuery ? 'true' : 'false'}, // isQuery`);
      parts.push(`      [`);
      parts.push(`        #requireAuth // Add your validation rules here`);
      parts.push(`      ],`);
      parts.push(`      func(args: Args): ${returnType} {`);
      parts.push(`        switch (args) {`);
      parts.push(`          case (#${methodName}(params)) {`);
      
      if (method.parameters.length === 0) {
        // No parameters to extract
        if (returnType === '()') {
          parts.push(`            // No parameters to process`);
          parts.push(`            ()`);
        } else {
          parts.push(`            // No parameters - add your return logic here`);
          parts.push(`            Runtime.trap("Implement return logic for ${method.name}")`);
        }
      } else if (method.parameters.length === 1) {
        // Single parameter
        parts.push(`            // Extract single parameter: ${method.parameters[0].name || 'param'}`);
        parts.push(`            let param = params();`);
        if (returnType === '()') {
          parts.push(`            // Add your validation/processing logic here`);
          parts.push(`            ()`);
        } else {
          parts.push(`            // Add your processing logic here`);
          parts.push(`            Runtime.trap("Implement processing logic for ${method.name}")`);
        }
      } else {
        // Multiple parameters  
        parts.push(`            // Extract multiple parameters`);
        for (let i = 0; i < method.parameters.length; i++) {
          const param = method.parameters[i];
          parts.push(`            let ${param.name || `param${i}`} = params().${i};`);
        }
        if (returnType === '()') {
          parts.push(`            // Add your validation/processing logic here`);
          parts.push(`            ()`);
        } else {
          parts.push(`            // Add your processing logic here`);
          parts.push(`            Runtime.trap("Implement processing logic for ${method.name}")`);
        }
      }
      
      parts.push(`          };`);
      parts.push(`          case (_) {`);
      if (returnType === '()') {
        parts.push(`            // Default fallback`);
        parts.push(`            ()`);
      } else {
        parts.push(`            // Default fallback - provide appropriate default`);
        parts.push(`            Runtime.trap("Invalid args type for ${method.name}")`);
      }
      parts.push(`          };`);
      parts.push(`        };`);
      parts.push(`      }`);
      parts.push(`    ));`);
      parts.push('');
    }
    
    parts.push('    inspector');
    parts.push('  };');
    
    return parts.join('\n');
  }

  /**
   * Generate system inspect function template
   */
  private generateSystemInspectTemplate(service: CandidService): string {
    const parts: string[] = [];
    
    parts.push('  /// System inspect function template for ErasedValidator pattern');
    parts.push('  /// Copy this code into your canister and customize as needed');
    parts.push('  /*');
    parts.push('  system func inspect({');
    parts.push('    arg : Blob;');
    parts.push('    caller : Principal;');
    parts.push('    msg : {');
    
    for (const method of service.methods) {
      if (method.parameters.length === 0) {
        parts.push(`      #${method.name} : ();`);
      } else if (method.parameters.length === 1) {
        const paramType = this.enhancedTypeToMotokoString(method.parameters[0].type, service.typeDefinitions || new Map());
        parts.push(`      #${method.name} : (${paramType});`);
      } else {
        const paramTypes = method.parameters
          .map(p => this.enhancedTypeToMotokoString(p.type, service.typeDefinitions || new Map()))
          .join(', ');
        parts.push(`      #${method.name} : (${paramTypes});`);
      }
    }
    
    parts.push('    }');
    parts.push('  }) : Bool {');
    parts.push('    let (methodName, isQuery, msgArgs) = switch (msg) {');
    
    for (const method of service.methods) {
      // Preserve original method name case  
      const methodName = method.name;
      if (method.parameters.length === 0) {
        parts.push(`      case (#${method.name} _) ("${method.name}", ${method.isQuery}, #${methodName}(()));`);
      } else if (method.parameters.length === 1) {
        parts.push(`      case (#${method.name} params) ("${method.name}", ${method.isQuery}, #${methodName}(params));`);
      } else {
        parts.push(`      case (#${method.name} params) ("${method.name}", ${method.isQuery}, #${methodName}(params));`);
      }
    }
    
    // Default case - use first method with empty params as fallback
    let firstMethod = service.methods[0];
    if (firstMethod) {
      parts.push(`      case (_) ("unknown_method", false, #${firstMethod.name}(${firstMethod.parameters.length === 0 ? '' : firstMethod.parameters.map(_ => 'Runtime.trap("Unknown method")').join(', ')}));`);
    } else {
      parts.push('      case (_) Runtime.trap("No methods defined");');
    }
    parts.push('    };');
    parts.push('    ');
    parts.push('    let inspectArgs : InspectMo.InspectArgs<Args> = {');
    parts.push('      methodName = methodName;');
    parts.push('      caller = caller;');
    parts.push('      arg = arg;');
    parts.push('      msg = msgArgs;');
    parts.push('      isQuery = isQuery;');
    parts.push('      isInspect = true;');
    parts.push('      cycles = ?0;');
    parts.push('      deadline = null;');
    parts.push('    };');
    parts.push('    ');
    parts.push('    let result = validatorInspector.inspectCheck(inspectArgs);');
    parts.push('    switch (result) {');
    parts.push('      case (#ok) { true };');
    parts.push('      case (#err(_)) { false };');
    parts.push('    }');
    parts.push('  };');
    parts.push('  */');
    
    return parts.join('\n');
  }

  /**
   * Get default value for a Motoko type (enhanced for complex types)
   */
  private getDefaultValueForType(motokoType: string): string {
    // Handle types with comments
    const cleanType = motokoType.split('/*')[0].trim();
    
    switch (cleanType.toLowerCase()) {
      case 'text': return '""';
      case 'nat': return '0';
      case 'nat8': return '0';
      case 'nat16': return '0';
      case 'nat32': return '0';
      case 'nat64': return '0';
      case 'int': return '0';
      case 'int8': return '0';
      case 'int16': return '0';
      case 'int32': return '0';
      case 'int64': return '0';
      case 'bool': return 'false';
      case 'float': return '0.0';
      case 'blob': return '""';
      case 'principal': return 'Principal.fromText("2vxsx-fae")';
      case 'userrecord':
      case 'uservariant':
      case 'any':
        return 'Runtime.trap("Define default value and type for: ' + cleanType + '")';
      default:
        if (cleanType.startsWith('?')) {
          return 'null';
        } else if (cleanType.startsWith('[')) {
          return '[]';
        } else {
          return 'Runtime.trap("Define default value and type for: ' + cleanType + '")';
        }
    }
  }

  /**
   * Generate accessor function name for a method parameter
   */
  private generateAccessorName(methodName: string, paramName: string): string {
    const cleanMethodName = this.toCamelCase(methodName);
    const cleanParamName = this.capitalize(paramName);
    return `get${this.capitalize(cleanMethodName)}${cleanParamName}`;
  }

  /**
   * Capitalize first letter of string
   */
  private capitalize(str: string): string {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

  /**
   * Check if a type is a primitive Motoko type that can have identity functions
   */
  private isPrimitiveType(typeName: string): boolean {
    const primitives = ['Nat', 'Int', 'Text', 'Bool', 'Blob', 'Principal'];
    return primitives.includes(typeName);
  }

  private toCamelCase(str: string): string {
    return str.replace(/_([a-z])/g, (match, letter) => letter.toUpperCase());
  }
}
