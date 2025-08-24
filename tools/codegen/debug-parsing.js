const { parseCandidContent } = require('./dist/candid-parser');

const testContent = `service : {
  get_data: () -> (text) query;
  set_data: (text) -> ();
  update_counter: (nat) -> (nat);
}`;

console.log('Original content:');
console.log(testContent);
console.log('\n===================\n');

const result = parseCandidContent(testContent);
if (result.success && result.service) {
  for (const method of result.service.methods) {
    console.log(`Method: ${method.name}`);
    console.log(`  Parameters: ${JSON.stringify(method.parameters)}`);
    console.log(`  Return Type: ${JSON.stringify(method.returnType)}`);
    console.log(`  Is Query: ${method.isQuery}`);
    console.log('');
  }
}
