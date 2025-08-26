/**
 * Enhanced source code analyzer for auto-discovery and InspectMo usage detection
 */

import * as fs from 'fs';
import * as path from 'path';
import * as glob from 'glob';
import { 
  ProjectAnalysis, 
  InspectMoUsage, 
  AutoDiscoveryOptions, 
  IntegrationSuggestion 
} from './types';

// Internal interface for file analysis
interface InternalInspectMoUsage {
  file: string;
  line: number;
  type: 'inspect' | 'guard';
  method?: string;
  rules: string[];
  raw: string;
}

export interface AnalysisResult {
  inspectCalls: InternalInspectMoUsage[];
  guardCalls: InternalInspectMoUsage[];
  suggestions: string[];
}

export class SourceAnalyzer {
  
  /**
   * Auto-discover project structure and generate integration recommendations
   */
  public analyzeProject(projectRoot: string, options?: Partial<AutoDiscoveryOptions>): ProjectAnalysis {
    // First, check for dfx.json to get defined canisters
    const dfxCanisters = this.getDfxCanisters(projectRoot);
    
    const defaultOptions: AutoDiscoveryOptions = {
      projectRoot,
      includePatterns: this.buildIncludePatterns(projectRoot, dfxCanisters),
      excludePatterns: [
        'node_modules/**', 
        '.git/**', 
        'build/**',
        '.mops/**',
        '.vessel/**',
        'dist/**',
        'target/**',
        '.dfx/local/lsp/**',  // Exclude LSP files which are temporary
        '.dfx/local/canisters/*/constructor.did'  // Usually not needed for validation
      ],
      scanMotokoFiles: true,
      generateMissingTypes: true
    };
    
    const finalOptions = { ...defaultOptions, ...options };
    
    // Auto-discover .did files
    const didFiles = this.findDidFiles(finalOptions);
    
    // Scan Motoko files for InspectMo usage
    const motokoFiles = this.findMotokoFiles(projectRoot);
    const inspectMoUsage = this.analyzeInspectMoUsage(motokoFiles);
    
    // Detect missing types by analyzing .did files
    const missingTypes = this.detectMissingTypes(didFiles);
    
    // Generate integration suggestions
    const suggestions = this.generateIntegrationSuggestions(projectRoot, didFiles, inspectMoUsage);
    
    return {
      didFiles,
      motokoFiles,
      inspectMoUsage,
      missingTypes,
      suggestedIntegrations: suggestions
    };
  }

  /**
   * Find all .did files in the project using glob patterns
   */
  public findDidFiles(options: AutoDiscoveryOptions): string[] {
    const didFiles: string[] = [];
    
    // Check if we have src/declarations - if so, be more restrictive
    const declarationsPath = path.join(options.projectRoot, 'src/declarations');
    const hasDeclarations = fs.existsSync(declarationsPath);
    
    for (const pattern of options.includePatterns) {
      const fullPattern = path.join(options.projectRoot, pattern);
      try {
        const matches = glob.sync(fullPattern, {
          ignore: options.excludePatterns.map(p => 
            p.startsWith('**') || p.includes('*') ? p : path.join(options.projectRoot, p)
          )
        });
        didFiles.push(...matches);
      } catch (error) {
        console.warn(`Warning: Failed to search pattern ${pattern}:`, error);
      }
    }
    
    // Filtering logic - more restrictive if we have declarations
    const filtered = didFiles.filter(file => {
      const relativePath = path.relative(options.projectRoot, file);
      
      // Always exclude these directories
      if (relativePath.includes('.mops/') ||
          relativePath.includes('.vessel/') ||
          relativePath.includes('node_modules/') ||
          relativePath.includes('build/') ||
          relativePath.includes('dist/') ||
          relativePath.includes('target/')) {
        return false;
      }
      
      // If we have src/declarations, be very restrictive about other sources
      if (hasDeclarations) {
        // Only allow src/declarations and explicit did/ folder
        return relativePath.startsWith('src/declarations/') || 
               relativePath.startsWith('did/') ||
               relativePath.startsWith('tools/codegen/'); // Allow codegen test files
      }
      
      // For .dfx files, be selective (fallback when no declarations)
      if (relativePath.includes('.dfx/')) {
        // Exclude LSP temporary files
        if (relativePath.includes('.dfx/local/lsp/')) {
          return false;
        }
        // Exclude constructor files (usually not needed for validation)
        if (relativePath.includes('constructor.did')) {
          return false;
        }
        // Keep canister service files and main canister files
        return relativePath.includes('.dfx/local/canisters/') &&
               (relativePath.endsWith('service.did') || 
                relativePath.match(/\.dfx\/local\/canisters\/[^/]+\/[^/]+\.did$/));
      }
      
      return true;
    });
    
    // Remove duplicates and ensure absolute paths
    return [...new Set(filtered)].map(f => path.resolve(f));
  }

  /**
   * Analyze InspectMo usage across multiple files
   */
  public analyzeInspectMoUsage(motokoFiles: string[]): InspectMoUsage[] {
    const usage: InspectMoUsage[] = [];
    
    for (const file of motokoFiles) {
      const fileAnalysis = this.analyzeFile(file);
      
      // Convert to InspectMoUsage format
      fileAnalysis.inspectCalls.forEach(call => {
        usage.push({
          filePath: call.file,
          lineNumber: call.line,
          methodName: call.method || 'unknown',
          usageType: 'inspect',
          complexity: this.determineComplexity(call.rules)
        });
      });
      
      fileAnalysis.guardCalls.forEach(call => {
        usage.push({
          filePath: call.file,
          lineNumber: call.line,
          methodName: call.method || 'unknown',
          usageType: 'guard',
          complexity: this.determineComplexity(call.rules)
        });
      });
    }
    
    return usage;
  }

  /**
   * Detect missing types by parsing .did files and checking for undefined references
   */
  public detectMissingTypes(didFiles: string[]): string[] {
    const missingTypes: string[] = [];
    
    for (const didFile of didFiles) {
      try {
        const content = fs.readFileSync(didFile, 'utf-8');
        
        // Find type references that might be missing
        const typeReferences = this.extractTypeReferences(content);
        const definedTypes = this.extractDefinedTypes(content);
        
        for (const typeRef of typeReferences) {
          if (!definedTypes.includes(typeRef) && !this.isBuiltinType(typeRef)) {
            missingTypes.push(typeRef);
          }
        }
      } catch (error) {
        console.warn(`Warning: Failed to analyze ${didFile}:`, error);
      }
    }
    
    return [...new Set(missingTypes)];
  }

  /**
   * Generate integration suggestions based on project analysis
   */
  public generateIntegrationSuggestions(
    projectRoot: string, 
    didFiles: string[], 
    inspectMoUsage: InspectMoUsage[]
  ): IntegrationSuggestion[] {
    const suggestions: IntegrationSuggestion[] = [];
    
    // Check for build system integration opportunities
    const mopsPath = path.join(projectRoot, 'mops.toml');
    const dfxPath = path.join(projectRoot, 'dfx.json');
    
    if (fs.existsSync(mopsPath)) {
      suggestions.push({
        type: 'build-hook',
        description: 'Add pre-build hook to mops.toml for automatic code generation',
        implementation: this.generateMopsBuildHook(didFiles),
        priority: 'high'
      });
    }
    
    if (fs.existsSync(dfxPath)) {
      suggestions.push({
        type: 'build-hook',
        description: 'Add prebuild script to dfx.json for automatic code generation',
        implementation: this.generateDfxBuildHook(didFiles),
        priority: 'high'
      });
    }
    
    // Auto-generation suggestions
    if (didFiles.length > 0) {
      suggestions.push({
        type: 'auto-generation',
        description: `Auto-generate InspectMo boilerplate from ${didFiles.length} .did file(s)`,
        implementation: this.generateAutoGenerationCommand(didFiles),
        priority: 'high'
      });
    }
    
    // Missing types suggestions
    if (inspectMoUsage.length === 0 && didFiles.length > 0) {
      suggestions.push({
        type: 'missing-types',
        description: 'No InspectMo usage detected - consider adding validation to your methods',
        implementation: 'npx inspect-mo-generate --analyze --suggest',
        priority: 'medium'
      });
    }
    
    return suggestions;
  }
  
  /**
   * Analyze a directory for existing InspectMo usage
   */
  public analyzeDirectory(dirPath: string): AnalysisResult {
    const result: AnalysisResult = {
      inspectCalls: [],
      guardCalls: [],
      suggestions: []
    };

    const motokoFiles = this.findMotokoFiles(dirPath);
    
    for (const file of motokoFiles) {
      const fileAnalysis = this.analyzeFile(file);
      result.inspectCalls.push(...fileAnalysis.inspectCalls);
      result.guardCalls.push(...fileAnalysis.guardCalls);
    }

    // Generate suggestions based on findings
    result.suggestions = this.generateSuggestions(result);

    return result;
  }

  /**
   * Analyze a single Motoko file for InspectMo usage
   */
  public analyzeFile(filePath: string): AnalysisResult {
    const result: AnalysisResult = {
      inspectCalls: [],
      guardCalls: [],
      suggestions: []
    };

    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      const lines = content.split('\n');

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const lineNum = i + 1;

        // Look for InspectMo.inspect() calls
        const inspectMatch = this.matchInspectCall(line);
        if (inspectMatch) {
          result.inspectCalls.push({
            file: filePath,
            line: lineNum,
            type: 'inspect',
            method: inspectMatch.method,
            rules: inspectMatch.rules,
            raw: line.trim()
          });
        }

        // Look for InspectMo.guard() calls
        const guardMatch = this.matchGuardCall(line);
        if (guardMatch) {
          result.guardCalls.push({
            file: filePath,
            line: lineNum,
            type: 'guard',
            method: guardMatch.method,
            rules: guardMatch.rules,
            raw: line.trim()
          });
        }

        // Look for inspector.guardCheck() calls
        const guardCheckMatch = this.matchGuardCheckCall(line);
        if (guardCheckMatch) {
          result.guardCalls.push({
            file: filePath,
            line: lineNum,
            type: 'guard',
            method: guardCheckMatch.method,
            rules: ['guardCheck'],
            raw: line.trim()
          });
        }
      }
    } catch (error) {
      console.error(`Error analyzing file ${filePath}:`, error);
    }

    return result;
  }

  /**
   * Find all .mo files in a directory recursively
   */
  private findMotokoFiles(dirPath: string): string[] {
    const files: string[] = [];
    
    if (!fs.existsSync(dirPath)) {
      return files;
    }

    const entries = fs.readdirSync(dirPath, { withFileTypes: true });
    
    for (const entry of entries) {
      const fullPath = path.join(dirPath, entry.name);
      
      if (entry.isDirectory()) {
        // Skip node_modules and .dfx directories
        if (!['node_modules', '.dfx', '.vessel', 'build'].includes(entry.name)) {
          files.push(...this.findMotokoFiles(fullPath));
        }
      } else if (entry.isFile() && entry.name.endsWith('.mo')) {
        files.push(fullPath);
      }
    }

    return files;
  }

  /**
   * Get canister names from dfx.json
   */
  private getDfxCanisters(projectRoot: string): string[] {
    const dfxPath = path.join(projectRoot, 'dfx.json');
    
    if (!fs.existsSync(dfxPath)) {
      return [];
    }
    
    try {
      const dfxContent = fs.readFileSync(dfxPath, 'utf-8');
      const dfxConfig = JSON.parse(dfxContent);
      
      if (dfxConfig.canisters && typeof dfxConfig.canisters === 'object') {
        return Object.keys(dfxConfig.canisters);
      }
    } catch (error) {
      console.warn(`Warning: Failed to parse dfx.json:`, error);
    }
    
    return [];
  }

  /**
   * Build include patterns based on project structure and dfx canisters
   */
  private buildIncludePatterns(projectRoot: string, dfxCanisters: string[]): string[] {
    // Check if src/declarations exists (created by dfx generate)
    const declarationsPath = path.join(projectRoot, 'src/declarations');
    
    if (fs.existsSync(declarationsPath)) {
      // If declarations exist, prioritize them as they're the canonical source
      console.log('📁 Found src/declarations - using as primary source for .did files');
      return [
        'src/declarations/**/*.did',  // Primary source after dfx generate
        'did/**/*.did'  // Also check explicit did folder if it exists
      ];
    }
    
    // Fallback to broader search if no declarations directory
    const patterns = [
      '**/*.did',  // Base pattern for all .did files
      'did/**/*.did'  // Common did folder
    ];
    
    // Add specific dfx canister patterns as fallback
    for (const canister of dfxCanisters) {
      patterns.push(`.dfx/local/canisters/${canister}/${canister}.did`);
      patterns.push(`.dfx/local/canisters/${canister}/service.did`);
    }
    
    return patterns;
  }

  /**
   * Match InspectMo.inspect() calls with patterns like:
   * inspector.inspect("method_name", [rule1, rule2])
   * InspectMo.inspect("method_name", [rule1, rule2])
   */
  private matchInspectCall(line: string): { method?: string; rules: string[] } | null {
    // Pattern for inspector.inspect or InspectMo.inspect calls
    const patterns = [
      /(?:inspector|InspectMo)\.inspect\s*\(\s*"([^"]+)"\s*,\s*\[(.*?)\]/,
      /(?:inspector|InspectMo)\.inspect\s*\(\s*"([^"]+)"\s*,\s*([^)]+)\)/,
      /\.inspect\s*\(\s*"([^"]+)"/
    ];

    for (const pattern of patterns) {
      const match = line.match(pattern);
      if (match) {
        const method = match[1];
        const rulesStr = match[2] || '';
        const rules = this.parseRules(rulesStr);
        return { method, rules };
      }
    }

    return null;
  }

  /**
   * Match InspectMo.guard() calls with patterns like:
   * inspector.guard("method_name", [rule1, rule2])
   * InspectMo.guard("method_name", [rule1, rule2])
   */
  private matchGuardCall(line: string): { method?: string; rules: string[] } | null {
    // Pattern for inspector.guard or InspectMo.guard calls
    const patterns = [
      /(?:inspector|InspectMo)\.guard\s*\(\s*"([^"]+)"\s*,\s*\[(.*?)\]/,
      /(?:inspector|InspectMo)\.guard\s*\(\s*"([^"]+)"\s*,\s*([^)]+)\)/,
      /\.guard\s*\(\s*"([^"]+)"/
    ];

    for (const pattern of patterns) {
      const match = line.match(pattern);
      if (match) {
        const method = match[1];
        const rulesStr = match[2] || '';
        const rules = this.parseRules(rulesStr);
        return { method, rules };
      }
    }

    return null;
  }

  /**
   * Match inspector.guardCheck() calls
   */
  private matchGuardCheckCall(line: string): { method?: string; rules: string[] } | null {
    const pattern = /inspector\.guardCheck\s*\(/;
    
    if (pattern.test(line)) {
      return { rules: ['guardCheck'] };
    }

    return null;
  }

  /**
   * Parse validation rules from a string
   */
  private parseRules(rulesStr: string): string[] {
    if (!rulesStr.trim()) {
      return [];
    }

    // Split by comma and clean up
    return rulesStr
      .split(',')
      .map(rule => rule.trim())
      .filter(rule => rule.length > 0)
      .map(rule => {
        // Extract rule names from function calls
        const match = rule.match(/(\w+)\s*\(/);
        return match ? match[1] : rule;
      });
  }

  /**
   * Generate suggestions based on analysis results
   */
  private generateSuggestions(result: AnalysisResult): string[] {
    const suggestions: string[] = [];

    if (result.inspectCalls.length === 0 && result.guardCalls.length === 0) {
      suggestions.push('No existing InspectMo usage found. Consider adding boundary validation with inspect() calls.');
    }

    if (result.inspectCalls.length > 0 && result.guardCalls.length === 0) {
      suggestions.push('Found inspect() calls but no guard() calls. Consider adding runtime validation.');
    }

    if (result.guardCalls.length > 0 && result.inspectCalls.length === 0) {
      suggestions.push('Found guard() calls but no inspect() calls. Consider adding boundary validation.');
    }

    // Analyze common patterns
    const allRules = [
      ...result.inspectCalls.flatMap(call => call.rules),
      ...result.guardCalls.flatMap(call => call.rules)
    ];

    const ruleFrequency = this.countRuleFrequency(allRules);
    
    if (ruleFrequency.textSize === 0 && (ruleFrequency.total > 0)) {
      suggestions.push('Consider adding textSize validation for text parameters.');
    }

    if (ruleFrequency.requireAuth === 0 && (ruleFrequency.total > 0)) {
      suggestions.push('Consider adding authentication requirements for sensitive methods.');
    }

    return suggestions;
  }

  /**
   * Count frequency of different rule types
   */
  private countRuleFrequency(rules: string[]): Record<string, number> {
    const frequency: Record<string, number> = {
      textSize: 0,
      blobSize: 0,
      natValue: 0,
      intValue: 0,
      requireAuth: 0,
      requirePermission: 0,
      total: rules.length
    };

    for (const rule of rules) {
      if (rule.includes('textSize') || rule.includes('text')) {
        frequency.textSize++;
      }
      if (rule.includes('blobSize') || rule.includes('blob')) {
        frequency.blobSize++;
      }
      if (rule.includes('natValue') || rule.includes('nat')) {
        frequency.natValue++;
      }
      if (rule.includes('intValue') || rule.includes('int')) {
        frequency.intValue++;
      }
      if (rule.includes('requireAuth') || rule.includes('auth')) {
        frequency.requireAuth++;
      }
      if (rule.includes('requirePermission') || rule.includes('permission')) {
        frequency.requirePermission++;
      }
    }

    return frequency;
  }

  /**
   * Determine complexity based on rule count and types
   */
  private determineComplexity(rules: string[]): 'simple' | 'complex' {
    if (rules.length === 0) return 'simple';
    if (rules.length > 3) return 'complex';
    
    const complexRules = ['requirePermission', 'rateLimiter', 'customValidator'];
    const hasComplexRule = rules.some(rule => 
      complexRules.some(complex => rule.includes(complex))
    );
    
    return hasComplexRule ? 'complex' : 'simple';
  }

  /**
   * Extract type references from Candid content
   */
  private extractTypeReferences(content: string): string[] {
    const typeRefs: string[] = [];
    
    // Find type references in method signatures and type definitions
    const patterns = [
      /:\s*([A-Z][A-Za-z0-9_]*)/g,  // Type annotations
      /\[\s*([A-Z][A-Za-z0-9_]*)\s*\]/g,  // Array types
      /\?\s*([A-Z][A-Za-z0-9_]*)/g,  // Optional types
      /record\s*\{\s*[^}]*?:\s*([A-Z][A-Za-z0-9_]*)/g  // Record field types
    ];
    
    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(content)) !== null) {
        typeRefs.push(match[1]);
      }
    }
    
    return [...new Set(typeRefs)];
  }

  /**
   * Extract defined types from Candid content
   */
  private extractDefinedTypes(content: string): string[] {
    const definedTypes: string[] = [];
    
    // Find type definitions
    const typeDefPattern = /type\s+([A-Z][A-Za-z0-9_]*)\s*=/g;
    let match;
    while ((match = typeDefPattern.exec(content)) !== null) {
      definedTypes.push(match[1]);
    }
    
    return definedTypes;
  }

  /**
   * Check if a type name is a builtin type
   */
  private isBuiltinType(typeName: string): boolean {
    const builtins = [
      'text', 'nat', 'int', 'bool', 'blob', 'principal', 
      'vec', 'opt', 'record', 'variant', 'service', 'func',
      'Text', 'Nat', 'Int', 'Bool', 'Blob', 'Principal'
    ];
    return builtins.includes(typeName);
  }

  /**
   * Generate mops.toml build hook configuration
   */
  private generateMopsBuildHook(didFiles: string[]): string {
    const didList = didFiles.map(f => `"${path.relative(process.cwd(), f)}"`).join(', ');
    
    return `
# Add to mops.toml
[build]
pre-build = ["npx inspect-mo-generate --auto-discover"]

[tools.inspect-mo]
did-files = [${didList}]
output-dir = "src/generated/"
auto-generate = true
watch-mode = true
`.trim();
  }

  /**
   * Generate dfx.json build hook configuration
   */
  private generateDfxBuildHook(didFiles: string[]): string {
    const didList = didFiles.map(f => `"${path.relative(process.cwd(), f)}"`).join(', ');
    
    return `
// Add to dfx.json
{
  "canisters": {
    "your_canister": {
      "main": "./src/main.mo",
      "type": "motoko",
      "prebuild": ["npm run codegen"]
    }
  },
  "scripts": {
    "codegen": "inspect-mo-generate --auto-discover --output src/generated/"
  }
}
`.trim();
  }

  /**
   * Generate auto-generation command
   */
  private generateAutoGenerationCommand(didFiles: string[]): string {
    if (didFiles.length === 1) {
      return `npx inspect-mo-generate ${path.relative(process.cwd(), didFiles[0])} -o inspect-boilerplate.mo`;
    } else {
      return `npx inspect-mo-generate --scan . --output src/generated/`;
    }
  }
}
