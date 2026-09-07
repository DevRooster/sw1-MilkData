const fs = require('node:fs');

const coverage = JSON.parse(fs.readFileSync('coverage/coverage-final.json', 'utf8'));
for (const [file, data] of Object.entries(coverage)) {
  if (!file.includes(`${require('node:path').sep}src${require('node:path').sep}repositories${require('node:path').sep}`) && !file.includes(`${require('node:path').sep}src${require('node:path').sep}services${require('node:path').sep}`)) {
    continue;
  }

  const uncoveredStatements = Object.entries(data.s)
    .filter(([, count]) => count === 0)
    .map(([id]) => data.statementMap[id].start.line);
  const uncoveredFunctions = Object.entries(data.f)
    .filter(([, count]) => count === 0)
    .map(([id]) => `${data.fnMap[id].name}@${data.fnMap[id].loc.start.line}`);
  const uncoveredBranches = [];
  for (const [id, counts] of Object.entries(data.b)) {
    counts.forEach((count, index) => {
      if (count === 0) {
        const location = data.branchMap[id].locations[index];
        uncoveredBranches.push(`${data.branchMap[id].type}@${location.start.line}`);
      }
    });
  }

  console.log(file);
  console.log('  statements:', [...new Set(uncoveredStatements)].join(', ') || 'none');
  console.log('  functions:', uncoveredFunctions.join(', ') || 'none');
  console.log('  branches:', uncoveredBranches.join(', ') || 'none');
}
