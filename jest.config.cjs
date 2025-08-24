/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: 'ts-jest',
  globalSetup: '<rootDir>/pic/global-setup.ts',
  globalTeardown: '<rootDir>/pic/global-teardown.ts',
  testEnvironment: 'node',
  extensionsToTreatAsEsm: ['.ts'],
  globals: {
    'ts-jest': {
      useESM: true
    }
  },
  transform: {
    '^.+\\.ts?$': ['ts-jest', { useESM: true }],
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
