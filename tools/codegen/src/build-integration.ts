/**
 * Build system integration for automated code generation
 */

import * as fs from 'fs';
import * as path from 'path';
const toml = require('toml');
import { AutoDiscoveryOptions, ProjectAnalysis, IntegrationSuggestion } from './types';

export interface BuildConfig {
  projectRoot: string;
  outputDir: string;
  didFiles: string[];
  autoGenerate: boolean;
  watchMode: boolean;
}

export interface MopsConfig {
  build?: {
    'pre-build'?: string[];
    'post-build'?: string[];
  };
  tools?: {
    'inspect-mo'?: {
      'did-files'?: string[];
      'output-dir'?: string;
      'auto-generate'?: boolean;
      'watch-mode'?: boolean;
    };
  };
}

export interface DfxConfig {
  canisters?: Record<string, {
    main?: string;
    type?: string;
    prebuild?: string[];
    postbuild?: string[];
  }>;
  scripts?: Record<string, string>;
}

export class BuildIntegrator {
  
  /**
   * Install mops build integration - NOT SUPPORTED
   * mops.toml does not support build hooks or prebuild commands
   */
  public async installMopsIntegration(projectRoot: string, buildConfig: BuildConfig): Promise<{
    success: boolean;
    message: string;
  }> {
    return {
      success: false,
      message: 'mops.toml does not support build hooks - integration not available'
    };
  }  /**
   * Install dfx.json integration hooks
   */
  public async installDfxIntegration(
    projectRoot: string,
    buildConfig: BuildConfig
  ): Promise<{ success: boolean; message: string }> {
    const dfxPath = path.join(projectRoot, 'dfx.json');
    
    try {
      let dfxConfig: DfxConfig = {};
      
      // Read existing dfx.json if it exists
      if (fs.existsSync(dfxPath)) {
        const content = fs.readFileSync(dfxPath, 'utf-8');
        dfxConfig = JSON.parse(content);
      }
      
      // Initialize sections if they don't exist
      if (!dfxConfig.canisters) dfxConfig.canisters = {};
      if (!dfxConfig.scripts) dfxConfig.scripts = {};
      
      // Add codegen script
      const codegenCommand = `inspect-mo-generate --auto-discover --output ${buildConfig.outputDir}`;
      dfxConfig.scripts.codegen = codegenCommand;
      
      // Add prebuild hooks to all Motoko canisters
      for (const [canisterName, canisterConfig] of Object.entries(dfxConfig.canisters)) {
        if (canisterConfig.type === 'motoko' || canisterConfig.main?.endsWith('.mo')) {
          if (!canisterConfig.prebuild) {
            canisterConfig.prebuild = [];
          }
          
          const prebuildCommand = 'npm run codegen';
          if (!canisterConfig.prebuild.includes(prebuildCommand)) {
            canisterConfig.prebuild.push(prebuildCommand);
          }
        }
      }
      
      // Write back to file with pretty formatting
      const updatedContent = JSON.stringify(dfxConfig, null, 2);
      fs.writeFileSync(dfxPath, updatedContent);
      
      return {
        success: true,
        message: `Successfully updated dfx.json with InspectMo prebuild hooks`
      };
      
    } catch (error) {
      return {
        success: false,
        message: `Failed to update dfx.json: ${error}`
      };
    }
  }
  
  /**
   * Check current integration status
   */
  public checkIntegrationStatus(projectRoot: string): {
    mopsInstalled: boolean;
    dfxInstalled: boolean;
    details: string[];
  } {
    const details: string[] = [];
    let mopsInstalled = false;
    let dfxInstalled = false;
    
    // Note: mops.toml doesn't support prebuild hooks, so mops integration is not available
    details.push('ℹ️  mops.toml does not support prebuild hooks - integration not available');
    
    // Check dfx.json
    const dfxPath = path.join(projectRoot, 'dfx.json');
    if (fs.existsSync(dfxPath)) {
      try {
        const content = fs.readFileSync(dfxPath, 'utf-8');
        const dfxConfig = JSON.parse(content) as DfxConfig;
        
        if (dfxConfig.scripts?.codegen?.includes('inspect-mo-generate')) {
          details.push('✅ dfx.json has inspect-mo codegen script');
        } else {
          details.push('❌ dfx.json missing inspect-mo codegen script');
        }
        
        const motokoCanisters = Object.entries(dfxConfig.canisters || {})
          .filter(([_, config]) => config.type === 'motoko' || config.main?.endsWith('.mo'));
          
        const canistersWithPrebuild = motokoCanisters
          .filter(([_, config]) => config.prebuild?.some(cmd => cmd.includes('codegen')));
          
        if (canistersWithPrebuild.length > 0) {
          dfxInstalled = true;
          details.push(`✅ ${canistersWithPrebuild.length}/${motokoCanisters.length} Motoko canisters have prebuild hooks`);
        } else if (motokoCanisters.length > 0) {
          details.push(`❌ 0/${motokoCanisters.length} Motoko canisters have prebuild hooks`);
        }
      } catch (error) {
        details.push(`❌ Error reading dfx.json: ${error}`);
      }
    } else {
      details.push('❌ dfx.json not found');
    }
    
    return { mopsInstalled, dfxInstalled, details };
  }
  
  /**
   * Remove build system integration
   */
  public async uninstallIntegration(projectRoot: string): Promise<{
    success: boolean;
    message: string;
  }> {
    const results: string[] = [];
    
    // Remove from mops.toml
    const mopsPath = path.join(projectRoot, 'mops.toml');
    if (fs.existsSync(mopsPath)) {
      try {
        const content = fs.readFileSync(mopsPath, 'utf-8');
        const mopsConfig = toml.parse(content) as MopsConfig;
        
        // Remove pre-build hooks
        if (mopsConfig.build?.['pre-build']) {
          mopsConfig.build['pre-build'] = mopsConfig.build['pre-build']
            .filter(cmd => !cmd.includes('inspect-mo-generate'));
        }
        
        // Remove tools section
        if (mopsConfig.tools?.['inspect-mo']) {
          delete mopsConfig.tools['inspect-mo'];
        }
        
        const updatedContent = this.stringifyToml(mopsConfig);
        fs.writeFileSync(mopsPath, updatedContent);
        results.push('Removed mops.toml integration');
      } catch (error) {
        results.push(`Failed to remove mops.toml integration: ${error}`);
      }
    }
    
    // Remove from dfx.json
    const dfxPath = path.join(projectRoot, 'dfx.json');
    if (fs.existsSync(dfxPath)) {
      try {
        const content = fs.readFileSync(dfxPath, 'utf-8');
        const dfxConfig = JSON.parse(content) as DfxConfig;
        
        // Remove codegen script
        if (dfxConfig.scripts?.codegen?.includes('inspect-mo-generate')) {
          delete dfxConfig.scripts.codegen;
        }
        
        // Remove prebuild hooks
        for (const [_, canisterConfig] of Object.entries(dfxConfig.canisters || {})) {
          if (canisterConfig.prebuild) {
            canisterConfig.prebuild = canisterConfig.prebuild
              .filter(cmd => !cmd.includes('codegen'));
            
            if (canisterConfig.prebuild.length === 0) {
              delete canisterConfig.prebuild;
            }
          }
        }
        
        const updatedContent = JSON.stringify(dfxConfig, null, 2);
        fs.writeFileSync(dfxPath, updatedContent);
        results.push('Removed dfx.json integration');
      } catch (error) {
        results.push(`Failed to remove dfx.json integration: ${error}`);
      }
    }
    
    return {
      success: true,
      message: results.join('; ')
    };
  }
  
  /**
   * Generate build configuration from project analysis
   */
  public generateBuildConfig(
    projectRoot: string, 
    analysis: ProjectAnalysis,
    outputDir: string = 'src/generated/'
  ): BuildConfig {
    return {
      projectRoot,
      outputDir,
      didFiles: analysis.didFiles,
      autoGenerate: true,
      watchMode: true
    };
  }
  
  /**
   * Convert object to TOML string (simple implementation)
   */
  private stringifyToml(obj: any, level: number = 0): string {
    const indent = '  '.repeat(level);
    let result = '';
    
    for (const [key, value] of Object.entries(obj)) {
      if (value && typeof value === 'object' && !Array.isArray(value)) {
        // Section header
        if (level === 0) {
          result += `\n[${key}]\n`;
        } else {
          result += `\n${indent}[${key}]\n`;
        }
        result += this.stringifyToml(value, level + 1);
      } else if (Array.isArray(value)) {
        // Array values
        const arrayStr = value.map(v => typeof v === 'string' ? `"${v}"` : String(v)).join(', ');
        result += `${indent}${key} = [${arrayStr}]\n`;
      } else if (typeof value === 'string') {
        // String values
        result += `${indent}${key} = "${value}"\n`;
      } else {
        // Other values (boolean, number)
        result += `${indent}${key} = ${value}\n`;
      }
    }
    
    return result;
  }
}
