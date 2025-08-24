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

export class MotokoCodeGenerator {

  /**
   * Generate complete InspectMo boilerplate for a service using ErasedValidator pattern
   */
  public generateBoilerplate(context: GenerationContext): string {
    const { service, options } = context;
    const parts: string[] = [];

    // Header and imports - updated for ErasedValidator pattern
    parts.push(this.generateHeader());
    parts.push('');
    parts.push('module {');
    parts.push('');

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

    // ErasedValidator initialization template
    if (options.generateInspectTemplate) {
      parts.push(this.generateErasedValidatorTemplate(service));
      parts.push('');
    }

    // System inspect function template
    if (options.generateGuardTemplate) {
      parts.push(this.generateSystemInspectTemplate(service));
      parts.push('');
    }

    parts.push('}'); // Close module

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
  private generateHeader(): string {
    return `/// Auto-generated InspectMo integration module using ErasedValidator pattern
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

import InspectMo "mo:inspect-mo/lib";
import Principal "mo:core/Principal";
import Result "mo:core/Result";
import Debug "mo:core/Debug";`;
  }

  /**
   * Generate type-safe accessor functions for each parameter type
   */
  private generateAccessorFunctions(service: CandidService): string {
    const accessors = new Set<string>();
    const parts: string[] = ['  /// Type-safe accessor functions'];

    for (const method of service.methods) {
      for (const param of method.parameters) {
        const accessor = this.generateAccessorForType(param.type, param.name || undefined);
        if (accessor && !accessors.has(accessor)) {
          accessors.add(accessor);
          parts.push(`  ${accessor}`); // Add module indentation
        }
      }
    }

    return parts.join('\n');
  }

  /**
   * Generate accessor function for a specific type
   */
  private generateAccessorForType(type: CandidType, paramName?: string): string | null {
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
      
      // For complex types, generate generic accessor
      case 'record':
      case 'variant':
      case 'vec':
      case 'opt':
        return `// TODO: Implement accessor for ${type.kind} type`;
      
      default:
        return null;
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
      const paramTypes = method.parameters.map(p => this.typeToMotokoString(p.type)).join(', ');
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
      const argsType = this.generateMethodArgsType(method);
      
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
  private generateMethodArgsType(method: CandidMethod): string {
    if (method.parameters.length === 0) {
      return '()';
    }
    
    if (method.parameters.length === 1) {
      return this.typeToMotokoString(method.parameters[0].type);
    }
    
    // Multiple parameters - create a tuple
    const paramTypes = method.parameters.map(p => this.typeToMotokoString(p.type));
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
   * Convert Candid type to Motoko type string
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
        return `[${type.inner ? this.typeToMotokoString(type.inner) : 'Any'}]`;
      case 'opt':
        return `?${type.inner ? this.typeToMotokoString(type.inner) : 'Any'}`;
      case 'record':
        return 'Record'; // Simplified
      case 'variant':
        return 'Variant'; // Simplified
      case 'custom':
        return type.name || 'CustomType'; // Use the custom type name
      default:
        return 'Any';
    }
  }

  /**
   * Generate Args union type for ErasedValidator pattern
   */
  private generateArgsUnionType(service: CandidService): string {
    const parts: string[] = [];
    
    parts.push('  /// Args union type for ErasedValidator pattern');
    parts.push('  public type Args = {');
    
    for (const method of service.methods) {
      const methodName = this.capitalize(method.name);
      const argTypes = method.parameters.map(p => this.typeToMotokoString(p.type)).join(', ');
      const argsType = method.parameters.length > 1 ? `(${argTypes})` : argTypes || '()';
      parts.push(`    #${methodName}: ${argsType};`);
    }
    
    parts.push('    #None: ();');
    parts.push('  };');
    
    return parts.join('\n');
  }

  /**
   * Generate accessor functions for ErasedValidator pattern
   */
  private generateErasedValidatorAccessors(service: CandidService): string {
    const parts: string[] = [];
    
    parts.push('  /// Accessor functions for ErasedValidator pattern');
    
    for (const method of service.methods) {
      if (method.parameters.length === 0) continue;
      
      const methodName = this.capitalize(method.name);
      
      for (let i = 0; i < method.parameters.length; i++) {
        const param = method.parameters[i];
        const paramType = this.typeToMotokoString(param.type);
        const accessorName = `get${methodName}${this.capitalize(param.name || `Param${i}`)}`;
        const defaultValue = this.getDefaultValueForType(paramType);
        
        if (method.parameters.length === 1) {
          parts.push(`  public func ${accessorName}(args: Args): ${paramType} {`);
          parts.push(`    switch (args) {`);
          parts.push(`      case (#${methodName}(value)) value;`);
          parts.push(`      case (_) ${defaultValue};`);
          parts.push(`    };`);
          parts.push(`  };`);
        } else {
          parts.push(`  public func ${accessorName}(args: Args): ${paramType} {`);
          parts.push(`    switch (args) {`);
          parts.push(`      case (#${methodName}(params)) params.${i};`);
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
      const methodName = this.capitalize(method.name);
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
          parts.push(`            Debug.trap("Implement return logic for ${method.name}")`);
        }
      } else if (method.parameters.length === 1) {
        // Single parameter
        parts.push(`            // Extract single parameter: ${method.parameters[0].name || 'param'}`);
        parts.push(`            let param = params;`);
        if (returnType === '()') {
          parts.push(`            // Add your validation/processing logic here`);
          parts.push(`            ()`);
        } else {
          parts.push(`            // Add your processing logic here`);
          parts.push(`            Debug.trap("Implement processing logic for ${method.name}")`);
        }
      } else {
        // Multiple parameters  
        parts.push(`            // Extract multiple parameters`);
        for (let i = 0; i < method.parameters.length; i++) {
          const param = method.parameters[i];
          parts.push(`            let ${param.name || `param${i}`} = params.${i};`);
        }
        if (returnType === '()') {
          parts.push(`            // Add your validation/processing logic here`);
          parts.push(`            ()`);
        } else {
          parts.push(`            // Add your processing logic here`);
          parts.push(`            Debug.trap("Implement processing logic for ${method.name}")`);
        }
      }
      
      parts.push(`          };`);
      parts.push(`          case (_) {`);
      if (returnType === '()') {
        parts.push(`            // Default fallback`);
        parts.push(`            ()`);
      } else {
        parts.push(`            // Default fallback - provide appropriate default`);
        parts.push(`            Debug.trap("Invalid args type for ${method.name}")`);
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
    parts.push('  public func generateSystemInspect() : Text {');
    parts.push('    let template = ```');
    parts.push('  system func inspect({');
    parts.push('    arg : Blob;');
    parts.push('    caller : Principal;');
    parts.push('    msg : {');
    
    for (const method of service.methods) {
      if (method.parameters.length === 0) {
        parts.push(`      #${method.name} : ();`);
      } else if (method.parameters.length === 1) {
        const paramType = this.typeToMotokoString(method.parameters[0].type);
        parts.push(`      #${method.name} : (${paramType});`);
      } else {
        const paramTypes = method.parameters.map(p => this.typeToMotokoString(p.type)).join(', ');
        parts.push(`      #${method.name} : (${paramTypes});`);
      }
    }
    
    parts.push('    }');
    parts.push('  }) : Bool {');
    parts.push('    let (methodName, isQuery, msgArgs) = switch (msg) {');
    
    for (const method of service.methods) {
      const methodName = this.capitalize(method.name);
      if (method.parameters.length === 0) {
        parts.push(`      case (#${method.name} _) ("${method.name}", ${method.isQuery}, #${methodName}(()));`);
      } else if (method.parameters.length === 1) {
        parts.push(`      case (#${method.name} params) ("${method.name}", ${method.isQuery}, #${methodName}(params));`);
      } else {
        parts.push(`      case (#${method.name} params) ("${method.name}", ${method.isQuery}, #${methodName}(params));`);
      }
    }
    
    parts.push('      case (_) ("unknown_method", false, #None(()));');
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
    parts.push('    ```;');
    parts.push('    template');
    parts.push('  };');
    
    return parts.join('\n');
  }

  /**
   * Get default value for a Motoko type
   */
  private getDefaultValueForType(motokoType: string): string {
    switch (motokoType.toLowerCase()) {
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
      default:
        if (motokoType.startsWith('?')) {
          return 'null';
        } else if (motokoType.startsWith('[')) {
          return '[]';
        } else {
          return `Debug.trap("No default value for type: ${motokoType}")`;
        }
    }
  }

  /**
   * Capitalize first letter of string
   */
  private capitalize(str: string): string {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }
}
