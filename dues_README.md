Dues feature — Firestore structure, rules and automation

Overview
--------

This document describes the recommended Firestore structure, security rules, client-side helper (Dart) and optional Cloud Functions to support "dues" and "due_payments" in the app.

Firestore structure
-------------------

Place dues under each organization so data is scoped per org:

organizations/{orgId}/dues/{dueId}

- orgId, name, amount, frequency, dueDate, createdBy, createdAt, updatedAt
- due_payments/{paymentId} (paymentId = userId recommended)
  - id (userId), dueId, userId, transactionId, amount, paidAt, createdAt, updatedAt
- meta/summary (optional single doc)
  - totalCollected, paidCount, totalMembers

Design notes
------------

- Storing dues inside organizations keeps data ownership and permissions straightforward.
- Storing due_payments as a subcollection simplifies cascading deletes and query locality; using userId as the payment doc id enforces uniqueness (dueId,userId).

Security rules
--------------

- See `firestore.rules` in the repo. The rules require the requesting user to be a member of the org to read dues. Only the creator may update/delete a due. Users may create/update their own payment record; admins may manage all payments.

Dart helper
-----------

- `lib/services/dues_service.dart` in the repo provides create/update/delete helpers for dues and due_payments. It uses server timestamps and client-side cascading deletes (batch deletes payments then the due).

Client-Side Automation
-----------------------

- Payment placeholders are created automatically when a due is created
- Summary calculations are performed client-side for real-time updates
- All operations are handled through the DuesService for consistency

Deployment
----------

1. Deploy rules:

   firebase deploy --only firestore:rules

Notes & Caveats
---------------

- Payment placeholders are created for all organization members when a due is created
- For large organizations (>5000 members), consider implementing pagination for placeholder creation
- All operations are client-side for consistency with the rest of the application
- Adjust security rules according to your org member document structure (roles, membership collection path)
