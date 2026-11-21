const fs = require('fs');
const path = require('path');

const source = path.resolve(__dirname, '../../darchstorebac/build');
const target = path.resolve(__dirname, '../hosting');

if (!fs.existsSync(path.join(source, 'index.html'))) {
  console.error('Build du back-office introuvable. Lancez npm run build dans darchstorebac.');
  process.exit(1);
}

fs.rmSync(target, { recursive: true, force: true });
fs.cpSync(source, target, { recursive: true });
console.log('Back-office copié vers hosting/.');
