const fs = require('fs');
const path = require('path');
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

function readProjectId() {
  if (process.env.GOOGLE_CLOUD_PROJECT) return process.env.GOOGLE_CLOUD_PROJECT;
  const rc = path.resolve(__dirname, '../../.firebaserc');
  if (!fs.existsSync(rc)) return undefined;
  const parsed = JSON.parse(fs.readFileSync(rc, 'utf8'));
  return parsed.projects && parsed.projects.default;
}

async function main() {
  const revoke = process.argv.includes('--revoke');
  const email = process.argv.find((arg) => arg.includes('@'));
  if (!email) {
    console.error('Usage: node scripts/set-admin.js admin@example.com [--revoke]');
    process.exit(1);
  }

  const projectId = readProjectId();
  if (!projectId) {
    console.error('Projet introuvable. Dans le dossier darchstore : firebase use --add');
    console.error('Ou exportez GOOGLE_CLOUD_PROJECT.');
    process.exit(1);
  }

  initializeApp({
    credential: applicationDefault(),
    projectId,
  });

  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  const claims = { ...(user.customClaims || {}) };
  if (revoke) delete claims.admin;
  else claims.admin = true;
  await auth.setCustomUserClaims(user.uid, claims);
  const verb = revoke ? 'retiré à' : 'accordé à';
  console.log(`Droit admin ${verb} ${email} (${user.uid}) sur ${projectId}.`);
  console.log('La personne doit se déconnecter, puis se reconnecter.');
}

main().catch((error) => {
  console.error(error.message || error);
  console.error('Identifiants : gcloud auth application-default login');
  console.error('Ou GOOGLE_APPLICATION_CREDENTIALS vers une clé de compte de service.');
  process.exit(1);
});
