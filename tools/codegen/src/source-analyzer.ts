/**
 * Source code analyzer for detecting existing InspectMo usage patterns
 */

import * as fs from 'fs';
import * as path from 'path';

export interface InspectMoUsage {
  file: string;
  line: number;
  type: 'inspect' | 'guard';
  method?: string;
  rules: string[];
  raw: string;
}

export interface AnalysisResult {
  inspectCalls: InspectMoUsage[];
  guardCalls: InspectMoUsage[];
  suggestions: string[];
}

export class SourceAnalyzer {
  
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
}
