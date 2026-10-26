# Agent tasks

Ordered, copy-and-paste work plan for the AI agent in Android Studio.
Requirements are in `docs/REQUIREMENTS.md`, design in `docs/ARCHITECTURE.md`,
standing rules in `AGENTS.md` (Android Studio reads it automatically; check that
it shows in the chat's Context drawer).

## How to use it

1. Open the repo folder in Android Studio and switch the Gemini panel to Agent mode.
2. Paste ONE task's **Prompt** block. Let the agent work, then read its diff.
3. Run the **Done when** checks yourself. If they hold, commit with the task id
   (`git commit -m "T04: login pages"`), then take the next task.
4. If a check fails, paste the error back to the agent in the same chat.

Nothing here has been compiled yet. The first `flutter analyze` and `flutter test`
in Android Studio are the real test of the existing skeleton.

## Run order

`T00 → T01 → T02 → T03 → T06 → T04 → T05 → T07 → T08 → T09 → T10 → T11 → T12 → T13 → T14 → T16 → T15 → T17 → T18 → T20 → T21 → T19`

| Task | What | Requirement |
|------|------|-------------|
| T00 | Remove the leaked service-account key, stop tracking `node_modules` | security |
| T01 | New app entry point, theme, correct Firebase project | brand |
| T02 | Router with role guard | FR-01, FR-02 |
| T03 | Auth repository and session | FR-01 |
| T04 | Login pages | FR-01 |
| T05 | Parent and teacher sign-up | FR-02 |
| T06 | Cloud Functions codebase `fyp` | all server rules |
| T07 | Admin creates admin | FR-03 |
| T08 | Parent creates student | FR-04 |
| T09 | Teacher courses and videos, publish gate | FR-07 |
| T10 | Playback with access check, free first video | FR-05 |
| T11 | One point per completed view | FR-06 |
| T12 | Subscription, payment, points grant, locked screen | FR-08, FR-10 |
| T13 | Student home | FR-06 |
| T14 | Block screenshots and recording on Android | FR-09 |
| T16 | Student ratings and comments | FR-11 |
| T15 | Teacher analytics | FR-11 |
| T17 | Security rules and emulator tests | all |
| T18 | Brand pass, icon, dark mode | brand |
| T19 | Deploy | — |
| T20 | Teacher and content approval workflows | FR-12, FR-13 |
| T21 | Arabic/English localization pass | FR-15 |

---

## T00 — Security cleanup (do this first, part of it is yours)

**Why:** the repo is public and its first commit contains a Firebase Admin
service-account key (`functions/bbc-api-tool-firebase-adminsdk-fbsvc-344ab63826.json`)
and 9,800 files of `node_modules`. Anyone can use that key against project
`bbc-api-tool`.

**Step 1, you, in the browser (the agent cannot do this):** Google Cloud console
→ project `bbc-api-tool` → IAM & Admin → Service Accounts →
`firebase-adminsdk-fbsvc@bbc-api-tool.iam.gserviceaccount.com` → Keys → delete
the key whose ID starts with `344ab63826`. Removing the file from the repo does
**not** make the key safe; only deleting the key does.

**Step 2, agent prompt:**

```text
Security cleanup, task T00. Do exactly this and nothing else:
1. Append these lines to .gitignore: node_modules/, .firebase/,
   serviceAccountKey.json, *adminsdk*.json, .env, .env.*
2. Run: git rm -r --cached node_modules .firebase functions/bbc-api-tool-firebase-adminsdk-fbsvc-344ab63826.json
3. In functions/migrateRoles.js, functions/checkRole.js and
   functions/makeSuperAdmin.js replace the service-account import and
   cert(serviceAccount) with applicationDefault() from firebase-admin/app.
   Change only those lines.
4. In grantSuperadmin.js do the same instead of require()-ing serviceAccountKey.json.
5. Do not delete anything from disk. Do not rewrite git history.
Show me the git status when done.
```

**Done when:** `git ls-files | findstr node_modules` prints nothing; the key
file is no longer tracked; `git grep private_key` finds nothing; the key is
deleted in the Cloud console.

---

## T01 — Runnable new app

**Needs:** T00.

```text
Task T01. Make the new app start. Follow AGENTS.md.
1. Run: flutterfire configure --project=future-youth-platform
   --platforms=android,ios,web,windows --out=lib/app/fyp_firebase_options.dart
   (do NOT touch lib/firebase_options.dart; its ios/macos/windows entries point to
   the old project bbc-api-tool).
2. Create lib/app/fyp_app.dart: class FypApp (a StatelessWidget, no Firebase
   calls inside) returning MaterialApp with title 'Future Youth Platform',
   theme FypTheme.light, darkTheme FypTheme.dark, themeMode system,
   debugShowCheckedModeBanner false, home a simple page with
   Image.asset('assets/logo.png') and the title.
3. Create lib/main_fyp.dart: WidgetsFlutterBinding.ensureInitialized,
   Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform) using
   lib/app/fyp_firebase_options.dart, then runApp(const FypApp()).
4. Replace test/widget_test.dart (it is the broken Flutter counter template and
   fails) with a test that pumps FypApp and finds the text 'Future Youth Platform'.
5. Run flutter pub get, then `flutter analyze` on the whole project and tell me
   how many issues were already there before my changes versus after.
```

**Done when:** `flutter run -t lib/main_fyp.dart -d edge` shows the logo on a
page; the app bar/buttons use navy `#263778`; `flutter test` passes (including
`test/fyp/video_access_policy_test.dart`).

---

## T02 — Router and role guard

**Needs:** T01. **FR-01, FR-02.**

```text
Task T02. Build the router with go_router.
1. lib/app/fyp_redirect.dart: a pure function
   String? fypRedirect({required String location, required bool signedIn,
   required UserRole? role}). Rules: signed out may open only '/', /login/<role>
   and /signup/parent|teacher; /signup/student and /signup/admin redirect to '/';
   signed in on '/', /login/* or /signup/* goes to FypRoutes.homeFor(role);
   a signed-in user may open only paths under their own role's prefix
   (/admin, /parent, /student, /teacher), otherwise go to their home;
   signed in with role == null goes to '/' .
2. lib/app/fyp_router.dart: GoRouter built from FypRoutes. Route builders:
   RoleSelectPage for '/', LoginPage(role) and SignupPage(role) with the role
   parsed by UserRole.tryParse (unknown role -> redirect to '/'),
   and the existing placeholder pages for the rest. Use refreshListenable so
   the redirect re-runs when the session changes. Take the session as a
   Listenable argument with signedIn and role getters; do not import Firebase here.
3. Switch FypApp to MaterialApp.router with a router built from a stub session.
4. test/fyp/fyp_redirect_test.dart: at least 12 cases covering every rule above.
```

**Done when:** the redirect tests pass; opening `/signup/admin` goes to `/`;
`flutter run -t lib/main_fyp.dart` shows the role-select page and each button
opens its login placeholder.

---

## T03 — Auth repository and session

**Needs:** T02. **FR-01.**

```text
Task T03. Create lib/features/auth/data/auth_repository.dart and
lib/features/auth/domain/auth_session.dart.
- AuthSession: uid?, role (UserRole?), displayName?, signedIn getter.
- AuthRepository (interface) and FirebaseAuthRepository: signIn(identifier,
  password), signOut(), Stream<AuthSession> sessionChanges().
  The role comes ONLY from the 'role' custom claim of the ID token
  (getIdTokenResult). After sign-in force a token refresh.
- Student sign-in uses a username: identifier -> '<username>@students.fyp.invalid'
  (see A-7 in docs/REQUIREMENTS.md). Other roles use the email as typed.
- signInAs(UserRole expected, ...): after sign-in compare the claim with
  'expected'. On mismatch sign out and throw RoleMismatchException.
- AuthController extends ChangeNotifier, exposes the session, and is the
  Listenable the router uses (T02). Wire it into FypApp with a simple
  InheritedWidget or constructor injection; add no new state-management package.
- Tests with a fake repository: mismatch signs out, student identifier mapping,
  claim parsing (unknown claim -> role null).
```

**Done when:** tests pass; signing in with a real test account of the wrong
role is refused with a clear message (verify after T06).

---

## T06 — Cloud Functions codebase `fyp`

**Needs:** T03. **All server-side rules.**

```text
Task T06. Create a separate Cloud Functions codebase so the old functions/ stay untouched.
1. Folder functions_fyp/: package.json ("type": "module", node 22,
   firebase-admin, firebase-functions), index.js, src/config.js (REGION: use the
   same region as the Firestore database; ask me which one), src/guards.js with
   requireRole(request, allowedRoles) that throws HttpsError 'unauthenticated' /
   'permission-denied' using request.auth.token.role.
2. Callable completeSignup({role}): accepts only 'parent' or 'teacher', only when
   the caller has no role claim yet. Sets the custom claim, writes
   users/{uid} {role, displayName, email, createdAt}. Return {ok:true}.
3. firebase.json: ADD a second entry to the "functions" array
   {"source":"functions_fyp","codebase":"fyp"} and an "emulators" block (auth 9099,
   firestore 8080, functions 5001, storage 9199, ui). Do not change anything else
   in firebase.json.
4. Use initializeApp() with no credentials (Application Default Credentials).
5. node:test unit tests for requireRole and for the role validation of completeSignup
   (extract the validation into a pure function).
```

**Done when:** `cd functions_fyp && npm test` passes;
`firebase emulators:start --only functions,auth,firestore` starts;
`firebase deploy --only functions:fyp` is the only deploy command used (never plain `firebase deploy`).

---

## T04 — Login pages

**Needs:** T03, T06. **FR-01.**

```text
Task T04. Replace the placeholder in lib/features/auth/presentation/login_page.dart.
One page, four roles. Header: the logo, 'Sign in as <Role>'. Fields: Email
(or Username for students), Password with a show/hide toggle. A filled navy
button with a progress state. Validate empty fields. Show errors inline for:
wrong password, user not found, RoleMismatchException ('This account is a
<other> account. Use the <other> login.'), network error. Show 'Create account'
only when role.canSelfSignUp. Add a back button to the role-select page.
Keep all strings in one const class in the same feature. Max content width 420.
Add widget tests: required fields, error shown on RoleMismatchException (fake repo),
sign-up link hidden for student and admin.
```

**Done when:** each of the 4 login pages opens; a parent account on the teacher
page is refused; after a valid login the router opens the role's home page.

---

## T05 — Parent and teacher sign-up

**Needs:** T04. **FR-02.**

```text
Task T05. Replace lib/features/auth/presentation/signup_page.dart.
Only for UserRole.parent and UserRole.teacher (the router already redirects other roles).
Fields: full name, email, password, confirm password. On submit:
createUserWithEmailAndPassword, call the completeSignup callable with the role,
force an ID-token refresh, then let the router redirect. If completeSignup fails,
delete the just-created Auth user and show the error. Add the method to the
auth repository interface and the fake. Widget tests: password mismatch,
failure path calls delete.
```

**Done when:** a new parent and a new teacher can sign up and land on their
home; `users/{uid}` exists with the right role; the token has the `role` claim.

---

## T07 — Admin creates admin

**Needs:** T06. **FR-03.**

```text
Task T07.
1. functions_fyp: callable createAdmin({displayName, email, password}).
   requireRole('admin'). Create the Auth user with the Admin SDK, set claim
   role='admin', write users/{uid}. Return {uid}. Must not sign the caller out.
2. functions_fyp/scripts/create_first_admin.js: a one-time script that creates the
   first admin using Application Default Credentials, taking email and
   password from command-line arguments. Never write them to disk.
3. lib/features/admin: replace admin_dashboard_page.dart (a card 'Create admin',
   sign-out) and create_admin_page.dart (the form, success message, error states).
   Put the callable call in features/admin/data/admin_repository.dart.
4. Tests: guard test for createAdmin (non-admin is refused), widget test for the form.
```

**Done when:** the first admin is created with the script; that admin creates a
second admin and stays signed in; a parent calling `createAdmin` gets
`permission-denied`.

---

## T08 — Parent creates student

**Needs:** T06. **FR-04.**

```text
Task T08.
1. functions_fyp: callable createStudent({displayName, username, password}).
   requireRole('parent'). Username: 3-20 chars, lowercase letters, digits, dot,
   underscore. Auth email = '<username>@students.fyp.invalid'. Set claim
   role='student', write users/{uid} with parentId = caller uid. Reject a taken
   username with 'already-exists'.
2. lib/features/parent: parent_dashboard_page.dart lists the parent's students
   (query users where parentId == uid), an 'Add student' button, and the
   subscriptions entry point (T12). create_student_page.dart is the form.
   Data access in features/parent/data/student_repository.dart.
3. Tests: username validation (pure function, many cases), guard test.
```

**Done when:** a parent creates a student; the student appears in the list; the
student can sign in on the Student login page with the username; a teacher
calling `createStudent` is refused.

---

## T09 — Teacher courses and videos

**Needs:** T06. **FR-07.**

```text
Task T09.
1. Models in features/course/domain: Course {id, teacherId, title, description,
   lessonCount, videoCount, status} and Video {id, title, order, durationSec}
   with fromMap/toMap and tests.
2. Add firebase_storage and file_picker to pubspec.yaml.
3. functions_fyp callables:
   - registerVideo({courseId, title, durationSec, storagePath}): caller must own
     the course; storagePath must start with 'uploads/<uid>/<courseId>/';
     in one transaction set order = videoCount + 1, create videos/{id} and
     video_sources/{id}, increment videoCount.
   - publishCourse({courseId}): owner only; fails with 'failed-precondition' unless
     videoCount >= lessonCount and lessonCount > 0 (FR-07).
4. UI: teacher_dashboard_page.dart lists own courses with a status chip; 'New
   course' form (title, description, lessonCount from the school book);
   course page: video list, 'Add video' (pick file, upload to Storage with a
   progress bar, then registerVideo), a green progress bar 'n of lessonCount videos',
   and a Publish button disabled until the minimum is met.
5. Tests: publish gate (pure function in functions_fyp/src), model tests.
```

**Done when:** a course with `lessonCount = 3` cannot be published with 2
videos and can with 3; the first video has `order = 1`.

---

## T10 — Playback and free first video

**Needs:** T09, T14 optional. **FR-05, FR-10.**

```text
Task T10.
1. functions_fyp callable getPlaybackUrl({courseId, videoId}). Load the caller's
   role, the subscription 'subscriptions/<uid>_<courseId>' and the video.
   Apply the same rules as decideVideoAccess in
   lib/features/video/domain/video_access_policy.dart (port them to a pure JS
   function with node:test tests that mirror test/fyp/video_access_policy_test.dart).
   If allowed: read video_sources, create a signed URL valid for 5 minutes, upsert
   video_views/<uid>_<videoId> with startedAt. If not: HttpsError
   'failed-precondition' with details {reason: 'payment_required' | 'no_points'}.
2. Add video_player to pubspec.yaml. Build video_player_page.dart: fetch the
   URL, play, handle loading and error states; for payment_required show the
   locked screen content, for no_points show 'No points left. Ask your parent to renew.'.
3. Call ScreenProtection.enable() in initState and disable() in dispose.
```

**Done when:** a subscribed student with 0 points can play the order-1 video and
is stopped on video 2; an unpaid student gets `payment_required` even for
video 1; the playback URL stops working after 5 minutes.

---

## T11 — One point per completed view

**Needs:** T10. **FR-06.**

```text
Task T11.
1. functions_fyp callable completeVideoView({courseId, videoId, watchedSeconds}).
   One Firestore transaction: read video_views/<uid>_<videoId>; if charged is
   already true return {charged:false}; require watchedSeconds >= 0.9 * durationSec;
   order-1 videos are never charged (set completedAt only); otherwise require
   subscription active and pointsBalance >= 1, then pointsBalance -= 1, append a
   points_ledger row {studentId, courseId, delta:-1, reason:'video_view', videoId},
   set charged:true and completedAt, and increment videos/<id>.viewCount.
   Extract the decision into a pure function; node:test cases: first call
   charges, second call does not, below 90% does not, zero balance refuses,
   free video never charges.
2. In the player, send completeVideoView once when 90% is reached; show
   'Done, 1 point used' and refresh the balance.
```

**Done when:** watching a paid video to 90% takes exactly 1 point; watching it
again takes none; the ledger shows one `-1` row.

---

## T12 — Subscription, payment, points grant, locked screen

**Needs:** T11. **FR-08, FR-10.** D-2: Egypt rails are Instapay, Vodafone Cash,
Orange Cash and Etisalat Cash. This task still builds the provider-neutral
record plus admin confirm; do not hard-wire a single PSP yet. Use
`PaymentProvider` for the stored name.

```text
Task T12.
1. functions_fyp:
   - createSubscriptionOrder({studentId, courseId, months}): parent only; the
     student must belong to the parent; the course must be published. Create
     payments/<id> {status:'pending', amount from course price (add a price
     field), provider:'manual'} and make sure subscriptions/<studentId>_<courseId>
     exists (status 'pending' if new).
   - confirmPayment({paymentId}): admin only. One transaction: if payment is
     already 'paid' do nothing; else mark paid, set the subscription 'active',
     extend endsAt by 'months', add videoCount x months to pointsBalance
     (PointsPolicy.pointsForSubscription, A-3), append a points_ledger row
     {reason:'subscription_grant', paymentId}. Pure function + node:test
     (idempotent on repeat, renewal adds points and extends the date).
2. Parent: subscription_page.dart: choose student, course and months, then
   'Pay'. Show pending and paid payments.
3. Admin: a 'Pending payments' list with a Confirm button (temporary until Q-2 is answered).
4. Student: payment_locked_page.dart. Listen to the student's subscriptions
   (snapshots). No active subscription: only the loading screen, nothing else.
   When one becomes active the router sends the student home, with no restart.
   Extend AuthSession with hasActiveSubscription and use it in fypRedirect:
   a student without one is redirected to FypRoutes.studentLocked.
```

**Done when:** an unpaid student sees only the loading screen; the admin
confirms the payment; the student's screen changes by itself within a few
seconds; the balance equals `videoCount x months`; confirming twice grants once.

---

## T13 — Student home

**Needs:** T12. **FR-06.**

```text
Task T13. Replace student_home_page.dart. For each active subscription show the
course, the teacher name, the points balance (green progress meter: points left
vs points granted) and the end date. Tapping a course lists its videos in
order; video 1 has a 'Free' chip, a video with no points available shows a lock
icon. Tapping opens FypRoutes.studentVideoFor. Read from Firestore only; no writes.
Widget tests with fake data for: free chip, lock icon at zero points, empty state.
```

**Done when:** the free chip is on video 1 only; the balance matches the ledger.

---

## T14 — Block screenshots and recording (Android)

**Needs:** T01. **FR-09.**

```text
Task T14. Implement the native side for lib/core/security/screen_protection.dart.
Replace android/app/src/main/kotlin/com/example/future_youth_platform/MainActivity.kt
with exactly this (this task names that file; change nothing else):

package com.example.future_youth_platform

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fyp/screen_protection")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

Then add a widget test that mocks the channel and checks 'enable' and 'disable'
are sent, and that nothing is sent on the web (kIsWeb).
```

**Done when:** on an Android device or emulator, with the player open, the
screenshot gesture says it is blocked, the Recents thumbnail is blank and a
screen recording shows black; on any other page screenshots work normally.
iOS needs a Mac (hide the player while `UIScreen.isCaptured`) and is left for later. The web cannot do this (Q-6).

---

## T16 — Student ratings and comments

**Needs:** T10. **FR-11.**

```text
Task T16.
1. Below the player: a 1-5 star rating (writes ratings/<uid>) and a comment box
   (writes comments with createdAt = server timestamp). Both only for a student
   with an active subscription. Show the student's own rating, and the latest comments.
2. functions_fyp Firestore triggers: on rating write update ratingSum and
   ratingCount on the video (handle create, change and the old value);
   on comment create/delete update commentCount. Pure function for the rating
   delta with node:test cases.
```

**Done when:** rating a video 4 then changing it to 2 leaves `ratingSum = 2`,
`ratingCount = 1`; deleting a comment lowers `commentCount`.

---

## T15 — Teacher analytics

**Needs:** T11, T16. **FR-11.**

```text
Task T15. Replace course_analytics_page.dart. For the teacher's own course show
a table: video title, average rating (ratingSum / ratingCount, '-' when none),
rating count, comment count, views (viewCount). Totals row on top. Tap a video to
open its comments, newest first. Use the green only for the rating stars and
the selected row. Add a link to this page from each course in the teacher dashboard.
Read only; no writes. Tests: average calculation with zero ratings, sort order.
```

**Done when:** a teacher sees the numbers for their own course and gets
`permission-denied` for another teacher's course.

---

## T17 — Security rules and emulator tests

**Needs:** T16.

```text
Task T17.
1. Replace the contents of firestore.rules with docs/proposed/firestore.rules.
   This task names that file. Do NOT keep the old isSuperAdmin() function: it
   contains a hard-coded personal email address.
2. Create storage.rules: deny all client reads of 'uploads/**'; a signed-in
   teacher may write only to 'uploads/<own uid>/**', max 2 GB, content type video/*.
   Reference it in firebase.json.
3. Install @firebase/rules-unit-testing in functions_fyp and write
   functions_fyp/test/rules.test.js. Required cases: student cannot write
   subscriptions, payments, points_ledger, video_views, video_sources;
   student cannot change users/<uid>.role; teacher cannot read another
   teacher's draft course; teacher cannot set status 'published' from the client;
   parent cannot read another parent's students; comment needs an active
   subscription; rating value 6 is refused; unauthenticated reads are refused.
4. Run the tests with: firebase emulators:exec --only firestore,storage "npm test"
```

**Done when:** all emulator tests pass. Fix the rules, not the tests, if one fails.

---

## T18 — Brand pass

```text
Task T18.
1. Add flutter_launcher_icons (dev dependency), configure it with assets/logo.png
   on a navy #263778 background, and generate the icons. Set the native splash
   color to #263778.
2. Check every page in light and dark mode: no hex colors in widgets (search
   for '0xFF' under lib/features), no white text smaller than 18 px on a green
   fill, focus rings visible, text scales at 200% without overflow.
3. Replace every remaining PlaceholderPage; delete core/widgets/placeholder_page.dart
   only when nothing uses it.
```

**Done when:** a search for `Color(0xFF` under `lib/features` finds nothing;
`PlaceholderPage` is unused.

---

## T19 — Deploy

```text
Task T19.
1. flutter build web -t lib/main_fyp.dart --release
2. Hosting: the target 'master' in .firebaserc serves build/web. Run
   firebase deploy --only hosting
3. Functions: firebase deploy --only functions:fyp  (never plain `firebase deploy`).
4. In the Firebase console add the hosting domain to Authentication > Settings >
   Authorized domains, and turn on App Check for Firestore, Storage and Functions.
5. Build an Android release APK: flutter build apk --release, and test the
   screenshot block (T14) on a real phone.
```

**Done when:** the hosted site loads, a parent can sign up and a teacher can
publish a course end to end, and the rules tests still pass.


---

## T20 — Teacher and content approval

```text
Task T20. Implement the approval lifecycle using the existing field name
`approvalStatus` (do not introduce a second field named `approval`).

1. In functions_fyp/completeSignup, a first-time teacher is created with
   approvalStatus='pending'. A caller with any existing role claim or stored
   users/{uid}.role cannot change role through completeSignup.
2. Add Admin-only callables to approve/reject teacher profiles and submitted
   course/video content. Validate all input server-side and store
   reviewedBy, reviewedAt, and rejectionReason. Do not let the client write
   approvalStatus or published status directly.
3. Teacher sign-up UI clearly says that approval is required. Pending/rejected
   teachers can edit their own draft profile but cannot publish content.
4. Student discovery and video queries return only approved teachers and
   approved content. Add Firestore rules and emulator tests for each case.
5. Use existing AppLocalizations for every new string in English and Arabic.
```

**Done when:** a new teacher is pending; only an Admin can approve/reject;
pending/rejected teachers are not visible to students and cannot publish;
approval and rejection metadata are recorded; tests cover both allowed and
denied paths.

## T21 — Complete Arabic/English localization

```text
Task T21. Extend the existing AppLocalizations in lib/services/localization_service.dart.
Do not add a second localization framework or replace the existing locale
preference.

1. Move all new Future Youth screen labels, validation messages, dialogs,
   empty/error/loading states and payment/approval labels into the existing
   English and Arabic maps.
2. Make the Future Youth screens respect the active locale, including RTL
   layout in Arabic and LTR in English.
3. Add tests for representative English and Arabic strings and locale direction.
4. Keep the old operations code intact except where a shared app-level string
   is necessary; do not regress the existing application entry points.
```

**Done when:** the Future Youth authentication, teacher, parent, student and
Admin workflows contain no newly hard-coded user-facing strings; English and
Arabic both render without overflow; locale tests pass.
