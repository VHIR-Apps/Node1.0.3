/// lib/config/firestore_leaderboard_setup_guide.dart
///
/// HabitNode — Firestore Leaderboard Setup Guide
///
/// This file is a developer reference to configure Firestore safely and
/// Play-policy friendly. It is NOT shown to users.
///
/// ---------------------------------------------------------------------------
/// 1) Collections
/// ---------------------------------------------------------------------------
/// A) Public leaderboard user documents:
///   collection: leaderboard_v1_users
///   docId: uid (FirebaseAuth uid)
///
/// B) Reports (UGC moderation):
///   collection: leaderboard_v1_reports
///   docId: auto
///
/// Optional (future):
///   - leaderboard_v1_blocks (server-managed global blocks)
///
/// ---------------------------------------------------------------------------
/// 2) Fields used by current app code (leaderboard_v1_users/{uid})
/// ---------------------------------------------------------------------------
/// Required / common:
/// - schemaVersion (number)
/// - uid (string)
/// - displayName (string)
/// - avatarEmoji (string)
/// - avatarIndex (number)
/// - tagline (string | null)
/// - bio (string | null)
/// - countryCode (string | null)
/// - joinedAtMs (number)
/// - isOptedIn (bool)
/// - showLevel (bool)
/// - showBadges (bool)
/// - showStudyHours (bool)
/// - level (number)
/// - badgesUnlocked (number)
/// - studyHours (number)
/// - score (number)
/// - createdAtMs (number)
/// - createdAtIso (string)
/// - updatedAt (timestamp)
/// - updatedAtMs (number)
///
/// Server/admin-managed only (do not allow client to set these to true):
/// - isInterviewUser (bool)   // "Crown user" / verified interview user
/// - isProVerified (bool)     // secure Pro crown (recommended; server only)
/// - profileThemeIndex (number)  // can be client-managed if you want, but keep safe
///
/// ---------------------------------------------------------------------------
/// 3) Composite Index (CRITICAL)
/// ---------------------------------------------------------------------------
/// The app queries:
///   where isOptedIn == true
///   orderBy score desc
///   orderBy updatedAtMs desc
///
/// Create composite index in Firebase Console:
/// - Collection: leaderboard_v1_users
/// - Fields:
///     isOptedIn Asc
///     score Desc
///     updatedAtMs Desc
///
/// Without this index, Firestore will throw an index error.
/// ---------------------------------------------------------------------------
/// 4) Security Rules (Recommended)
/// ---------------------------------------------------------------------------
/// Goals:
/// - Anyone can read leaderboard (public ranking).
/// - Only signed-in users can write.
/// - Users can only create/update/delete their own uid document.
/// - Client must not set server-only flags like isInterviewUser/isProVerified.
///
/// IMPORTANT:
/// - Server-side writes (Cloud Functions / Admin SDK) bypass rules.
///   Use that for setting isInterviewUser/isProVerified.
///
/// Example rules:
///
/// rules_version = '2';
/// service cloud.firestore {
///   match /databases/{database}/documents {
///
///     // Public leaderboard docs
///     match /leaderboard_v1_users/{userId} {
///       allow read: if true;
///
///       allow create: if request.auth != null
///                     && request.auth.uid == userId
///                     // Prevent client from creating crown/pro flags
///                     && (request.resource.data.isInterviewUser == false
///                         || !('isInterviewUser' in request.resource.data))
///                     && (request.resource.data.isProVerified == false
///                         || !('isProVerified' in request.resource.data));
///
///       allow update: if request.auth != null
///                     && request.auth.uid == userId
///                     // Prevent client from flipping crown/pro flags
///                     && (
///                       !('isInterviewUser' in request.resource.data)
///                       || request.resource.data.isInterviewUser == resource.data.isInterviewUser
///                     )
///                     && (
///                       !('isProVerified' in request.resource.data)
///                       || request.resource.data.isProVerified == resource.data.isProVerified
///                     );
///
///       allow delete: if request.auth != null && request.auth.uid == userId;
///     }
///
///     // Reports (UGC moderation)
///     match /leaderboard_v1_reports/{reportId} {
///       allow create: if request.auth != null;
///       allow read: if false;   // reports are private
///       allow update, delete: if false;
///     }
///   }
/// }
///
/// ---------------------------------------------------------------------------
/// 5) Play Policy / UGC Compliance Checklist
/// ---------------------------------------------------------------------------
/// - Leaderboard is opt-in: Users must explicitly enable isOptedIn=true.
/// - Opt-out supported: isOptedIn=false hides from public ranking.
/// - Delete cloud profile supported: delete /leaderboard_v1_users/{uid}.
/// - Report feature supported: writes to leaderboard_v1_reports.
/// - Block feature supported: local blocklist (device-side).
/// - No photo upload: avatarIndex/emoji only (reduces cost & moderation risk).
///
/// ---------------------------------------------------------------------------
/// 6) Secure "Pro Crown" Strategy (IMPORTANT)
/// ---------------------------------------------------------------------------
/// Problem:
/// - If the client writes "isPro" to Firestore, users can fake it.
///
/// Recommended secure approach:
/// - Use server/admin to set isProVerified=true.
/// - Client only reads isProVerified and displays a Pro crown.
/// - Keep local Pro logic for app features using PurchaseService + DatabaseService.
///   That is separate from public verified crown.
///
/// Minimal low-cost approach:
/// - Only use isInterviewUser crown (admin-managed) for public.
/// - For Pro crown: show it only for the local current user in UI (not global).
///
/// ---------------------------------------------------------------------------
/// This guide should match the current production code.
/// If you change the leaderboard schema, bump schemaVersion and write a
/// migration plan.
///
class FirestoreLeaderboardSetupGuide {
  const FirestoreLeaderboardSetupGuide._();

  static const String summary = 'Firestore rules + indexes + compliance guide for HabitNode leaderboard.';
}