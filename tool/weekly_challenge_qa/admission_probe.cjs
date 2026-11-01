
// Probe only actual client writes to one known local fixture. Never replace event identity.
const {onDocumentCreatedWithAuthContext} = require('firebase-functions/v2/firestore');
exports.qaAdmissionProbe = onDocumentCreatedWithAuthContext({document: 'walls/{wallId}', region: 'asia-south1'}, async event => {
  if (!event.data || event.params.wallId !== 'qa-upload-probe') return;
  const {admin, db, challenge} = require('../backend.cjs').load(require('node:path').resolve(__dirname, '..'));
  const provenance = {authId: event.authId || null, authType: event.authType || null};
  const before = event.data.data();
  const admitted = await challenge.admitChallengeWall(event.data, event.authId, event.authType);
  const after = (await event.data.ref.get()).data();
  await db.doc('qaEvidence/admissionProbe').set({provenance, before, after, admitted, observedAt: admin.firestore.Timestamp.now()});
  console.log('LOCAL_QA_ADMISSION_PROVENANCE', JSON.stringify({provenance, admitted}));
});
