const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

// When a due is created, create due_payments entries (one per member) with unpaid status
exports.onDueCreated = functions.firestore
  .document('organizations/{orgId}/dues/{dueId}')
  .onCreate(async (snap, context) => {
    const { orgId, dueId } = context.params;
    const due = snap.data();
    if (!due) return null;

    // Fetch organization members
    const membersSnap = await db.collection('organizations').doc(orgId).collection('members').get();
    const batch = db.batch();
    membersSnap.docs.forEach(memberDoc => {
      const uid = memberDoc.id;
      const paymentRef = db.collection('organizations').doc(orgId).collection('dues').doc(dueId).collection('due_payments').doc(uid);
      batch.set(paymentRef, {
        id: uid,
        dueId: dueId,
        userId: uid,
        transactionId: '',
        amount: due.amount || 0,
        paidAt: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    return batch.commit();
  });

// When a due_payment is created/updated (i.e. payment recorded), update a summary document for quick totals
exports.onDuePaymentWrite = functions.firestore
  .document('organizations/{orgId}/dues/{dueId}/due_payments/{paymentId}')
  .onWrite(async (change, context) => {
    const { orgId, dueId } = context.params;
    // Compute totals: total collected for this due, number paid, number unpaid
    const paymentsSnap = await db.collection('organizations').doc(orgId).collection('dues').doc(dueId).collection('due_payments').get();
    let totalCollected = 0;
    let paidCount = 0;
    paymentsSnap.docs.forEach(d => {
      const data = d.data();
      const amt = Number(data.amount || 0);
      if (data.paidAt) {
        totalCollected += amt;
        paidCount += 1;
      }
    });
    const summaryRef = db.collection('organizations').doc(orgId).collection('dues').doc(dueId).collection('meta').doc('summary');
    return summaryRef.set({ totalCollected, paidCount, totalMembers: paymentsSnap.size }, { merge: true });
  });
