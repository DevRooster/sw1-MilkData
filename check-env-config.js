const fs = require('fs');

const envKeysExists = fs.existsSync('.env.keys');
const gitignoreText = fs.existsSync('.gitignore') ? fs.readFileSync('.gitignore', 'utf8') : '';

console.log(envKeysExists ? '.env.keys_EXISTS' : '.env.keys_MISSING');
console.log(gitignoreText.includes('.env.keys') ? '.env.keys_IN_GITIGNORE' : '.env.keys_NOT_IN_GITIGNORE');
