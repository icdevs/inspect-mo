#!/usr/bin/env node
/**
 * CLI tool for InspectMo code generation
 */

import { Command } from 'commander';
import { existsSync, writeFileSync, mkdirSync } from 'fs';
import { join, basename, relative, resolve, dirname } from 'path';
import { parseCandidFile } from './candid-parser';
import { MotokoCodeGenerator } from './code-generator';
import { SourceAnalyzer } from './source-analyzer';
import { BuildIntegrator } from './build-integration';
import { GenerationOptions } from './types';

const program = new Command();

program
  .name('inspectmo')
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
      generateTypeDefinitions: true, // Always generate missing type definitions
      includeComments: options.comments !== false,
      handleRecursiveTypes: true, // Enable recursive type handling
      maxDepth: 50 // Set max parsing depth
    };

    // Generate code
    console.log('🔧 Generating InspectMo boilerplate...');
    
    const generator = new MotokoCodeGenerator();
    // Resolve output path and guard against accidental root '/src/...'
    const resolvedOutput = resolve(process.cwd(), options.output);
    if (options.output.startsWith('/') && options.output.startsWith('/src/')) {
      console.error(`❌ Output path points to '/src/...', which is the filesystem root. Use a relative path like 'src/generated/inspect.mo' or an absolute path inside your project (e.g., '${resolve(process.cwd(), 'src/generated/inspect.mo')}').`);
      process.exit(1);
    }

    const context = {
      serviceName: 'GeneratedService',
      service: parseResult.service,
      outputPath: resolvedOutput,
      options: generationOptions,
      typeDefinitions: parseResult.typeDefinitions,
      recursiveTypes: new Set(parseResult.recursiveTypes || [])
    };

    const generatedCode = generator.generateBoilerplate(context, candidFile);
    
    // Write output file
    try {
  // Ensure parent directory exists
  const outDir = dirname(resolvedOutput);
      if (!existsSync(outDir)) {
        mkdirSync(outDir, { recursive: true });
      }
  writeFileSync(resolvedOutput, generatedCode, 'utf-8');
  console.log(`✅ Generated code written to: ${resolvedOutput}`);
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
  .command('discover')
  .description('Auto-discover .did files and analyze project structure')
  .argument('[project-dir]', 'Project directory to analyze', '.')
  .option('--include <patterns...>', 'Include patterns for .did files', ['**/*.did', '.dfx/**/*.did'])
  .option('--exclude <patterns...>', 'Exclude patterns', ['node_modules/**', '.git/**'])
  .option('--generate', 'Generate boilerplate for all discovered .did files')
  .option('--output <dir>', 'Output directory for generated files', 'src/generated/')
  .option('--suggest', 'Show integration suggestions')
  .action((projectDir: string, options: any) => {
    console.log(`🔍 Auto-discovering project structure in: ${projectDir}`);
    
    if (!existsSync(projectDir)) {
      console.error(`❌ Error: Directory not found: ${projectDir}`);
      process.exit(1);
    }

    const analyzer = new SourceAnalyzer();
    const analysis = analyzer.analyzeProject(projectDir, {
      projectRoot: projectDir,
      includePatterns: options.include,
      excludePatterns: options.exclude,
      scanMotokoFiles: true,
      generateMissingTypes: true
    });
    
    console.log(`\n📊 Project Analysis:`);
    console.log(`   • ${analysis.didFiles.length} .did file(s) found`);
    console.log(`   • ${analysis.motokoFiles.length} .mo file(s) found`);
    console.log(`   • ${analysis.inspectMoUsage.length} InspectMo usage(s) detected`);
    
    if (analysis.didFiles.length > 0) {
      console.log('\n📄 Candid Files:');
      analysis.didFiles.forEach(file => {
        console.log(`   • ${file}`);
      });
    }
    
    if (analysis.inspectMoUsage.length > 0) {
      console.log('\n� InspectMo Usage:');
      analysis.inspectMoUsage.forEach(usage => {
        console.log(`   • ${usage.filePath}:${usage.lineNumber} - ${usage.usageType}(${usage.methodName})`);
      });
    }
    
    if (analysis.missingTypes.length > 0) {
      console.log('\n⚠️  Missing Types Detected:');
      analysis.missingTypes.forEach(type => {
        console.log(`   • ${type}`);
      });
    }
    
    if (options.suggest && analysis.suggestedIntegrations.length > 0) {
      console.log('\n💡 Integration Suggestions:');
      analysis.suggestedIntegrations.forEach(suggestion => {
        console.log(`\n🔧 ${suggestion.description} (${suggestion.priority} priority)`);
        console.log(`   Implementation:`);
        console.log(`   ${suggestion.implementation.split('\n').join('\n   ')}`);
      });
    }
    
    if (options.generate && analysis.didFiles.length > 0) {
      console.log('\n� Generating boilerplate for discovered .did files...');
      
      const generator = new MotokoCodeGenerator();
      
      for (const didFile of analysis.didFiles) {
        const parseResult = parseCandidFile(didFile);
        
        if (parseResult.success && parseResult.service) {
          const baseName = basename(didFile, '.did');
          const outputDir = resolve(projectDir, options.output || 'src/generated/');
          // Ensure output directory exists
          if (!existsSync(outputDir)) {
            mkdirSync(outputDir, { recursive: true });
          }
          const outputFile = join(outputDir, `${baseName}-inspect.mo`);
          
          const context = {
            serviceName: baseName,
            service: parseResult.service,
            outputPath: outputFile,
            options: {
              generateAccessors: true,
              generateInspectTemplate: true,
              generateGuardTemplate: true,
              generateMethodExtraction: true,
              generateTypeDefinitions: true,
              includeComments: true
            },
            typeDefinitions: parseResult.typeDefinitions,
            recursiveTypes: new Set(parseResult.recursiveTypes || [])
          };
          
          const generatedCode = generator.generateBoilerplate(context, didFile);
          writeFileSync(outputFile, generatedCode, 'utf-8');
          console.log(`   ✅ Generated: ${relative(process.cwd(), outputFile)}`);
        } else {
          console.log(`   ❌ Failed to parse: ${didFile}`);
        }
      }
    }
    
    console.log('\n✅ Discovery complete!');
  });

// Build system integration commands
program
  .command('install-hooks')
  .description('Install DFX build system integration hooks')
  .argument('<project-path>', 'path to the project root')
  .option('--output <dir>', 'output directory for generated code', 'src/generated/')
  .action(async (projectPath: string, options: any) => {
    const integrator = new BuildIntegrator();
    const analyzer = new SourceAnalyzer();
    
    console.log(`🔧 Installing build system hooks in: ${projectPath}\n`);
    
    // Analyze project to get build configuration
    const analysis = analyzer.analyzeProject(projectPath);
    const buildConfig = integrator.generateBuildConfig(projectPath, analysis, options.output);
    
    const results: string[] = [];
    
    // Note: mops integration is not supported
    console.log('ℹ️  mops.toml does not support build hooks - skipping mops integration');
    
    // Install dfx integration  
    const dfxResult = await integrator.installDfxIntegration(projectPath, buildConfig);
    if (dfxResult.success) {
      results.push(`✅ ${dfxResult.message}`);
    } else {
      results.push(`❌ ${dfxResult.message}`);
    }
    
    console.log(results.join('\n'));
    console.log('\n🎉 Build system integration complete!');
  });

program
  .command('status')
  .description('Check build system integration status')
  .argument('<project-path>', 'path to the project root')
  .action((projectPath: string) => {
    const integrator = new BuildIntegrator();
    
    console.log(`📊 Checking build integration status in: ${projectPath}\n`);
    
    const status = integrator.checkIntegrationStatus(projectPath);
    
    console.log('Integration Status:');
    status.details.forEach(detail => console.log(`   ${detail}`));
    
    console.log(`\nOverall Status:`);
    console.log(`   Mops Integration: ❌ Not Supported (mops.toml doesn't support prebuild hooks)`);
    console.log(`   DFX Integration: ${status.dfxInstalled ? '✅ Installed' : '❌ Not Installed'}`);
  });

program
  .command('uninstall-hooks')
  .description('Remove build system integration hooks')
  .argument('<project-path>', 'path to the project root')
  .action(async (projectPath: string) => {
    const integrator = new BuildIntegrator();
    
    console.log(`🗑️  Removing build system hooks from: ${projectPath}\n`);
    
    const result = await integrator.uninstallIntegration(projectPath);
    
    if (result.success) {
      console.log(`✅ ${result.message}`);
    } else {
      console.log(`❌ ${result.message}`);
    }
    
    console.log('\n🧹 Cleanup complete!');
  });

if (require.main === module) {
  program.parse(process.argv);
}

export { program };
