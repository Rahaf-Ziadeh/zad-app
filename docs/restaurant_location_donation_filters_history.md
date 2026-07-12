# Restaurant Location, Donation, Offer Filtering, and History Features

## Feature Name

موقع المطعم، التبرع للجمعيات، فلترة العروض، وسجلّ الشكاوى والتقييمات — Restaurant Location Selection, Restaurant-to-Charity Donation, Restaurant Offer Status Filtering, Restaurant Complaints and Ratings History

## Actor

**Restaurant** (role: `restaurant`)

---

## 1. Restaurant Location Selection

### Problem

The restaurant profile address and the offer pickup location could only be typed manually. `AddOfferScreen` already had a working map picker; `RestaurantProfileScreen` and `EditOfferScreen` did not, so restaurants had no consistent way to pick a location from the map or use their current GPS position across all three screens.

### Implementation

- Reused the existing `LocationPickerScreen` (OpenStreetMap / `flutter_map`) and `LocationService` (Geolocator + Nominatim reverse geocoding) everywhere — **no second map picker was created**.
- Added a single shared widget, `LocationPickerRow` (in `restaurant_widgets.dart`), that shows either "اختيار الموقع من الخريطة / استخدام موقعي الحالي" (no location yet) or the resolved coordinates with a clear (✕) button. Used identically in:
  - `RestaurantProfileScreen` (new, edit-mode only)
  - `AddOfferScreen` (refactored from an inline duplicate `Container` to the shared widget — same behavior)
  - `EditOfferScreen` (new — this screen previously had no location picker at all)
- When the map picker returns a result, the resolved address text fills the manual text field automatically — the restaurant never has to retype it. Manual editing of that text field remains available as a fallback at all times.

### Firestore Fields

Written to `restaurants/{uid}` (profile) and `offers/{offerId}` (add/edit offer), identically:

| Field | Type | Notes |
|---|---|---|
| `latitude` | number/null | null if never set |
| `longitude` | number/null | |
| `hasLocation` | bool | `true` only when both lat/lng are present |
| `locationSource` | string | `'gps'`, `'map'`, or `'manual'` |
| `address` (profile) / `pickupLocation` (offer) | string | always kept, editable manually as a fallback |

### Backward Compatibility

Existing restaurant/offer documents without these fields load with `_latitude`/`_longitude` = `null` and `locationSource` = `'manual'` — the screens behave exactly as before until the restaurant explicitly picks a location.

---

## 2. Restaurant-to-Charity Donation

### Problem

Restaurants had no shortcut to donate surplus food directly to a charity — only charities could publish surplus, and only regular users could donate to a charity.

### Implementation

- New screen: `RestaurantDonateToCharityScreen` (`lib/screens/restaurant/restaurant_donate_to_charity_screen.dart`).
- New home shortcut: "تبرع لجمعية" `ActionTile` on `RestaurantHomeScreen`, opened via direct `Navigator.push` (same pattern as the existing "مسح رمز الاستلام" tile).
- Reuses, rather than duplicates:
  - `CharityPickerSheet` — promoted from a private widget (`_CharityPickerSheet`) inside `donate_tab.dart`'s `CharityDonationScreen` to a public one, so both the user donation flow and this new restaurant flow share the exact same charity-selection UI and Firestore query (`users` where `role == 'charity'`, `status == 'active'`, `isApproved == true`). The existing user donation flow is unchanged — only the class visibility changed.
  - `CloudinaryService` for the single image upload.
  - `LocationPickerScreen` / `LocationPickerRow` for pickup location.
  - `NotificationService().sendNotification()` to notify the selected charity.
- **Business rule enforced**: the form has no mystery/hidden-content option at all — it is structurally clear-content only (title, description, category, quantity, image are always shown to the charity).

### Firestore Fields (`donations` collection)

Written with the exact contract already used by the user-to-charity flow (`donate_tab.dart`), plus two new additive fields to identify the source:

| Field | Notes |
|---|---|
| `donorUserId`, `donorName` | restaurant's uid/name |
| `donorRole` | `"restaurant"` (new field; old readers ignore it) |
| `restaurantId` | = `donorUserId` (new field, explicit) |
| `charityId`, `charityName` | required — restaurant must pick a charity |
| `title`, `description`, `category`, `quantity`, `imageUrl` | |
| `pickupLocation`, `latitude`, `longitude`, `hasLocation`, `locationSource` | |
| `pickupStartTime`, `pickupEndTime`, `pickupTime` | |
| `status` | `"pending"` |
| `createdAt`, `updatedAt` | |
| `userId`, `userName`, `foodName`, `location`, `notes`, `targetCharityId`, `targetCharityName` | legacy field names kept in parallel so existing charity-side screens (`CharityDonationsScreen`, `CharityPublishSurplusScreen`) that read these directly continue to work unmodified |

### Navigation

`RestaurantHomeScreen` → "تبرع لجمعية" → `RestaurantDonateToCharityScreen` (pushed on the Home tab's own Navigator, bottom navigation stays visible).

### Backward Compatibility

No existing `donations` documents are touched. The charity-side review/approval/redistribution screens were not modified — they already read the same field names this new form writes.

---

## 3. Restaurant Offer Status Filtering

### Problem

The "منتهية" (expired) tab in `RestaurantOffersScreen` was noticeably slower than the others.

### Root Cause

Every tab re-derived each offer's expiry/status from scratch on every rebuild (`isOfferExpired`/`effectiveOfferStatus` called once per filter tab **and again** for the card badge — up to 5× per document per Firestore snapshot). Expired offers are never archived or deleted, so they accumulate and form the largest tab over time — the redundant recomputation cost scaled with that tab's size, making it the most noticeably slow one. There was **no per-card Firestore read and no nested `FutureBuilder`** — the slowdown was pure redundant CPU work, not I/O.

A second, independent bug was found while fixing this: the query used `.where('providerUserId', ...).orderBy('createdAt', descending: true)`. Firestore **excludes from the result set entirely** any document missing the `orderBy` field — any offer without `createdAt` would silently vanish from every tab, not just sort last.

### Fix

- Added `_OfferEntry`, computed once per document per snapshot (`expired`, `remaining`, `effective` status, `badgeStatus`, `createdAtMillis`), consumed by all 5 tabs and the card badge — status is now computed exactly once instead of up to 5 times.
- Removed `.orderBy('createdAt', ...)` from the Firestore query entirely (query is now a single equality filter — **no composite index required**), and added an explicit client-side sort (`_compareNewestFirst`): newest first, any document with a missing/invalid `createdAt` is placed **at the end** instead of being silently dropped.
- `snapshot.hasError` and the loading state were already handled; both were kept as-is.

### Closed Offers Verification

Confirmed the exact status string used project-wide by reading `offer_actions.dart`'s `toggleOfferStatus`: an offer is closed by setting `status: 'closed'` (not `completed`/`inactive`/`cancelled`/`sold_out` — those strings are never written anywhere). The "مغلقة" filter correctly checks `effective == 'closed'`. "نفدت الكمية" (`sold_out`) is a separate, already-correct condition: any non-expired offer with `remainingQuantity <= 0`. If a restaurant has no closed offers, the tab shows the existing empty state ("لا توجد عروض هنا") — never an infinite spinner.

### Firestore Index Required

**None** — the query is now a single-field equality filter (`providerUserId`), which Firestore auto-indexes. No composite index needs to be created or reported.

---

## 4. Restaurant Complaints and Ratings History

### Problem

Restaurants had no way to review complaints related to their business or the ratings/reviews they've received.

### Implementation

Two new screens, entries placed at the bottom of `RestaurantProfileScreen` (chosen over Home because Profile already hosts the license/verification/account-status cards — the most consistent place for another read-only administrative list, per the existing navigation architecture).

#### A. `RestaurantComplaintsHistoryScreen`

- Query: `complaints.where('reportedUserId', isEqualTo: uid)` — the restaurant as the **reported/provider** account.
- Field verified against the actual schema (not guessed): `reportedUserId` is written by `_ReportProviderDialog` in `provider_public_profile_screen.dart` whenever a user reports a restaurant from its public profile. This is the real, already-existing "restaurant is the reported account" field — no new field was invented.
- Displays: complaint type, description, complainant name (`userName`, already denormalized on the complaint document), related offer/reservation ID if present, status, `createdAt`, resolution note, `resolvedAt`.
- Sorted newest first client-side (same missing-`createdAt`-goes-last rule as offers, and for the same reason: no `orderBy` in the query, so no composite index is needed and no document is silently excluded).
- Tapping a row opens a read-only detail screen. No resolve/reopen/delete actions are exposed — those remain admin-only in `AdminComplaintDetailsScreen`.
- Reuses `ComplaintSectionCard` / `ComplaintInfoRow`, promoted from private classes inside `admin_complaint_details_screen.dart` to public ones (rename + `super.key` only — the admin screen's own behavior is unchanged).

#### B. `RestaurantReviewsScreen`

- Query: `reviews.where('providerUserId', isEqualTo: uid)` — same field and collection already used by `provider_public_profile_screen.dart` to display a provider's reviews to users.
- Displays: star rating, comment, reviewer name, offer title, reservation ID ("رمز الحجز") if present, `createdAt`.
- Summary card: average rating + total review count, computed from the same snapshot (no extra reads).
- Tapping a review looks up its `offerId` and opens `RestaurantOfferDetailsScreen` if the offer still exists; otherwise shows "هذا العرض لم يعد متوفرًا" instead of failing silently.
- All fields are read with null-safe fallbacks (`as num?`, `as String? ?? ''`) so reviews written before any of these fields existed do not crash the screen.

### Navigation

`RestaurantProfileScreen` → new card with two `ListTile`s: "سجل الشكاوى" and "التقييمات والآراء", placed directly above the existing "تغيير كلمة المرور" card. The bottom navigation bar (5 tabs) was not changed.

---

## 5. Role-Aware Chatbot Architecture

### Problem

The individual-user chatbot (`ChatbotScreen`) was a single-role widget with a hardcoded welcome message, chip list, and if/else intent chain. Restaurants needed their own assistant (publishing offers, managing reservations, donating surplus, reviewing complaints/ratings) without forking the screen into a second, duplicated implementation.

### Design: shared screen, role-driven config

- **One screen, one widget tree**: `ChatbotScreen` (`lib/screens/user/chatbot_screen.dart`) is unchanged in structure — same `_ChatMessage`/`_MessageBubble`/`_QuickChip`/`_TypingIndicator`/`_InputBar` widgets, same layout. No `if (role == restaurant)` branching inside `build()`.
- **Role passed explicitly via constructor**: `ChatbotScreen(userRole: 'individual' | 'restaurant', ...)`. No extra Firestore read is needed to determine role — callers already know it (`UserDashboard` always passes `'individual'`, `RestaurantDashboard` always passes `'restaurant'`).
- **All role-varying content lives in data, not code**: `lib/screens/user/chatbot_role_config.dart` defines:
  - `ChatbotRole` enum (`individual`, `restaurant`) with `chatbotRoleFromString()` — any unrecognized string safely falls back to `individual`.
  - `ChatbotRoleConfig` — welcome message, default suggested chips, fallback message, and an ordered list of `ChatbotIntent`s (id, exact-match phrases, keyword list, reply text or navigation action id, follow-up chips).
  - `individualChatbotConfig` and `restaurantChatbotConfig` — the two concrete configs.
  - `resolveIntent({role, message})` — a pure function (no `BuildContext`): normalizes Arabic input, checks exact chip matches first, then keyword matches, in list order, and returns a `ChatbotResponse` (text+chips, or a navigation action id) or `null` on no match.
- **Context-dependent behavior stays in the screen, not the config**: the async "nearest offers" GPS/Firestore lookup and the multi-step "contact admin" sub-flow (category selection → support chat creation) remain special-cased in `_ChatbotScreenState`, dispatched by a small `_dispatchNavigation(actionId)` switch. This keeps `chatbot_role_config.dart` a pure data/matching layer, satisfying the "shared resolver" requirement without forcing stateful logic into it.

### Individual behavior — preserved exactly

`individualChatbotConfig` reproduces the original welcome message, the original 7 default chips, the original fallback message, and the original intent priority order (reserve_offer → nearby_offers → browse_offers_vs_packages → cancel_reservation/qr_help → contact_admin → nav-only intents) verbatim. No restaurant chip or intent is reachable from `userRole: 'individual'`.

### Restaurant intents — added

`restaurantChatbotConfig` welcome/fallback messages and its 13 suggested questions match the spec exactly, covering: publish_offer, publish_mystery_package, edit_offer, delete_offer, reservation_management, pickup_confirmation, qr_scan, offer_visibility, location_help, allergy_help, charity_donation, reviews_history, complaints_history, contact_admin. The `contact_admin` keyword list deliberately omits `اداره` (present for the individual config) to avoid colliding with restaurant "إدارة العروض" free text — a real collision found and fixed while building this config.

### Navigation mapping

| Action id | Individual target | Restaurant target |
|---|---|---|
| `kNavOffers` | offers tab | `RestaurantOffersScreen` tab |
| `kNavPackages` | packages tab | — |
| `kNavOrders` | my orders tab | reservations tab |
| `kNavDonate` | donate tab | — |
| `kNavAddOffer` | — | `AddOfferScreen` tab |
| `kNavScanQr` | — | `ScanQrScreen` (pushed directly) |
| `kNavDonateToCharity` | — | `RestaurantDonateToCharityScreen` (pushed directly) |
| `kNavReviews` | — | `RestaurantReviewsScreen` (pushed directly) |
| `kNavComplaints` | — | `RestaurantComplaintsHistoryScreen` (pushed directly) |
| `kNavNotifications` | user `NotificationsScreen` | common `NotificationsScreen` with `onOpenRelated: openRestaurantRelatedNotification` |
| `kNavContactAdmin` | support chat sub-flow | support chat sub-flow (same code path) |

All targets are existing screens reached via `Navigator.pop` + tab-switch callback (for bottom-nav destinations) or direct `Navigator.push` (for screens with no tab) — no destination screen was duplicated.

### Support-chat integration

- `RestaurantDashboard` adds a `FloatingActionButton` labeled "مساعد المطعم" (chat icon) positioned as the default single FAB — no overlap with the bottom nav, since the restaurant dashboard had no other floating action button.
- The contact-admin sub-flow calls `SupportService().createSupportChat(userId, userName, userRole, userEmail, issueCategory)`, so `support_chats` docs now carry `userRole` (`individual`/`restaurant`) alongside the pre-existing fields (`status: 'waiting'`, `unreadForAdmin: true`, `lastMessage`, `lastMessageAt`, `createdAt`, `updatedAt`).
- New `SupportService.findOpenChatId(userId)` is checked before creating a chat; if the user already has a non-closed chat, the bot reuses it (offers "فتح المحادثة" instead of creating a duplicate).
- `AdminSupportPanel`'s `_AdminChatCard` and `AdminSupportChatScreen`'s app bar both show a small role badge (مستخدم / مطعم / جمعية) next to the requester's name, driven by the same `userRole` field, so admins can tell individual and restaurant support requests apart at a glance without opening the chat.

### Testing Performed

- `flutter analyze`: 0 new issues across all changed/added files (`chatbot_role_config.dart`, `chatbot_screen.dart`, `user_dashboard.dart`, `restaurant_dashboard.dart`, `restaurant_home_screen.dart`, `support_service.dart`, `admin_support_panel.dart`, `admin_support_chat_screen.dart`); only the 2 pre-existing unrelated info-level lints remain project-wide.
- Verified by reading `chatbot_role_config.dart` intent lists side-by-side with the spec that all 13 restaurant chips/intents and the exact welcome/fallback strings (both roles) match verbatim.
- Verified the individual intent list preserves the original if/else priority order and that no restaurant-only chip/intent leaks into `individualChatbotConfig`.
- Verified `RestaurantHomeScreen`'s notification-opening logic was extracted to a top-level `openRestaurantRelatedNotification()` function (from a private instance method) so both the app-bar bell and the new chatbot "فتح الإشعارات" action share one implementation instead of duplicating the reservation/pickup/offer/account switch-case.
- Could not perform an interactive device/emulator walkthrough in this environment — the 14-item manual testing checklist (both roles' welcome message, chip lists, each intent's reply text, each navigation button, contact-admin dedup, admin role badges) should be re-run against a real Firebase project with a seeded restaurant account before release.

---

## Testing Performed

- `flutter analyze`: 0 issues introduced (2 pre-existing, unrelated info-level lints remain: a file-naming convention notice on `WelcomeScreen.dart` and a missing-`key` notice on an unrelated charity screen).
- Traced every new/changed Firestore query by hand against the actual schema (via `git show`/`grep` on the real write sites) rather than assuming field names.
- Verified no other screen was broken: `restaurant_reservations_screen.dart`, `scan_qr_screen.dart`, `qr_code_screen.dart`, notification screens, and the reservation/payment flow were not touched (confirmed via `git diff --stat`).
- Could not perform an interactive device/emulator walkthrough in this environment (no seeded restaurant/charity test accounts or browser-automation tooling available in this session) — the checklist above should be re-verified manually against a real Firebase project before release, particularly the end-to-end donation submission → charity notification path.
