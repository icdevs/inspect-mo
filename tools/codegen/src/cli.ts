/**
 * CLI tool for InspectMo code generation
 */

import { Command } from 'commander';
import { existsSync, writeFileSync } from 'fs';
import { join } from 'path';
import { parseCandidFile } from './candid-parser';
import { MotokoCodeGenerator } from './code-generator';
import { SourceAnalyzer } from './source-analyzer';
import { GenerationOptions } from './types';

const program = new Command();

program
  .name('inspect-mo-generate')
  .description('Generate InspectMo boilerplate from Candid interface files')
  .version('1.0.0');

program
  .command('generate')
  .description('Generate InspectMo code from a Candid (.did) file')
  .argument('<candid-file>', 'Path to the Candid (.did) file')
  .option('-o, --output <file>', 'Output file path', 'generated-inspect.mo')
  .option('--no-accessors', 'Skip generating accessor functions')
  .option('--no-inspect', 'Skip generating inspect template')
  .option('--no-guard', 'Skip generating guard template') 
  .option('--no-methods', 'Skip generating method extraction')
  .option('--no-comments', 'Skip generating documentation comments')
  .action((candidFile: string, options: any) => {
    console.log(`🔍 Parsing Candid file: ${candidFile}`);
    
    if (!existsSync(candidFile)) {
      console.error(`❌ Error: Candid file not found: ${candidFile}`);
      process.exit(1);
    }

    // Parse Candid file
    const parseResult = parseCandidFile(candidFile);
    
    if (!parseResult.success || !parseResult.service) {
      console.error('❌ Failed to parse Candid file:');
      parseResult.errors.forEach(error => console.error(`   ${error}`));
      process.exit(1);
    }

    if (parseResult.warnings.length > 0) {
      console.warn('⚠️  Warnings:');
      parseResult.warnings.forEach(warning => console.warn(`   ${warning}`));
    }

    console.log(`✅ Successfully parsed ${parseResult.service.methods.length} methods`);

    // Configure generation options
    const generationOptions: GenerationOptions = {
      generateAccessors: options.accessors !== false,
      generateInspectTemplate: options.inspect !== false,
      generateGuardTemplate: options.guard !== false,
      generateMethodExtraction: options.methods !== false,
      includeComments: options.comments !== false
    };

    // Generate code
    console.log('🔧 Generating InspectMo boilerplate...');
    
    const generator = new MotokoCodeGenerator();
    const context = {
      serviceName: 'GeneratedService',
      service: parseResult.service,
      outputPath: options.output,
      options: generationOptions
    };

    const generatedCode = generator.generateBoilerplate(context);
    
    // Write output file
    try {
      writeFileSync(options.output, generatedCode, 'utf-8');
      console.log(`✅ Generated code written to: ${options.output}`);
    } catch (error) {
      console.error(`❌ Failed to write output file: ${error}`);
      process.exit(1);
    }

    // Generate analysis report
    const analysis = generator.analyzeService(parseResult.service);
    console.log('\n📊 Method Analysis:');
    
    for (const methodAnalysis of analysis) {
      const { method, suggestedValidations, complexity, securityConsiderations } = methodAnalysis;
      
      console.log(`\n🔍 ${method.name} (${method.isQuery ? 'query' : 'update'}) - ${complexity} complexity`);
      
      if (suggestedValidations.length > 0) {
        console.log('   Suggested validations:');
        suggestedValidations.forEach(v => {
          console.log(`     • ${v.type}: ${v.reason} (${v.priority} priority)`);
        });
      }
      
      if (securityConsiderations.length > 0) {
        console.log('   Security considerations:');
        securityConsiderations.forEach(c => console.log(`     • ${c}`));
      }
    }

    console.log(`\n🎉 Code generation complete! Check ${options.output} for the generated boilerplate.`);
  });

program
  .command('analyze')
  .description('Analyze a Candid file and suggest validations without generating code')
  .argument('<candid-file>', 'Path to the Candid (.did) file')
  .action((candidFile: string) => {
    console.log(`🔍 Analyzing Candid file: ${candidFile}`);
    
    if (!existsSync(candidFile)) {
      console.error(`❌ Error: Candid file not found: ${candidFile}`);
      process.exit(1);
    }

    const parseResult = parseCandidFile(candidFile);
    
    if (!parseResult.success || !parseResult.service) {
      console.error('❌ Failed to parse Candid file:');
      parseResult.errors.forEach(error => console.error(`   ${error}`));
      process.exit(1);
    }

    const generator = new MotokoCodeGenerator();
    const analysis = generator.analyzeService(parseResult.service);
    
    console.log(`\n📊 Service Analysis for ${parseResult.service.methods.length} methods:\n`);
    
    for (const methodAnalysis of analysis) {
      const { method, suggestedValidations, complexity, securityConsiderations } = methodAnalysis;
      
      console.log(`🔍 Method: ${method.name}`);
      console.log(`   Type: ${method.isQuery ? 'query' : 'update'}`);
      console.log(`   Complexity: ${complexity}`);
      console.log(`   Parameters: ${method.parameters.length}`);
      
      if (method.parameters.length > 0) {
        console.log('   Parameter types:');
        method.parameters.forEach((p, i) => {
          console.log(`     ${i + 1}. ${p.name || 'unnamed'}: ${p.type.kind}`);
        });
      }
      
      if (suggestedValidations.length > 0) {
        console.log('   Suggested validations:');
        suggestedValidations.forEach(v => {
          console.log(`     • ${v.type}: ${v.reason} (${v.priority} priority)`);
        });
      }
      
      if (securityConsiderations.length > 0) {
        console.log('   Security considerations:');
        securityConsiderations.forEach(c => console.log(`     • ${c}`));
      }
      
      console.log('');
    }
  });

program
  .command('scan')
  .description('Scan existing source code for InspectMo usage patterns')
  .argument('[source-dir]', 'Directory to scan for .mo files', '.')
  .option('--detailed', 'Show detailed line-by-line analysis')
  .action((sourceDir: string, options: any) => {
    console.log(`🔍 Scanning for InspectMo usage in: ${sourceDir}`);
    
    if (!existsSync(sourceDir)) {
      console.error(`❌ Error: Directory not found: ${sourceDir}`);
      process.exit(1);
    }

    const analyzer = new SourceAnalyzer();
    const result = analyzer.analyzeDirectory(sourceDir);
    
    console.log(`\n📊 Scan Results:`);
    console.log(`   • ${result.inspectCalls.length} inspect() calls found`);
    console.log(`   • ${result.guardCalls.length} guard() calls found`);
    
    if (options.detailed) {
      if (result.inspectCalls.length > 0) {
        console.log('\n📋 Inspect calls:');
        for (const call of result.inspectCalls) {
          console.log(`   • ${call.file}:${call.line}`);
          console.log(`     Method: ${call.method || 'unknown'}`);
          console.log(`     Rules: ${call.rules.join(', ') || 'none'}`);
          console.log(`     Code: ${call.raw}`);
          console.log('');
        }
      }

      if (result.guardCalls.length > 0) {
        console.log('🛡️ Guard calls:');
        for (const call of result.guardCalls) {
          console.log(`   • ${call.file}:${call.line}`);
          console.log(`     Method: ${call.method || 'runtime'}`);
          console.log(`     Rules: ${call.rules.join(', ') || 'none'}`);
          console.log(`     Code: ${call.raw}`);
          console.log('');
        }
      }
    }

    if (result.suggestions.length > 0) {
      console.log('\n💡 Suggestions:');
      for (const suggestion of result.suggestions) {
        console.log(`   • ${suggestion}`);
      }
    }

    console.log('\n✅ Scan complete!');
  });

if (require.main === module) {
  program.parse(process.argv);
}

export { program };
