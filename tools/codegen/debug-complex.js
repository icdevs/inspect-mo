const { parseCandidFile } = require('./dist/candid-parser');

const result = parseCandidFile('../../.dfx/local/canisters/complex_test_canister/complex_test_canister.did');
if (result.success && result.service) {
  console.log(`Found ${result.service.methods.length} methods:`);
  for (const method of result.service.methods) {
    console.log(`- ${method.name}: ${method.parameters.length} params, returns ${method.returnType ? method.returnType.kind : 'void'}`);
  }
  
  console.log('\nLooking for complex_operation...');
  const complexOp = result.service.methods.find(m => m.name.includes('complex'));
  if (complexOp) {
    console.log('Found complex operation:', complexOp);
  } else {
    console.log('No complex operation found');
  }
} else {
  console.log('Parse failed:', result.errors);
}
