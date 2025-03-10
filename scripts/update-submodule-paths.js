#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Determine if running in submodule context
const isSubmodule = process.argv.includes('--submodule');

// Update remappings
const remappingsPath = path.join(__dirname, '..', 'remappings.txt');
const solacenetRemappingsPath = path.join(__dirname, '..', 'solacenet.remappings.txt');

if (isSubmodule) {
  // Copy submodule remappings to main remappings
  fs.copyFileSync(solacenetRemappingsPath, remappingsPath);
  console.log('Updated remappings for submodule context');
} else {
  // Restore original remappings (from git)
  console.log('Restored remappings for standalone context');
  // Use git to restore the original remappings
  const { execSync } = require('child_process');
  try {
    execSync('git checkout -- ' + remappingsPath, { stdio: 'inherit' });
  } catch (error) {
    console.error('Failed to restore original remappings:', error.message);
  }
}

console.log(`Repository configured for ${isSubmodule ? 'submodule' : 'standalone'} usage`);
