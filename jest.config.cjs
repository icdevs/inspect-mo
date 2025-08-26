/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: 'ts-jest',
  globalSetup: '<rootDir>/pic/global-setup.ts',
  globalTeardown: '<rootDir>/pic/global-teardown.ts',
  testEnvironment: 'node',
  testTimeout: 30000, // Increase timeout to 30 seconds for PocketIC setup
  extensionsToTreatAsEsm: ['.ts'],
  transform: {
    '^.+\\.ts?$': ['ts-jest', { useESM: true, tsconfig: '<rootDir>/tsconfig.json' }],
    '^.+\\.js$': ['ts-jest', { useESM: true }],
  },
  transformIgnorePatterns: [
    'node_modules/(?!(@dfinity|@hadronous)/.*)'
  ],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.did\\.js$': '$1.did.js',
    '^(\\.{1,2}/.*)\\.did$': '$1.did.d.ts',
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
  testPathIgnorePatterns: ["<rootDir>/.mops/","<rootDir>/node_modules/", "<rootDir>/web/", "<rootDir>/scratch_tests/"],
  modulePathIgnorePatterns: ["<rootDir>/.mops/"],
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json', 'node']
};
