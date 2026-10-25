# Future Youth Platform feature

This feature introduces the first role-aware application workspace in the existing Flutter app.

- Brand: navy #263778 and green #00A651.
- Roles: admin/superadmin, teacher, parent, student.
- The first iteration provides role-specific navigation, Firestore-backed draft playlist records, child profile/invitation requests, pending payment requests, and an Admin content-review surface.
- It does **not** claim to include actual video uploads, an AI moderation provider, email invitations, a payment gateway, server-side point deductions, or end-to-end security verification. Those require trusted backend integrations and verified Firestore rules.
- All production access must be enforced by Firebase rules/Cloud Functions; client-side navigation is not a security boundary.
