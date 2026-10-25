// Cuenta la profundidad de llaves, parentesis y corchetes, linea a linea.
// Ignora cadenas y comentarios para no contar sus simbolos.
const fs = require('fs');

const ruta = process.argv[2];
const lineas = fs.readFileSync(ruta, 'utf8').split('\n');

let profundidad = 0;
let anterior = 0;

for (let i = 0; i < lineas.length; i += 1) {
  const codigo = lineas[i]
    .replace(/'[^']*'/g, "''")
    .replace(/"[^"]*"/g, '""')
    .replace(/\/\/.*$/, '');

  const abres = (codigo.match(/[{([]/g) || []).length;
  const cierras = (codigo.match(/[})\]]/g) || []).length;

  anterior = profundidad;
  profundidad += abres - cierras;

  if (profundidad < 0) {
    console.log(`NEGATIVO en la linea ${i + 1}: ${lineas[i].trim()}`);
    break;
  }

  // Solo se avisa de los saltos raros dentro del cuerpo de main().
  if (i > 60 && profundidad !== anterior) {
    console.log(`  linea ${i + 1}  ${anterior} -> ${profundidad}  ${lineas[i].trim().slice(0, 60)}`);
  }
}

console.log(`profundidad final: ${profundidad}`);