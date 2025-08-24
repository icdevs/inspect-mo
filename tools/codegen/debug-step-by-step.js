const content = `service : {
  set_data: (text) -> ();
}`;

// Simulate the parsing logic step by step
const cleanContent = content
  .replace(/\/\/.*$/gm, '')
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .trim();

console.log('Clean content:', cleanContent);

const serviceMatch = cleanContent.match(/service\s*:\s*\{([\s\S]*)\}/);
if (serviceMatch) {
  const serviceBody = serviceMatch[1];
  console.log('Service body:', JSON.stringify(serviceBody));
  
  const methodMatches = serviceBody.matchAll(/(\w+)\s*:\s*([^;]+);?/g);
  for (const match of methodMatches) {
    const [, methodName, signaturePart] = match;
    console.log(`Method: ${methodName}`);
    console.log(`Signature part: "${signaturePart}"`);
    
    const isQuery = signaturePart.includes('query');
    const cleanSignature = signaturePart.replace(/\s+query\s*$/, '').trim();
    console.log(`Clean signature: "${cleanSignature}"`);
    
    const arrowIndex = cleanSignature.indexOf('->');
    console.log(`Arrow index: ${arrowIndex}`);
    
    if (arrowIndex !== -1) {
      const paramsPart = cleanSignature.substring(0, arrowIndex).trim();
      const returnPart = cleanSignature.substring(arrowIndex + 2).trim();
      
      console.log(`Params part: "${paramsPart}"`);
      console.log(`Return part: "${returnPart}"`);
      console.log(`Return part after cleanup: "${returnPart.replace(/^\(|\)$/g, '').trim()}"`);
    }
    console.log('---');
  }
}
