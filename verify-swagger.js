async function main() {
  const docsResponse = await fetch('http://127.0.0.1:3000/api-docs');
  const jsonResponse = await fetch('http://127.0.0.1:3000/api-docs.json');
  const html = await docsResponse.text();
  const document = await jsonResponse.json();

  console.log('API_DOCS_STATUS:', docsResponse.status);
  console.log('API_DOCS_HTML_HAS_SWAGGER_UI:', html.includes('swagger-ui'));
  console.log('API_DOCS_JSON_STATUS:', jsonResponse.status);
  console.log('API_DOCS_JSON_LITERAL:', JSON.stringify(document));

  if (docsResponse.status !== 200 || jsonResponse.status !== 200 || !html.includes('swagger-ui')) {
    throw new Error('Swagger no está disponible correctamente');
  }
}

main().catch((error) => {
  console.error('SWAGGER_ERROR:', error.message);
  process.exitCode = 1;
});
