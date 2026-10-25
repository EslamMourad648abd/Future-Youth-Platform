# Roles, Permissions & Restrictions

Backend rules must enforce permissions. Hiding controls in the UI is not sufficient.

## Admin
**Stated:** private/hidden login entry; review teacher uploads and AI reports; approve/reject videos; provide rejection reason and exact timecode; support users.
**Recommended:** provision teacher accounts; suspend/reactivate/edit accounts; soft-delete with audit log; record privileged actions. Never expose passwords/secrets.

## Teacher
**Stated:** separate private login entry; create playlists by subject/school year; organize units, lessons and numbered videos; submit uploads for AI review; see own AI reports; see own content views, ratings and comments.
**Restrictions:** cannot approve/publish own videos or access unrelated users' private data.
**Lifecycle:** draft/uploaded → submitted → AI review → pending Admin decision → approved/published OR rejected with reason/timecode → replacement/resubmission → reviewed again.

## Parent
**Stated:** public registration with name, national ID and phone; add children with name, national ID, school year and required email; invite child by email; pay tuition; view own children's exam results, curriculum progress, watch time and replay counts.
**Restrictions:** only own children; cannot act as a Student learner or see another family's data.

## Student
**Stated:** no self-registration; accept invitation and set password; choose teacher per subject and confirm twice; browse curriculum; watch designated free preview; access paid lessons after eligibility checks; take exams and see own results/progress.
**Restrictions:** cannot pay, see other students' records, access unpaid paid-content, or see unapproved/rejected videos.

## Access policy for a paid lesson
Require all applicable checks:
1. Authenticated Student with valid invitation/account and not suspended.
2. Video approved and published.
3. Confirmed teacher selection for the subject.
4. Parent payment/subscription confirmed and active.
5. Sufficient points if the final points policy requires them.
6. Server-side authorization; client cannot mint points or set payment state.

The designated free preview bypasses only payment/points checks. It does not bypass authentication, content approval, or privacy controls.

## Summary
| Capability | Admin | Teacher | Parent | Student |
|---|---|---|---|---|
| Public self-registration | No | No | Yes | No |
| Create/invite children | No | No | Yes | No |
| Create curriculum content | No | Yes | No | No |
| Submit for AI review | No | Yes | No | No |
| Approve/reject videos | Yes | No | No | No |
| Pay tuition | No | No | Yes | No |
| Watch free preview | Admin review | Own content preview | Unresolved | Yes |
| Watch paid lessons | No | Own content preview | No | After eligibility checks |
| Take exams | No | No | No | Yes, when eligible |
| View all user accounts | Yes | No | No | No |
| View own children's progress | No | No | Yes | No |
| View own results | No | No | No | Yes |
| View own content analytics | Review all | Yes | No | No |

## Security notes
- Role changes only through privileged backend code/custom claims.
- Scope Firestore reads/writes by UID, parent-child relationship, teacher ownership, and Admin role.
- Never trust role values from client request bodies.
- Validate payments and point transactions server-side.
- Audit privileged actions without storing secrets or excessive sensitive data.
