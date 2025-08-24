const { parseCandidFile } = require('./dist/candid-parser');

const result = parseCandidFile('./simple-test.did');
if (result.success && result.service) {
  console.log('Methods and their return types:');
  for (const method of result.service.methods) {
    console.log(`${method.name}: returnType =`, method.returnType);
  }
}
