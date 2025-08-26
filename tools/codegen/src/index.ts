/**
 * InspectMo Code Generation Tool
 * 
 * Main entry point for the code generation library
 */

export { parseCandidFile } from './candid-parser';
export { MotokoCodeGenerator } from './code-generator';
export * from './types';

// Re-export for convenience
import { parseCandidFile } from './candid-parser';
import { MotokoCodeGenerator } from './code-generator';
import { GenerationOptions } from './types';

/**
 * High-level function to generate InspectMo code from a Candid file
 */
export function generateFromCandidFile(
  candidFilePath: string, 
  outputPath: string,
  options: Partial<GenerationOptions> = {}
): { success: boolean; error?: string; generatedCode?: string } {
  
  try {
    // Parse Candid file
    const parseResult = parseCandidFile(candidFilePath);
    
    if (!parseResult.success || !parseResult.service) {
      return {
        success: false,
        error: `Failed to parse Candid file: ${parseResult.errors.join(', ')}`
      };
    }

    // Generate code
    const generator = new MotokoCodeGenerator();
    const context = {
      serviceName: 'GeneratedService',
      service: parseResult.service,
      outputPath,
      options: {
        generateAccessors: true,
        generateInspectTemplate: true,
        generateGuardTemplate: true,
        generateMethodExtraction: true,
        generateTypeDefinitions: true,
        includeComments: true,
        ...options
      }
    };

    const generatedCode = generator.generateBoilerplate(context);

    return {
      success: true,
      generatedCode
    };

  } catch (error) {
    return {
      success: false,
      error: `Code generation failed: ${error}`
    };
  }
}

/**
 * Analyze a Candid service and return validation suggestions
 */
export function analyzeCandidService(candidFilePath: string) {
  const parseResult = parseCandidFile(candidFilePath);
  
  if (!parseResult.success || !parseResult.service) {
    throw new Error(`Failed to parse Candid file: ${parseResult.errors.join(', ')}`);
  }

  const generator = new MotokoCodeGenerator();
  return generator.analyzeService(parseResult.service);
}
