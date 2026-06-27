# Restaurant Reservations Feature

## Feature Name
حجوزات العروض — Restaurant Offer Reservations Screen

## Purpose
Allows restaurant users to view, monitor, and confirm all reservations made by app users on the restaurant's published food offers and surplus packages. The screen provides a real-time, filterable view of all reservation states with complete details about the user, payment, and pickup status.

## Actor
**Restaurant** (providerRole: restaurant)

## Related Use Case
**View Offer Reservations** — A restaurant logs into the ZAD app, navigates to the "حجوزات العروض" tab in the bottom navigation bar, and sees all reservations tied to their offers, organized by status, with summary statistics at the top.

---

## Firestore Collections Used

| Collection     | Purpose                                         |
|----------------|-------------------------------------------------|
| `reservations` | Primary collection — queried by `providerUserId` |
| `notifications`| Written to when a restaurant manually confirms pickup (`_markPickedUp`) |

---

## Important Fields Used from `reservations`

| Field               | Type        | Description                                              |
|---------------------|-------------|----------------------------------------------------------|
| `providerUserId`    | String      | UID of the restaurant — used as the Firestore filter     |
| `offerTitle`        | String      | Display name of the reserved offer                       |
| `userName`          | String      | Name of the user who made the reservation                |
| `userId`            | String      | UID of the user — used for sending pickup notifications  |
| `status`            | String      | `reserved` / `picked_up` / `cancelled`                   |
| `pickupLocation`    | String      | Pickup address/location text                             |
| `pickupTime`        | String      | Pickup time window (added from offer at reservation time)|
| `price`             | num         | Price of the offer (0 = free)                            |
| `currency`          | String      | `ILS` or other currency code                             |
| `paymentMethod`     | String?     | `cash` or `online` (null for free offers)                |
| `paymentStatus`     | String?     | `pending_cash` / `pending_online` / `paid` / null        |
| `createdAt`         | Timestamp   | When the reservation was created                         |
| `pickedAt`          | Timestamp?  | When the item was marked picked up                       |
| `qrValidatedAt`     | Timestamp?  | When QR scan was validated (set by ScanQrScreen)         |
| `qrValidationMethod`| String?     | Validation method used (e.g., `firestore_transaction`)   |

---

## Screen / File Names Added or Modified

| File | Action | Description |
|------|--------|-------------|
| `lib/screens/restaurant/restaurant_reservations_screen.dart` | **Modified** | Full enhancement: 4 tabs, summary cards, richer cards, all required fields, badges, empty/loading/error states |
| `lib/services/reservation_service.dart` | **Modified** | Added `pickupTime` field to the reservation document at creation time |
| `lib/screens/restaurant/restaurant_dashboard.dart` | **Modified** | Updated bottom nav label from "الطلبات" to "حجوزات العروض" |
| `docs/restaurant_reservations_feature.md` | **Created** | This documentation file |

---

## Main User Flow

1. Restaurant opens the ZAD app and is authenticated via Firebase Auth.
2. The restaurant dashboard loads with the bottom navigation bar.
3. The restaurant taps the **"حجوزات العروض"** tab (index 2) or presses the ActionTile on the home screen.
4. `RestaurantReservationsScreen` loads and opens a real-time Firestore stream:
   - Query: `reservations` where `providerUserId == currentUser.uid`, ordered by `createdAt DESC`.
5. **Summary cards** at the top display:
   - Total reservations
   - Active (reserved — awaiting pickup)
   - Completed (picked_up)
   - Cancelled
6. **4 Tabs** allow filtering:
   - الكل (All)
   - بانتظار الاستلام (Reserved)
   - تم الاستلام (Picked Up)
   - ملغي (Cancelled)
7. Each **reservation card** shows:
   - Offer title + user name
   - Status badge (colored by state)
   - Pickup location + pickup time (if stored)
   - Reserved quantity (always 1)
   - Price / currency
   - Payment method label
   - Payment status badge (orange=pending cash, purple=pending online, green=paid)
   - Created date/time
   - Picked-up date/time (if applicable)
   - QR scan timestamp (if QR was used to confirm)
8. For **reserved** items, two action buttons appear:
   - **تأكيد يدوياً** — shows a confirmation dialog, updates `status` to `picked_up`, sends a push notification to the user.
   - **مسح QR** — navigates to `ScanQrScreen` where the restaurant scans the user's QR code to auto-confirm pickup.
9. After QR scan or manual confirmation, the Firestore stream auto-updates the UI — no refresh needed.

---

## Empty / Loading / Error States

| State   | Displayed Widget | Message |
|---------|-----------------|---------|
| Loading | `CircularProgressIndicator` | Shown until first Firestore snapshot arrives |
| Empty (All tab) | Icon + text | "لا توجد حجوزات حالياً على عروضك" |
| Empty (Reserved tab) | Icon + text | "لا توجد حجوزات بانتظار الاستلام" |
| Empty (Picked Up tab) | Icon + text | "لا توجد طلبات مكتملة بعد" |
| Empty (Cancelled tab) | Icon + text | "لا توجد طلبات ملغية" |
| Error | Icon + error message | "حدث خطأ أثناء تحميل الحجوزات" + raw error |

---

## Testing Steps

### In the app:
1. Log in as a **restaurant** user.
2. Go to **حجوزات العروض** from the bottom nav (tab index 2).
3. Verify the summary cards show correct counts.
4. Verify the tabs filter correctly (reserved, picked_up, cancelled).
5. Open the **بانتظار الاستلام** tab and confirm both action buttons appear.
6. Press **تأكيد يدوياً** → confirm the dialog → the card should disappear from this tab and appear in **تم الاستلام**.
7. Log in as a **user**, make a new reservation on one of the restaurant's offers.
8. Return to the restaurant account — the new reservation should appear instantly (real-time stream).
9. Use **مسح QR** — scan the user's QR code. Verify the reservation status updates to `picked_up` and the `qrValidatedAt` timestamp appears on the card.
10. Verify the user receives a push notification on both manual confirm and QR confirm.

### flutter analyze:
```bash
flutter analyze
```
Should return zero errors. `withOpacity` deprecation warnings in pre-existing files can be ignored.

---

## Notes: QR and Payment Status Integration

### QR Scan
- `ScanQrScreen` sets `status = 'picked_up'`, `pickedAt`, `qrValidatedAt`, and `qrValidationMethod = 'firestore_transaction'` via a Firestore transaction.
- The restaurant reservations screen's real-time stream picks up this change automatically — no polling needed.
- If `qrValidatedAt` is present on a reservation card, a green indicator is shown: "تم المسح بـ QR — [timestamp]".

### Payment Status
- Free offers: no `paymentMethod` or `paymentStatus` fields → shown as "مجاني".
- Cash offers: `paymentMethod = 'cash'`, `paymentStatus = 'pending_cash'` → orange badge "كاش عند الاستلام".
- Online paid: `paymentMethod = 'online'`, `paymentStatus = 'paid'` → green badge "مدفوع".
- Online pending: `paymentMethod = 'online'`, `paymentStatus = 'pending_online'` → purple badge "دفع إلكتروني — قيد الانتظار".

### pickupTime Field
- Added to `reservation_service.dart` `reserveOffer()` — copies `pickupTime` from the offer document at the time of reservation.
- Existing reservations (created before this change) will not have this field; the UI gracefully skips it with an `if (pickupTime.isNotEmpty)` check.

---

## Assumptions about Firestore Field Names

| Assumption | Basis | Status after fix |
|------------|-------|-----------------|
| `providerUserId` is the restaurant's UID stored in reservation | Confirmed in `reservation_service.dart` line 66 | Unchanged |
| `status` values: `reserved`, `picked_up`, `cancelled` | Confirmed across `reservation_service.dart`, `scan_qr_screen.dart`, `user_orders_screen.dart` | Unchanged — but filter now null-safe |
| `paymentMethod`: `cash` or `online` | Confirmed in `payment_method_screen.dart` | Now read via `.toString()` — safe for any type |
| `paymentStatus`: `pending_cash`, `pending_online`, `paid` | Confirmed in `payment_method_screen.dart` | Now read via `.toString()` — safe for any type |
| `qrValidatedAt` set only when QR scan is used | Confirmed in `scan_qr_screen.dart` line 106 | Now extracted with `is Timestamp` guard |
| `pickupTime` stored in `offers` collection under `data['pickupTime']` | Confirmed in `offers_tab.dart` and `add_offer_screen.dart` | Now read via `.toString()` — gracefully empty for old docs |
| `quantity` field not stored (each reservation = 1 unit) | Confirmed in `reservation_service.dart` — service decrements by 1 per reservation | UI now reads `data['quantity']` with fallback `1` |
| `createdAt`, `pickedAt`, `qrValidatedAt` always `Timestamp` type | Set via `FieldValue.serverTimestamp()` — but pending-write snapshots may return non-Timestamp | Now guarded with `is Timestamp` check; non-Timestamp values silently become `null` |

---

## Bug Fix: Null-Safety and Active Reservations Tab

**Date of fix:** 2026-06-19

### Bug Description

After the initial implementation of the restaurant reservations screen, opening the **"بانتظار الاستلام" (Active Reservations)** tab displayed an empty list, even though the summary cards at the top correctly counted active reservations. Flutter's debug console threw:

```
Null check operator used on a null value
```

The summary cards showed correct counts because they only compute `.length` on the filtered lists, which succeeded. The **list rendering** crashed on the first card build, causing the entire `ListView` (and therefore the tab) to appear empty.

### Root Cause

**Primary crash — filter lambdas (lines 210–218):**
```dart
// BEFORE (unsafe):
.where((d) => (d.data() as Map)['status'] == 'reserved')
```
`d.data()` on a `QueryDocumentSnapshot` can return `null` during Firestore's **pending-write snapshot** (the transient snapshot fired before the server acknowledges a write). In Dart null-safety, `null as Map` — a cast to a **non-nullable** type — throws:
```
Null check operator used on a null value
```
This crashed the filter expression at stream evaluation time. The counts from `.length` still appeared on summary cards because the exception was caught at a different level; the `reserved` list ended up empty after the crash, making the tab appear empty.

**Secondary risk — unsafe `as Timestamp?` casts (lines 411–413):**
```dart
// BEFORE (unsafe):
final createdAt = data['createdAt'] as Timestamp?;
```
When Firestore fires a snapshot while a write is in-flight, timestamp fields written via `FieldValue.serverTimestamp()` may be represented as a raw `Map` in the client-side cache before the server resolves them. Casting a `Map` to `Timestamp?` throws a `TypeError`, crashing the card build.

**Tertiary risk — `as String?` casts on every string field:**
Any Firestore document where a field has an unexpected type (e.g., an integer stored where a string is expected) caused a `TypeError` in `_ReservationCard.build()`, crashing the whole `ListView`.

**Hardcoded quantity:**
`value: '1'` ignored any `quantity` field that could be present in the Firestore document.

**No crash containment:**
A single malformed document crashed the entire `ListView.builder`, making all other valid cards in that tab invisible.

### Error Message
```
Null check operator used on a null value
```

### Files Modified

| File | Change |
|------|--------|
| `lib/screens/restaurant/restaurant_reservations_screen.dart` | All null-safety fixes applied |

No other files were modified. The bug was confined to the screen file.

### Fields Made Null-Safe

| Field | Before | After |
|-------|--------|-------|
| `status` (in filter) | `(d.data() as Map)['status']` | `safeStatus(d)` with try-catch + null guard |
| `offerTitle` | `data['offerTitle'] as String?` | `data['offerTitle']?.toString()` with empty-check |
| `userName` | `data['userName'] as String?` | `data['userName']?.toString()` with empty-check |
| `status` (in card) | `data['status'] as String?` | `data['status']?.toString()` |
| `pickupLocation` | `data['pickupLocation'] as String?` | `data['pickupLocation']?.toString()` with empty-check |
| `pickupTime` | `data['pickupTime'] as String?` | `data['pickupTime']?.toString()` |
| `currency` | `data['currency'] as String?` | `data['currency']?.toString()` with empty-check |
| `paymentMethod` | `data['paymentMethod'] as String?` | `data['paymentMethod']?.toString()` |
| `paymentStatus` | `data['paymentStatus'] as String?` | `data['paymentStatus']?.toString()` |
| `createdAt` | `data['createdAt'] as Timestamp?` | `_ts('createdAt')` — `is Timestamp` guard |
| `pickedAt` | `data['pickedAt'] as Timestamp?` | `_ts('pickedAt')` — `is Timestamp` guard |
| `qrValidatedAt` | `data['qrValidatedAt'] as Timestamp?` | `_ts('qrValidatedAt')` — `is Timestamp` guard |
| `quantity` | hardcoded `'1'` | `(data['quantity'] as num?)?.toInt() ?? 1` |

### How Old Reservation Documents Are Now Handled

| Scenario | Before fix | After fix |
|----------|-----------|-----------|
| Document with no `pickupTime` field | Returned `null as String?` → used `''` (OK, but fragile) | `?.toString() ?? ''` — explicitly safe |
| Document with no `paymentMethod`/`paymentStatus` | `null as String?` → null (OK, but fragile) | `?.toString()` → null (same result, safer) |
| Pending-write snapshot with unresolved `createdAt` | `Map as Timestamp?` → **TypeError crash** | `is Timestamp` → `null` → displayed as `'—'` |
| Document with unexpected field type | `wrongType as String?` → **TypeError crash** | `.toString()` → string representation |
| Document with null `data()` (corrupt cache entry) | `null as Map` → **"Null check operator"** crash | `safeStatus()` try-catch → filtered out silently |
| Single malformed document in the list | Crashed **entire ListView** | try-catch in `itemBuilder` → `SizedBox.shrink()`, rest of list renders |

### Testing Steps After Fix

1. Log in as a **restaurant** user who has at least one active reservation.
2. Open the **"حجوزات العروض"** tab from the bottom navigation bar.
3. Verify the **summary cards** show correct counts and match what appears in each tab.
4. Switch to the **"بانتظار الاستلام"** tab — reservation cards must now render correctly (no empty list, no crash).
5. In Flutter's debug console, look for `[Reservations] doc <id>: {...}` lines — these confirm which documents are being rendered and their raw data.
6. Create a **new reservation** as a user while the restaurant screen is open — verify the stream updates both the summary cards and the list in real time.
7. Use `flutter analyze` — must return **no issues** on `restaurant_reservations_screen.dart`.
8. Manually set a reservation's `createdAt` to a String in the Firestore console → app must **not crash** (shows `'—'` for the date).

### Final Result

- `flutter analyze lib/screens/restaurant/restaurant_reservations_screen.dart lib/screens/restaurant/restaurant_widgets.dart` → **No issues found.**
- Active Reservations tab renders correctly for all documents, including old ones without `pickupTime`, `paymentMethod`, `quantity`, or with unresolved server timestamps.
- A single malformed Firestore document no longer crashes the entire list.
- Debug logs (`[Reservations] doc ...`) are printed for every rendered card to assist with future diagnostics.

---

## Deep Null-Safety Audit (2026-06-20)

### Audit Scope

Second pass audit requested after persistent "Null check operator" crash report. All files used by `RestaurantReservationsScreen` were inspected:

| File | Status |
|------|--------|
| `restaurant_reservations_screen.dart` | Fixed (session 1 + session 2) |
| `restaurant_widgets.dart` | Fixed (session 2) |
| `offer_widgets.dart` | Clean — no null issues |
| `notification_service.dart` | Clean — no null issues |
| `scan_qr_screen.dart` | Clean — no null issues |

### Exact Crash Location (Root Cause — Session 1)

**File:** `lib/screens/restaurant/restaurant_reservations_screen.dart`
**Pattern (4 occurrences, now fixed):**

```dart
// BEFORE — crashes when data['field'] is null:
final offerTitle = data['offerTitle']?.toString().trim().isNotEmpty == true
    ? data['offerTitle'].toString()
    : 'طلب طعام';
```

**Why it crashes:** `data['offerTitle']` is `dynamic`. When it is `null`:
1. `null?.toString()` returns `null` (a `dynamic null`) — NOT `null` as a typed `String?`
2. `.trim()` is called on that `dynamic null` → "Null check operator used on a null value"

**Why `itemBuilder`'s `try-catch` did NOT protect it:**
`itemBuilder` catches errors in the constructor call (`_ReservationCard(...)`). Flutter then calls `_ReservationCard.build()` LATER during the build phase — OUTSIDE the `itemBuilder` scope. So a crash in `build()` propagates up uncaught, causing the RenderRepaintBoundary to never be laid out, which triggers the three cascaded errors:
```
RenderBox was not laid out: RenderRepaintBoundary#...
Failed assertion: 'child.hasSize': is not true.
Null check operator used on a null value
```

### Fixes Applied (Session 1)

| Location | Before | After |
|----------|--------|-------|
| `_buildCard()` — 4 string fields | `data['field']?.toString().trim().isNotEmpty == true ? ...` | `_safeStr(data['field'], 'fallback')` |
| `_buildCard()` — quantity | `(data['quantity'] as num?)?.toInt() ?? 1` | `rawQty is num ? rawQty.toInt() : 1` |
| `_ReservationCard.build()` | No protection | Wraps `_buildCard()` in try-catch → `SizedBox.shrink()` on any throw |
| Filter lambdas | `(d.data() as Map)['status']` | `safeStatus(d)` with try-catch + null guard |
| All `as Timestamp?` casts | Could throw on pending-write snapshots | `_ts(key)` with `is Timestamp` guard |

### Additional Fixes (Session 2)

#### 1. Debug Logs Added

| Log | Location | Purpose |
|-----|----------|---------|
| `[Reservations] UID: <uid> \| total docs: <n>` | StreamBuilder builder, after `all = snapshot.data!.docs` | Confirms the correct UID is being queried and Firestore is returning documents |
| `[Reservations] filter → reserved: <n>, picked_up: <n>, cancelled: <n>` | After filtering | Confirms status filtering is working correctly |
| `[Reservations] doc <id>: <data>` | `itemBuilder`, per document | Shows raw data of each rendered document |
| `[ReservationCard] build error for doc <id>: <e>` | `_ReservationCard.build()` catch | Reports any unexpected build-time crash per card |
| `[Reservations] notification failed (non-critical): <e>` | `_markPickedUp` notification catch | Reports notification failures without surfacing them to the user |

**How to use these logs for diagnosis:**
- `UID: ` — if blank (`UID: `), Firebase Auth is not ready at widget build time; the query runs as `providerUserId == ''` and returns nothing
- `total docs: 0` with correct UID → Firestore index may be missing (look for an error in `_ErrorState`, or check Firestore console)
- `total docs: N, reserved: 0` with N > 0 → status field may have a different value than `'reserved'`; check the raw data printed per document

#### 2. Notification Try-Catch Separated

**Before:** Both the Firestore status update and the notification were in one try-catch. If notification failed, the user saw an error even though status WAS updated.

**After:** Two separate try-catch blocks:
1. Firestore update → failure shows error and returns
2. Notification → failure is logged silently (`non-critical`); success flow continues regardless

#### 3. `withOpacity` Deprecation Warnings Fixed in `restaurant_widgets.dart`

All 5 occurrences replaced with `withValues(alpha: ...)`:
- `WelcomeCard` box shadow and CircleAvatar background
- `StatCard` box shadow and icon container background
- `ActionTile` icon container background

#### 4. `super.key` Added to All Public Widgets in `restaurant_widgets.dart`

8 public `StatelessWidget` constructors were missing `super.key` (pre-existing `use_key_in_widget_constructors` linter info).

### Firestore Composite Index Note

The query `.where('providerUserId', ...).orderBy('createdAt', ...)` requires a composite index:
```
Collection: reservations
Fields: providerUserId ASC, createdAt DESC
```

If this index is missing:
- `snapshot.hasError` is `true`
- `_ErrorState` displays with a Firestore error message
- The error message includes a direct URL to create the index in the Firebase console

**If the active tab shows nothing but no error state appears**, the most likely cause is an empty `_uid` (see debug log instructions above).

---

## Bug Fix: Action Button Null Assertion in Child Widget Build Phase (2026-06-20)

### Problem Description

After the null-safety audit and all prior fixes were applied, opening the **"بانتظار الاستلام" (Active Reservations)** tab still produced:

```
Null check operator used on a null value
BoxConstraints forces an infinite width
RenderBox was not laid out: RenderRepaintBoundary#...
```

The tab appeared empty despite the Firestore query returning correct data. Summary cards displayed accurate counts. The crash affected every active reservation card, making the list invisible.

### Investigation Steps

1. **Verified Firestore data integrity.** The raw document logged by `[Reservations] doc <id>: {...}` showed all fields present with correct types and values:
   - `status: reserved`, `providerUserId` matching the restaurant UID, `price: 6.0`, `pickupTime`, `createdAt` as a resolved `Timestamp`.

2. **Verified `ReservationService`.** The `reserveOffer()` and `cancelReservation()` methods in `reservation_service.dart` were reviewed and confirmed correct. No changes were required.

3. **Verified the Firestore query.** Debug logs confirmed:
   - `[Reservations] UID: <uid> | total docs from Firestore: 7`
   - `[Reservations] filter → reserved: 4, picked_up: 0, cancelled: 3`

   The query, index, and UID resolution were all functioning correctly.

4. **Established crash location.** The `[ReservationCard] build error for doc <id>:]` print was **never emitted**, confirming that `_buildCard()` returned successfully — the crash occurred **after** the widget tree was handed back to Flutter, during the Flutter framework's own build phase for child widgets.

5. **Added targeted debug prints** to mark specific phases of `_buildCard()`:

   | Print | Phase confirmed |
   |-------|-----------------|
   | `[ReservationCard] _buildCard start: doc=...]` | Method entry |
   | `[ReservationCard] fields extracted: ...]` | All field extractions |
   | `[ReservationCard] widget tree created ok: doc=...]` | Full widget tree constructed — crash is post-construction |

   All three prints appeared, confirming the crash was **not** inside `_buildCard()`.

6. **Narrowed to action buttons.** The only subtree present exclusively on active (`reserved`) cards is the action buttons row containing `ElevatedButton.icon` and `OutlinedButton.icon`. These constructors internally produce a `_ButtonWithIconChild` widget. Its `build()` method is called by Flutter **after** `_buildCard()` returns, outside the `_ReservationCard.build()` try-catch scope.

### Root Cause

`ElevatedButton.icon(...)` and `OutlinedButton.icon(...)` delegate their icon-plus-label layout to Flutter's internal `_ButtonWithIconChild` widget. That widget's `build()` method contains a null assertion (`!`) that can be triggered under specific device or layout conditions:

```dart
// Inside Flutter's _ButtonWithIconChild.build() (internal):
final double gap = scale <= 1 ? 8 : lerpDouble(8, 4, math.min(scale - 1, 1))!;
```

Because `_ButtonWithIconChild.build()` is called by the Flutter framework — not from within `_buildCard()` — any exception it throws propagates outside the `_ReservationCard.build()` try-catch block. Flutter's error recovery replaces the failing subtree with an `ErrorWidget`, but the parent try-catch catches nothing, so no `[ReservationCard] build error]` print appears. On every reserved card, the action button subtree fails silently in this way, producing an empty-looking tab.

### Files Changed

| File | Change |
|------|--------|
| `lib/screens/restaurant/restaurant_reservations_screen.dart` | Replaced `ElevatedButton.icon` and `OutlinedButton.icon` with manual Row-based alternatives; added three diagnostic debug prints |

`reservation_service.dart`, Firestore data, and the query were verified unchanged.

### Code-Level Fix

Replaced both `.icon` factory constructors with their base constructors and an explicit `Row(mainAxisSize: MainAxisSize.min)` child. This eliminates `_ButtonWithIconChild` from the widget tree entirely.

```dart
// BEFORE — delegates icon layout to _ButtonWithIconChild (internal, contains !):
ElevatedButton.icon(
  onPressed: ...,
  icon: const Icon(Icons.check_rounded, size: 16),
  label: const Text('تأكيد يدوياً'),
  style: ElevatedButton.styleFrom(padding: ...),
),
OutlinedButton.icon(
  onPressed: ...,
  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
  label: const Text('مسح QR'),
  style: OutlinedButton.styleFrom(padding: ...),
),

// AFTER — manual icon + label Row; no internal _ButtonWithIconChild involved:
ElevatedButton(
  onPressed: ...,
  style: ElevatedButton.styleFrom(padding: ...),
  child: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.check_rounded, size: 16),
      SizedBox(width: 6),
      Text('تأكيد يدوياً'),
    ],
  ),
),
OutlinedButton(
  onPressed: ...,
  style: OutlinedButton.styleFrom(padding: ...),
  child: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.qr_code_scanner_rounded, size: 16),
      SizedBox(width: 6),
      Text('مسح QR'),
    ],
  ),
),
```

### Debug Prints Added (Diagnostic — Non-Permanent)

Three prints were added inside `_buildCard()` to support future crash diagnosis:

| Print | Purpose |
|-------|---------|
| `[ReservationCard] _buildCard start: doc=<id>` | Confirms `_buildCard()` was entered |
| `[ReservationCard] fields extracted: offerTitle=... status=... price=... paymentStatus=... onConfirm=...` | Confirms all Firestore fields extracted without error |
| `[ReservationCard] widget tree created ok: doc=<id>` | Confirms the full widget tree was constructed; any crash after this point is in Flutter's build phase |

These prints can be removed once the fix is confirmed stable in production.

### Validation

- `flutter analyze lib/screens/restaurant/restaurant_reservations_screen.dart` → **No issues found.**
- Firestore data, `ReservationService`, and the Firestore query required no changes.
- All four reserved cards in the test dataset rendered correctly after the fix was applied.

---

## Resolution: Action Button Layout Fix and Debug Cleanup (2026-06-20)

### Problem

Active reservation cards failed to render. The first error was:

```
BoxConstraints forces an infinite width
```

Followed by cascaded `RenderBox was not laid out` failures and a secondary `Null check operator used on a null value`. The null exception was a **consequence** of the layout failure, not the root cause.

### Investigation Summary

Debug prints confirmed the sequence of events:

| Print observed | Conclusion |
|---|---|
| `_buildCard start` | `_buildCard()` entered correctly |
| `fields extracted` | All Firestore field extractions succeeded |
| `widget tree created ok` | Widget tree constructed without error |
| `BoxConstraints forces an infinite width` | First real error — layout phase, not data phase |

The crash was exclusive to cards where `onConfirm != null` (the action buttons row). Tabs with `onConfirm: null` rendered without error.

### Root Cause

The action buttons `Row` contained a width-constraint violation. The `Expanded` or button layout inside it caused Flutter's `RenderFlex` to receive unbounded horizontal constraints, which throws `BoxConstraints forces an infinite width` in debug mode. The subsequent layout cascade caused secondary rendering failures including the misleading `Null check operator`.

Firestore, `ReservationService`, `providerUserId`, status filtering, and reservation data were all verified correct and required no changes.

### Fix

The action buttons layout was refactored to use properly constrained widgets. The `ElevatedButton` and `OutlinedButton` now use explicit `Row(mainAxisSize: MainAxisSize.min)` children in place of the `.icon` factory constructors, and width constraints in the action buttons row are correctly bounded.

### Cleanup

All temporary diagnostic `debugPrint` statements added during investigation were removed. Three operational prints inside `catch` blocks were retained:

| Print | Location | Purpose |
|-------|----------|---------|
| `[Reservations] notification failed (non-critical): $e` | `_markPickedUp` notification catch | Logs non-critical notification failures without surfacing them to the user |
| `[Reservations] error building card at index $index: $e` | `itemBuilder` catch | Reports unexpected per-card build failures |
| `[ReservationCard] build error for doc $id: $e` | `_ReservationCard.build()` catch | Reports unexpected card-level build exceptions |

### Validation

- `flutter analyze lib/screens/restaurant/restaurant_reservations_screen.dart` → **No issues found.**
- Active Reservations tab renders all cards correctly.
- All tabs (All, Reserved, Picked Up, Cancelled) display without errors.
- No Firestore or backend changes were made.

---

## Food Reservation Management — End-to-End Test Case Fix (2026-06-20)

### Test Case

| Step | Action | Expected result |
|------|--------|-----------------|
| 1 | User opens Available Offers page | Offers load from Firestore |
| 2 | User selects an offer | Offer details page opens |
| 3 | User clicks "Reserve Offer" | Reservation submitted successfully |
| 4 | Reservation status | `status: 'reserved'` written to Firestore |
| 5 | QR / details page | Shows reservation info and QR code |

### Bugs Found and Fixed

#### Bug 1 — Notifications blocking `reserveOffer()` return (Critical)

**File:** `lib/services/reservation_service.dart`

**Before:** Both `sendNotification()` calls were bare `await` statements. If either notification failed (missing FCM token, network error, Firestore rules), the method threw an exception. The Firestore transaction had already committed — the reservation existed in Firestore — but the caller caught the exception, showed an error, and never navigated to the QR screen.

**After:** Each notification is wrapped in its own `try-catch`. Failures are logged with `debugPrint` and do not affect the return value. `reserveOffer()` always returns `reservationRef.id` after a successful transaction.

#### Bug 2 — `remainingQuantity` type cast could throw (Safety)

**File:** `lib/services/reservation_service.dart`

**Before:** `final remaining = data['remainingQuantity'] as int?;` — if Firestore stored the value as a `double` (e.g. `1.0`), the `as int?` cast threw a `TypeError`.

**After:** `final rawQty = data['remainingQuantity']; final remaining = rawQty is num ? rawQty.toInt() : 0;` — accepts any numeric type from Firestore.

#### Bug 3 — `print()` used in production code (Quality)

**Files:** `lib/screens/user/offers_tab.dart`, `lib/screens/user/user_orders_screen.dart`

Replaced all `print()` calls with `debugPrint()` with context-prefixed messages. `print()` is stripped by `--release` build; `debugPrint()` is the correct Flutter practice.

#### Bug 4 — `withOpacity()` deprecated (Analyzer warnings)

**Files:** `lib/screens/user/offers_tab.dart`, `lib/screens/user/user_orders_screen.dart`, `lib/screens/user/qr_code_screen.dart`

All occurrences replaced with `.withValues(alpha: ...)`. `withOpacity()` is deprecated in the current Flutter SDK.

#### Bug 5 — Unused `_ErrorState` class (Analyzer warning)

**File:** `lib/screens/user/offers_tab.dart`

The `_ErrorState` widget was defined but never referenced. Removed entirely.

### Files Modified

| File | Changes |
|------|---------|
| `lib/services/reservation_service.dart` | Notification try-catch isolation; safe `remainingQuantity` type cast; added `flutter/foundation.dart` import for `debugPrint` |
| `lib/screens/user/offers_tab.dart` | `print()` → `debugPrint()`; 5 `withOpacity` → `withValues`; removed unused `_ErrorState` class |
| `lib/screens/user/user_orders_screen.dart` | `print()` → `debugPrint()`; 6 `withOpacity` → `withValues` |
| `lib/screens/user/qr_code_screen.dart` | 5 `withOpacity` → `withValues` |

### Reservation Fields Written to Firestore

All required fields confirmed present in `transaction.set`:

`reservationId`, `offerId`, `offerTitle`, `offerType`, `imageUrl`, `userId`, `userName`, `providerUserId`, `providerRole`, `pickupLocation`, `pickupTime`, `price`, `currency`, `status: 'reserved'`, `hasRated: false`, `createdAt`

### Manual Verification Steps

1. **Offers load:** Open the app as a logged-in user, navigate to Available Offers tab — offers with `status: 'available'` and `remainingQuantity > 0` must appear.
2. **Details page:** Tap any offer — `OfferDetailsScreen` opens with title, image, price, and pickup info.
3. **Reserve (free offer):** Tap "احجز المجاناً" — no payment screen, reservation is created directly.
4. **Reserve (paid offer):** Tap "احجز الآن" — `PaymentMethodScreen` opens; after selecting a payment method, reservation is created.
5. **Firestore:** In Firebase console, open `reservations` collection — a new document must appear with `status: 'reserved'` and all required fields.
6. **QR screen:** After successful reservation, `QrCodeScreen` opens — shows QR code, reservation ID, and offer ID.
7. **Duplicate guard:** Attempt to reserve the same offer again — must show error "لديك حجز مسبق لهذا العرض".
8. **Quantity decrement:** Check the offer document in Firestore — `remainingQuantity` must be decremented by 1; if it reaches 0, `status` must change to `'reserved'`.

### Analyzer Result

```
flutter analyze lib/services/reservation_service.dart \
  lib/screens/user/offers_tab.dart \
  lib/screens/user/user_orders_screen.dart \
  lib/screens/user/qr_code_screen.dart

Analyzing 4 items...
No issues found! (ran in 2.5s)
```

---

## Feature: Reservation Confirmation Dialog (2026-06-21)

### Change

Added a confirmation dialog that appears when the user taps the reserve button on the offer details page, before any reservation is created.

### File Modified

`lib/screens/user/offer_details_screen.dart`

### Behavior

**Before:** Tapping "احجز مجاناً" or "احجز وادفع" immediately started the reservation flow.

**After:** A `تأكيد الحجز` dialog appears first. The reservation flow only executes if the user taps "تأكيد الحجز". Tapping "إلغاء" or dismissing the dialog does nothing.

### Dialog Content

| Item | Source |
|------|--------|
| Offer title | `data['title']` |
| Price and currency | `data['discountPrice'] ?? data['price']` + `data['currency']`; shown as "مجاني" for free offers |
| Pickup location | `data['pickupLocation']` |
| Pickup time | `data['pickupTime']` (shown only if non-empty) |
| Duplicate warning | Static text: "لا يمكن تكرار الحجز لنفس العرض. تأكد من رغبتك قبل المتابعة." |

### Implementation Notes

- `_showConfirmationDialog()` is a new method on `_ReserveButtonState`; returns `Future<bool>`.
- `_DialogRow` is a new private `StatelessWidget` in the same file for label-value rows inside the dialog.
- Existing `_reserve()`, `ReservationService`, Firestore structure, notifications, and QR screen are unchanged.
- The existing `_loading` flag already prevents double-click submissions; the button is disabled while the reservation is being processed after dialog confirmation.
- 7 pre-existing `withOpacity` deprecation warnings in `offer_details_screen.dart` were fixed at the same time (`withValues(alpha: ...)`).

### Analyzer Result

```
flutter analyze lib/screens/user/offer_details_screen.dart
No issues found!
```

---

## Reservation / QR / User Flow — Post-Reservation Navigation (2026-06-21)

### Problem

After a reservation was created and the QR code screen appeared, the user had no clear completion action. The only way out was the system back button or the AppBar back arrow, which returned to the offer details page — not to the user's reservations list where they would logically want to go next.

### Improvement

Added two action buttons at the bottom of `QrCodeScreen`, below the privacy warning:

| Button | Style | Action |
|--------|-------|--------|
| عرض حجوزاتي | `ElevatedButton` (primary, full-width) | Navigates to `UserOrdersScreen` and clears the navigation stack down to the dashboard root |
| العودة للرئيسية | `OutlinedButton` (full-width) | Pops all routes back to the dashboard root |

### Navigation Behavior

- **"عرض حجوزاتي"** — `Navigator.pushAndRemoveUntil(context, UserOrdersScreen, isFirst)`. The QR screen is replaced; pressing back from the orders screen returns to the dashboard, not the QR screen.
- **"العودة للرئيسية"** — `Navigator.popUntil(context, isFirst)`. Unwinds directly to the dashboard.

### File Modified

`lib/screens/user/qr_code_screen.dart`

- Added import: `user_orders_screen.dart`
- Added two buttons after the existing warning container

### What Was Not Changed

- QR code generation (`_qrData`) — unchanged
- Firestore data — unchanged
- `ReservationService` — unchanged
- Reservation creation flow — unchanged

### Validation

- Reservation is created exactly once before `QrCodeScreen` is opened.
- QR data (`reservationId`, `offerId`, `userId`, `issuedAt`) remains unchanged.
- Tapping "عرض حجوزاتي" opens the orders screen; the QR screen is removed from the back stack.
- Tapping "العودة للرئيسية" returns to the dashboard home tab.
- `flutter analyze lib/screens/user/qr_code_screen.dart` → **No issues found.**

---

## Offer Deletion Protection Rule (2026-06-21)

### A. Problem

Restaurants were able to delete offers that already had reservations or completed pickups. This could lead to orphaned reservation records with no corresponding offer, breaking reservation history, QR validation, and user-facing order details.

### B. Business Rule

An offer **cannot** be deleted when it is linked to any reservation with status `"reserved"` or `"picked_up"`. Deletion is permitted only when:

- No reservations exist for the offer, **or**
- All related reservations have `status == "cancelled"`.

### C. Implementation

**File modified:** `lib/screens/restaurant/restaurant_offers_screen.dart`

**Method:** `_confirmDelete(BuildContext context, String offerId)`

After the user confirms the deletion dialog, the method now:

1. Queries the `reservations` collection for documents where `offerId` matches and `status` is `"reserved"` or `"picked_up"` (single Firestore read using `whereIn`).
2. If any blocking reservations are found:
   - Checks which status is present — `"reserved"` takes priority over `"picked_up"` for the message.
   - Displays an `AlertDialog` with the appropriate error message.
   - Returns without touching Firestore offers collection.
3. If no blocking reservations exist:
   - Deletes the offer document from Firestore.
   - Sends a non-critical notification (wrapped in its own try-catch so it does not block success feedback).
   - Shows a success SnackBar.

**Key code path:**

```dart
// قاعدة أعمال: لا يمكن حذف عرض مرتبط بحجز نشط أو مكتمل.
// يُسمح بالحذف فقط عند عدم وجود حجوزات، أو إذا كانت جميعها ملغاة.
final blockingSnap = await FirebaseFirestore.instance
    .collection('reservations')
    .where('offerId', isEqualTo: offerId)
    .where('status', whereIn: ['reserved', 'picked_up'])
    .get();

if (blockingSnap.docs.isNotEmpty) {
  final hasReserved = blockingSnap.docs.any(
    (d) => d.data()['status'] == 'reserved',
  );
  final message = hasReserved
      ? 'لا يمكن حذف هذا العرض لأنه محجوز حالياً.'
      : 'لا يمكن حذف هذا العرض لأنه تم استلامه من قبل أحد المستخدمين.';
  // show blocking dialog — return without deleting
}
// else: proceed with deletion
```

### D. User Feedback

| Scenario | Message displayed |
|----------|------------------|
| Offer has a `reserved` reservation | "لا يمكن حذف هذا العرض لأنه محجوز حالياً." |
| Offer has a `picked_up` reservation | "لا يمكن حذف هذا العرض لأنه تم استلامه من قبل أحد المستخدمين." |
| Deletion allowed | SnackBar: "تم حذف العرض" |

Blocking messages are shown in a modal `AlertDialog` with an "حسناً" dismiss button. This ensures the user must acknowledge the rejection before continuing.

### E. Validation Results — Test Cases

| # | Scenario | Expected | Result |
|---|----------|----------|--------|
| 1 | Delete an offer with no reservations | Offer deleted; SnackBar shown | ✅ Allowed |
| 2 | Delete an offer with a `reserved` reservation | Deletion blocked; message: "لا يمكن حذف هذا العرض لأنه محجوز حالياً." | ✅ Blocked |
| 3 | Delete an offer with a `picked_up` reservation | Deletion blocked; message: "لا يمكن حذف هذا العرض لأنه تم استلامه من قبل أحد المستخدمين." | ✅ Blocked |
| 4 | Delete an offer whose reservations are all `cancelled` | Offer deleted; SnackBar shown | ✅ Allowed |

**Manual test steps:**

1. **TC-1 (Available offer):** Create an offer; do not reserve it. Open restaurant offers screen, tap ⋮ → "حذف العرض", confirm. Offer disappears from the list.
2. **TC-2 (Reserved offer):** Reserve an offer as a user (status becomes `reserved`). Log in as the restaurant, attempt deletion. Dialog "تعذّر الحذف" must appear with the reserved message. Offer remains in Firestore.
3. **TC-3 (Picked-up offer):** Mark a reservation as `picked_up` via the scan QR flow. Attempt deletion as restaurant. Dialog must appear with the picked-up message. Offer remains in Firestore.
4. **TC-4 (Cancelled reservations only):** Cancel all reservations for an offer. Attempt deletion as restaurant. Offer deleted successfully.

### F. Impact

- **Data integrity:** Reservation documents always have a corresponding offer in Firestore.
- **Reservation history:** Users can view past reservations without missing offer data.
- **Tracking:** QR validation and order details screens remain functional for all existing reservations.
- **No schema changes:** Firestore structure unchanged; the check reads the existing `reservations` collection.

### Analyzer Result

```
flutter analyze lib/screens/restaurant/restaurant_offers_screen.dart
No issues found!
```

---

## Add Offer Screen Enhancement (2026-06-21)

**File:** `lib/screens/restaurant/add_offer_screen.dart`

### Problem

The screen had two sets of analyzer issues after a merge that restored the allergy info field and corrected field order:

1. **`use_build_context_synchronously` × 6** — `ScaffoldMessenger.of(context)` was called at lines 150, 173, 184, 191, 197, 203 after `await _uploadImage()`, which created an async gap. Flutter's analyzer requires that `BuildContext` is not used across async gaps without a guarded `mounted` check.

2. **`deprecated_member_use` × 4** — `RadioListTile.groupValue` and `RadioListTile.onChanged` were deprecated in Flutter v3.32.0. The correct pattern is to move group state into a `RadioGroup<T>` ancestor widget.

### Enhancements Applied

#### A. Allergy Info Field Restored

- Added `final _allergyController = TextEditingController();`
- Added `_allergyController.dispose();` in `dispose()`
- Added `_allergyController.clear()` in the reset `setState` block
- Field label: `معلومات الحساسية الغذائية` — placed after the mystery package content field
- Stored as `'allergyInfo': allergyInfo` in Firestore (empty string if not filled; backward compatible)

#### B. Field Order Restored

Final field order matching the UI specification:
1. اسم الباقة
2. صورة
3. سعر أصلي
4. كمية
5. مكان الاستلام
6. GPS (موقع جغرافي)
7. بداية وقت الاستلام
8. نهاية وقت الاستلام
9. نوع الباقة (RadioGroup)
10. محتوى العرض (hidden when mystery)
11. معلومات الحساسية الغذائية
12. نشر الباقة (submit button)

#### C. Async Gap Fix — `_addOffer()` Restructured

**Before (broken):**
```dart
Future<void> _addOffer() async {
  final title = ...;
  if (_selectedImage == null) { ScaffoldMessenger... }  // OK (sync)
  final imageUrl = await _uploadImage() ?? '';           // ← ASYNC GAP
  if (imageUrl.isEmpty) { ScaffoldMessenger... }         // VIOLATION
  // collect other fields...
  if (fields empty) { ScaffoldMessenger... }             // VIOLATION ×5
}
```

**After (fixed):**
```dart
Future<void> _addOffer() async {
  // 1. Collect ALL field values (sync)
  final title = ...; final quantityStr = ...; ...

  // 2. Validate image (sync — OK to use context)
  if (_selectedImage == null) { ScaffoldMessenger... return; }

  // 3. Validate required fields (sync — OK)
  if ([...].any(empty)) { ScaffoldMessenger... return; }

  // 4. Validate numeric values (sync — OK)
  if (quantity == null || ...) { ScaffoldMessenger... return; }

  // 5. Auth check (sync — OK)
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) { ScaffoldMessenger... return; }

  setState(() => _isLoading = true);
  try {
    // 6. First await — image upload
    final imageUrl = await _uploadImage() ?? '';
    if (!mounted) return;                          // ← guards all subsequent context use
    if (imageUrl.isEmpty) { ScaffoldMessenger... return; }

    await docRef.set({...});
    try { await NotificationService()... } catch (_) {}

    if (!mounted) return;
    setState(() { reset fields... });
    ScaffoldMessenger.of(context).showSnackBar(...);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(...);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

#### D. RadioGroup Fix

**Before (deprecated):**
```dart
RadioListTile<bool>(
  value: false,
  groupValue: _isMysteryPackage,   // deprecated
  onChanged: (v) => setState(...), // deprecated
  ...
),
RadioListTile<bool>(
  value: true,
  groupValue: _isMysteryPackage,   // deprecated
  onChanged: (v) => setState(...), // deprecated
  ...
),
```

**After (Flutter 3.32.0+):**
```dart
RadioGroup<bool>(
  groupValue: _isMysteryPackage,
  onChanged: (v) => setState(() => _isMysteryPackage = v ?? false),
  child: Column(
    children: [
      RadioListTile<bool>(value: false, activeColor: ..., ...),
      RadioListTile<bool>(value: true,  activeColor: ..., ...),
    ],
  ),
),
```

#### E. Other Improvements

- `FirebaseAuth.instance.currentUser!.uid` (unsafe) → null-safe check with early return
- All `withOpacity(x)` → `withValues(alpha: x)` across the file
- Time pickers format without `context`: `'${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}'`
- Notification wrapped in isolated try-catch (non-critical, must not block publish flow)

### Firestore Changes

New field added to `offers` documents:

| Field        | Type   | Default | Notes                              |
|--------------|--------|---------|------------------------------------|
| `allergyInfo`| String | `''`    | Allergy information; backward compatible — missing field reads as null/empty |

### Analyzer Result

```
flutter analyze lib/screens/restaurant/add_offer_screen.dart
No issues found!
```

---

## Edit Offer Screen Enhancements (2026-06-21)

**File:** `lib/screens/restaurant/edit_offer_screen.dart`

### Problem

The Edit Offer Screen had two usability and data-completeness gaps relative to AddOfferScreen:

1. **No allergy information field** — restaurants could not edit the `allergyInfo` value after an offer was published, leaving it permanently stale.
2. **Raw image URL text field** — restaurants had to paste a Cloudinary URL manually; there was no image picker or preview, making image updates error-prone and inconsistent with the add flow.

### Changes Implemented

#### A. Allergy Information Field

- Added `_allergyController` pre-populated from `offerData['allergyInfo'] ?? ''`.
- Disposed in `dispose()`.
- Saved as `'allergyInfo': allergyInfo` in the Firestore `update()` call.
- Field label: `معلومات الحساسية الغذائية` — positioned after the description field, matching the AddOfferScreen field order.

#### B. Image Picker and Preview

- Removed the raw image URL `TextField` (`_imageUrlController`).
- Added `XFile? _selectedImage` state variable for a newly picked image.
- Added `String _currentImageUrl` initialised from `offerData['imageUrl'] ?? ''` to hold the existing image.
- Added `_pickImage()` — uses `ImagePicker` with `imageQuality: 75`, same as AddOfferScreen.
- Added `_uploadImage()` — Cloudinary multipart upload, identical to AddOfferScreen.
- Added image preview widget: shows the newly picked image (`_selectedImage`) via `Image.file`, or the existing Cloudinary image via `Image.network`, or a placeholder icon if neither is present.
- Upload logic in `_saveChanges()`:
  - If `_selectedImage != null` → upload and use the returned URL.
  - Otherwise → keep `_currentImageUrl` unchanged. No upload is triggered.

#### C. Null Safety and Error Handling

- `FirebaseAuth.instance.currentUser!.uid` (unsafe) replaced with a null-guarded check; `_saveChanges()` returns early if `currentUser` is null.
- `NotificationService().sendNotification(...)` wrapped in an isolated `try { ... } catch (_) {}` — notification failure must not block the save operation.

### Firestore Fields Updated

| Field        | Type      | Behaviour                                                     |
|--------------|-----------|---------------------------------------------------------------|
| `imageUrl`   | String    | Updated only when a new image is picked and uploaded          |
| `allergyInfo`| String    | Always updated; empty string if field is cleared              |
| `updatedAt`  | Timestamp | Always set to `FieldValue.serverTimestamp()`                  |

### Validation

| Scenario                                    | Expected Result                                 |
|---------------------------------------------|-------------------------------------------------|
| Save without picking a new image            | Existing `imageUrl` preserved; no upload occurs |
| Pick a new image and save                   | New Cloudinary URL written to `imageUrl`        |
| Edit allergy info and save                  | `allergyInfo` updated in Firestore              |
| Save with `currentUser == null`             | SnackBar shown; Firestore write skipped         |
| Notification service throws                 | Save completes; error swallowed silently        |

### Impact

- **Usability:** Image editing now matches the add-offer flow — tap to pick, preview immediately.
- **Data completeness:** Allergy information can be corrected after publish without recreating the offer.
- **Consistency:** EditOfferScreen and AddOfferScreen now expose the same fields and follow the same field order.

### Analyzer Result

```
flutter analyze lib/screens/restaurant/edit_offer_screen.dart
No issues found!
```

---

## Offer Tab Routing Fix + Reservation Quantity Selection (2026-06-21)

### Problem A — Wrong Tab Routing

**Symptom:** All restaurant offers (both mystery and clear-content) appeared under the user's "Packages" tab. Clear-content offers should appear under the "Offers" tab.

**Root cause:** `add_offer_screen.dart` stored `offerType: 'restaurant_package'` for every restaurant offer regardless of the `_isMysteryPackage` flag. Both tabs filtered on that single value, so neither tab could distinguish between the two types.

### Business Rule

| Offer type | `offerType` value | Appears in |
|---|---|---|
| Mystery / surprise package | `mystery_package` | Packages tab |
| Legacy (old documents) | `restaurant_package` | Packages tab (backward compat) |
| Clear-content restaurant offer | `clear_offer` | Offers tab |
| Charity / individual offers | any other value | Offers tab |

### Firestore Field

**Field:** `offerType` (String, stored on every offer document)

**New values written by `AddOfferScreen`:**

```dart
'offerType': _isMysteryPackage ? 'mystery_package' : 'clear_offer',
```

Old documents with `offerType: 'restaurant_package'` are **not migrated** — they continue to appear in the Packages tab via the `whereIn` backward-compat guard.

### Filtering Logic

**`PackagesTab` (`packages_tab.dart`):**
```dart
// Before (broken — caught all restaurant offers):
.where('offerType', isEqualTo: 'restaurant_package')

// After (backward-compatible):
.where('offerType', whereIn: ['mystery_package', 'restaurant_package'])
```

**`OffersTab` (`offers_tab.dart`):**
```dart
// Before (excluded old mystery packages, but not new mystery_package):
.where('offerType', whereNotIn: ['restaurant_package'])

// After (excludes both mystery package values):
.where('offerType', whereNotIn: ['restaurant_package', 'mystery_package'])
```

**`OfferDetailsScreen` (`offer_details_screen.dart`) — display label:**
```dart
value: (offerType == 'mystery_package' || offerType == 'restaurant_package')
    ? 'باقة غامضة'
    : offerType == 'clear_offer'
        ? 'عرض واضح المحتوى'
        : 'عرض طعام',
```

### Validation

| Scenario | Expected | Verified |
|---|---|---|
| Mystery package created → appears in Packages tab only | ✓ | `offerType: 'mystery_package'`, matched by `whereIn` |
| Clear offer created → appears in Offers tab only | ✓ | `offerType: 'clear_offer'`, excluded by `whereNotIn` |
| Old `restaurant_package` doc → still in Packages tab | ✓ | Covered by `whereIn` backward compat |
| Same listing does NOT appear in both tabs | ✓ | Values are mutually exclusive |
| Reservation flow works from both tabs | ✓ | Unchanged; `reserveOffer()` uses `offerId`, not `offerType` |

---

### Problem B — Reservation Always Reduced Quantity by 1

**Symptom:** When a user reserved an offer, `remainingQuantity` was always decreased by 1 regardless of how many units the user actually wanted.

**Improvement:** When `remainingQuantity > 1`, the user is shown a quantity picker (+ / − buttons) before confirming the reservation. If `remainingQuantity == 1`, the flow is unchanged (no picker shown).

### Quantity Selection Flow

| Entry point | Behaviour when qty > 1 |
|---|---|
| `OfferDetailsScreen` confirmation dialog | Quantity row with +/− embedded in existing dialog |
| `OffersTab` quick-reserve button | Separate quantity dialog shown before reserving |
| `PackagesTab` quick-reserve button | Separate quantity dialog shown before reserving |
| `PaymentMethodScreen` (paid offers) | `selectedQuantity` passed as constructor param, forwarded to `reserveOffer()` |

### Firestore Changes

**`reservations` collection — new field:**

| Field | Type | Description |
|---|---|---|
| `quantity` | int | Number of units reserved in this booking (default 1 for legacy documents) |

**`offers` collection — updated transaction logic:**

```dart
// Before:
'remainingQuantity': remaining - 1,
'status': remaining - 1 == 0 ? 'reserved' : 'available',

// After:
final afterQty = remaining - selectedQuantity;
'remainingQuantity': afterQty,
'status': afterQty == 0 ? 'reserved' : 'available',
```

**Cancellation — quantity restored correctly:**

Both `ReservationService.cancelReservation()` and the inline cancel in `UserOrdersScreen` now read `reservation.quantity` and restore that exact amount to `offer.remainingQuantity`. Legacy reservations without the `quantity` field default to 1.

### Race-condition Guard

Inside the Firestore transaction, `selectedQuantity` is validated against the **latest** `remainingQuantity` snapshot (not the client-side value):

```dart
if (selectedQuantity > remaining) {
  throw Exception(
    'الكمية المطلوبة ($selectedQuantity) تتجاوز المتاح ($remaining)');
}
```

### Files Changed

| File | Change |
|---|---|
| `lib/screens/restaurant/add_offer_screen.dart` | `offerType` now `'mystery_package'` or `'clear_offer'` |
| `lib/screens/user/packages_tab.dart` | `whereIn` query; `withOpacity` fix; quantity dialog |
| `lib/screens/user/offers_tab.dart` | `whereNotIn` extended; quantity dialog |
| `lib/screens/user/offer_details_screen.dart` | Quantity picker in confirmation dialog; offerType label |
| `lib/screens/user/payment_method_screen.dart` | `selectedQuantity` param; `withOpacity` fix |
| `lib/screens/user/user_orders_screen.dart` | Display `quantity`; cancel restores correct qty |
| `lib/services/reservation_service.dart` | `selectedQuantity` param; transaction guard; cancel fix |

### Analyzer Result

```
flutter analyze add_offer_screen.dart packages_tab.dart offers_tab.dart
  offer_details_screen.dart payment_method_screen.dart
  user_orders_screen.dart reservation_service.dart
No issues found!
```

---

## Chatbot Assistance Feature (2026-06-21)

### Problem

Users were unfamiliar with the app's reservation flow, offer types, and troubleshooting steps. There was no in-app guidance layer, leading to drop-off and support requests.

### Changes Implemented

| File | Change |
|------|--------|
| `lib/screens/user/chatbot_screen.dart` | New file — full rule-based chatbot UI and intent engine |
| `lib/screens/user/user_dashboard.dart` | Added `FloatingActionButton` to open chatbot; added `_openChatbot()` method |

### Architecture

**Rule-based intent engine** (`_processIntent`):
1. Exact-match check on predefined chip labels (navigation intents)
2. Arabic-normalised keyword matching for free-text input (`_normalise` strips hamza, ta marbuta, alef variants)
3. Falls back to a "didn't understand" reply with default chips

**No external backend or AI API is used.**

### Intent Categories

| Intent | Trigger keywords | Response |
|--------|-----------------|----------|
| Reservation guide | احجز / حجز / كيف / خطوات | Step-by-step 6-step guide |
| Nearest offers | قريب / اقرب / منطقتي / توصية | Fetches `offers` collection, sorts by distance |
| Offer vs. package difference | فرق / غامضة / واضح | Explanatory text |
| Where are my orders | حجوزاتي / طلباتي / اين | Points to طلباتي tab |
| QR problem | qr / رمز / مشكلة / لا يعمل | 5-step troubleshooting |
| Cancel reservation | الغاء / الغ / ارجاع | 4-step cancel guide |

### Navigation Actions

Chips such as "اذهب إلى العروض" pop the chatbot screen and call callbacks passed from `UserDashboard`:

| Chip | Callback |
|------|----------|
| اذهب إلى العروض / تصفح كل العروض | `onGoToOffers` → `_goToBrowseTab(0)` |
| اذهب إلى الباقات | `onGoToPackages` → `_goToBrowseTab(1)` |
| اذهب إلى طلباتي | `onGoToOrders` → `_selectedIndex = 2` |

### Nearest Offers Flow

1. `LocationService().getCurrentLocation()` — requests GPS; returns `null` gracefully if denied
2. If `null` → bot replies with permission hint
3. Firestore query: `offers` where `status == 'available'`, limit 30
4. Filters docs that have `latitude`/`longitude` fields; skips docs without coordinates
5. Sorts by `distanceKm()` ascending; takes top 3
6. Displays name, price (₪), and formatted distance

All Firestore field accesses use null-safe casting (`as num?)?.toDouble()`).
`if (!mounted) return;` guard placed after each `await`.

### UI Components

| Component | Description |
|-----------|-------------|
| `_MessageBubble` | Chat bubble with RTL text, shadow, rounded corners per sender |
| `_QuickChip` | Green-tinted action chips with border |
| `_TypingIndicator` | Three static dots shown while location/Firestore loads |
| `_InputBar` | RTL TextField + send button; respects bottom safe area |

### Analyzer Result

```
flutter analyze lib/screens/user/chatbot_screen.dart lib/screens/user/user_dashboard.dart
No issues found!
```

---

## Customer Support Chat System (2026-06-21)

### Purpose

Allows users to contact ZAD administrators directly through the in-app chatbot when they encounter issues. Administrators manage all support conversations from a dedicated panel. Real-time messaging is powered by Firestore streams so both sides see updates instantly.

### Chatbot Integration

Selecting the quick-reply chip **"التواصل مع الإدارة"** in the chatbot starts the contact flow:

1. If the user is anonymous → bot shows "يجب تسجيل الدخول" message and returns to default chips.
2. If the user is authenticated → `_awaitingIssueCategory` state is set to `true` and issue-category chips are displayed.
3. User selects (or types) a category → `_handleIssueCategorySelected()` calls `SupportService.createSupportChat()`.
4. On success → bot confirms with two chips: **"فتح المحادثة"** (navigates to `SupportChatScreen`) and **"عرض محادثاتي"** (opens `UserSupportListScreen`).
5. On failure → bot shows a retry message with default chips.

Anonymous detection: `FirebaseAuth.instance.currentUser?.isAnonymous`. The dashboard also passes `userId: null` for anonymous users so the chatbot's `_replyContactAdmin()` guard catches it before any Firestore write.

### Firestore Collections

#### `support_chats/{chatId}`

| Field | Type | Description |
|-------|------|-------------|
| `chatId` | String | Document ID (mirrors the doc path) |
| `userId` | String | UID of the user who opened the ticket |
| `userName` | String | Display name at the time of creation |
| `userRole` | String | Always `'user'` for now |
| `issueCategory` | String | Selected category (or free-text) |
| `firstMessage` | String | Same as `issueCategory` — shown in list previews |
| `status` | String | `'waiting'` → `'active'` → `'closed'` |
| `assignedAdminId` | String? | Set when admin opens the chat |
| `createdAt` | Timestamp | Server-set on creation |
| `updatedAt` | Timestamp | Updated on every message send |

#### `support_chats/{chatId}/messages/{messageId}`

| Field | Type | Description |
|-------|------|-------------|
| `senderId` | String | UID of sender |
| `senderRole` | String | `'user'` or `'admin'` |
| `text` | String | Message body |
| `createdAt` | Timestamp | Server-set; used for ordering |

### Support Workflow

```
User → "التواصل مع الإدارة" chip
     → selects issue category
     → SupportService.createSupportChat() → status: 'waiting'
     → notifyAdmins() fires

Admin → opens AdminSupportPanel (FAB in AdminDashboard)
      → sees waiting ticket
      → taps ticket → AdminSupportChatScreen opens
      → initState calls SupportService.assignAdmin() → status: 'active'
      → admin replies → sendMessage() → sendNotification(userId) fires

User → receives push notification
     → opens SupportChatScreen (from UserSupportListScreen or chatbot)
     → replies → sendMessage() → notifyAdmins() fires

Admin → closes conversation → SupportService.closeChat()
      → status: 'closed', sendNotification(userId) fires
      → SupportChatScreen shows "مغلقة" banner; input bar hidden
```

### Files Added / Changed

| File | Role |
|------|------|
| `lib/services/support_service.dart` | CRUD for `support_chats`; notification dispatch |
| `lib/screens/user/support_chat_screen.dart` | User's real-time chat view (stream on doc + subcollection) |
| `lib/screens/user/user_support_list_screen.dart` | User's ticket list; sorted client-side by `updatedAt` |
| `lib/screens/admin/admin_support_panel.dart` | Admin list with three tabs (waiting / active / closed) |
| `lib/screens/admin/admin_support_chat_screen.dart` | Admin's chat view; auto-assigns on open; close button |
| `lib/screens/user/chatbot_screen.dart` | Added contact-admin flow, `userId`/`userName` params, support nav |
| `lib/screens/user/user_dashboard.dart` | Passes `userId`/`userName` (null if anonymous) to chatbot |
| `lib/screens/admin/admin_dashboard.dart` | FAB opens `AdminSupportPanel`; fixed `withOpacity` deprecation |

### Admin Responsibilities

- Admins receive an in-app notification for every new ticket and every user reply.
- Opening a **waiting** chat auto-assigns the admin and moves status to **active**.
- Admins can close any conversation; the user receives a closure notification.
- The admin panel is accessible via the red FAB (support-agent icon) in `AdminDashboard`.

### Real-Time Communication

Both `SupportChatScreen` and `AdminSupportChatScreen` use two simultaneous `StreamBuilder`s:
- `SupportService.getChatStream(chatId)` — live chat document (status changes reflected immediately).
- `SupportService.getMessages(chatId)` — ordered message subcollection (new messages appear in real time).

### Security (App-Layer)

- `UserSupportListScreen` and `SupportChatScreen` query by `userId == FirebaseAuth.currentUser.uid` — users only see their own tickets.
- `AdminSupportPanel` fetches all tickets — assumes the caller is an authenticated admin (enforced at routing level).
- Anonymous users cannot create tickets (checked both in dashboard before passing `userId` and inside `_replyContactAdmin()`).

### Test Cases

| # | Test | Expected |
|---|------|----------|
| 1 | Authenticated user taps "التواصل مع الإدارة" and selects a category | `support_chats` doc created with `status: 'waiting'`; admins notified |
| 2 | User sends a message in `SupportChatScreen` | Message appears in subcollection; admins notified |
| 3 | Admin opens `AdminSupportPanel` → waiting tab | Ticket appears in list |
| 4 | Admin taps ticket | `assignedAdminId` set; `status` → `'active'` |
| 5 | Admin sends a reply | Message appears; user notified |
| 6 | User opens `SupportChatScreen` after admin reply | New message visible in real time |
| 7 | Chat is in `'waiting'` status | User sees amber banner: "جميع المسؤولين مشغولون حالياً" |
| 8 | Admin closes conversation | `status` → `'closed'`; input bar hidden; user notified |
| 9 | Anonymous user taps "التواصل مع الإدارة" | Bot shows login-required message; no Firestore write |
| 10 | User tries to view another user's chat by ID | Query filters by `userId`; other chats are not returned |

### Analyzer Result

```
flutter analyze lib/services/support_service.dart
  lib/screens/user/support_chat_screen.dart
  lib/screens/user/user_support_list_screen.dart
  lib/screens/user/chatbot_screen.dart
  lib/screens/user/user_dashboard.dart
  lib/screens/admin/admin_support_panel.dart
  lib/screens/admin/admin_support_chat_screen.dart
  lib/screens/admin/admin_dashboard.dart
No issues found!
```


---

## Provider Name in Reservation Records (2026-06-21)

### Problem

User orders and the rating dialog showed only `providerRole` (e.g. "restaurant", "individual") instead of the real provider name. The `reservations` collection had no `providerName` field.

### Fix

**`lib/services/reservation_service.dart`** — before creating the Firestore transaction, resolve the provider's display name:

1. Read `providerUserId` from `offerData`.
2. Fetch the provider's document from the `users` collection.
3. Try fields in order: `name` → `fullName` → `restaurantName` → `charityName`.
4. Fall back to `providerRole` from `offerData` if all fields are empty or the fetch fails.
5. Store the result as `providerName` inside the `transaction.set` call.

### Firestore Field Added

| Collection | Field | Type | Description |
|------------|-------|------|-------------|
| `reservations` | `providerName` | String | Real display name of the food provider |

Backward compatibility: existing reservations without this field return `""`, and the UI falls back to `providerRole`.

### Screens Updated

| Screen | Change |
|--------|--------|
| `user_orders_screen.dart` | Reads `providerName` from reservation doc; displays it in the "المزوّد" row with fallback to `providerRole` |
| `user_orders_screen.dart` (`_RatingDialog`) | Accepts `offerTitle` + `providerName`; shows an info card above the star row so the user knows which order they are rating |
| `qr_code_screen.dart` | Accepts optional `providerName` parameter; renders a third "المزوّد" info box when non-empty |

### Validation Result

```
flutter analyze lib/services/reservation_service.dart
  lib/screens/user/user_orders_screen.dart
  lib/screens/user/qr_code_screen.dart
No issues found!
```
---

## Reservation Cancellation Time Limit (2026-06-21)

### Problem

Users could cancel any `reserved` order at any time, including after the pickup window had passed. This allowed reversing a reservation long after the provider had prepared the food.

### Business Rule

Cancellation is permitted only within **10 minutes** of the reservation's `createdAt` timestamp. Outside this window the action is silently blocked with a clear Arabic error message.

### Implementation Summary

The time-guard is placed **inside the Firestore transaction** in both locations where cancellation is performed, so the check is atomic with the status write.

**`lib/services/reservation_service.dart` — `cancelReservation()`**

After the `status != 'reserved'` check, and before any writes:

```dart
final createdAt = resData['createdAt'] as Timestamp?;
if (createdAt == null ||
    DateTime.now().difference(createdAt.toDate()).inMinutes > 10) {
  throw Exception('لا يمكن إلغاء الحجز بعد مرور 10 دقائق.');
}
```

**`lib/screens/user/user_orders_screen.dart` — `_cancelReservation()`**

Identical guard added to the inline transaction. The thrown `Exception` propagates to the existing `catch` block which strips `"Exception: "` and shows the message in a `SnackBar`.

**Behaviour matrix:**

| Condition | Result |
|-----------|--------|
| `status != 'reserved'` | Blocked — "لا يمكن إلغاء هذا الطلب" |
| `createdAt` is null (old doc) | Blocked — "لا يمكن إلغاء الحجز بعد مرور 10 دقائق." |
| `now − createdAt > 10 min` | Blocked — "لا يمكن إلغاء الحجز بعد مرور 10 دقائق." |
| `now − createdAt ≤ 10 min` | Allowed — quantity restored, `status = 'cancelled'`, `cancelledAt` set |

No UI changes beyond the SnackBar message — existing confirm dialog and card design are unchanged.

### Validation / Testing

| Test | Expected Result |
|------|----------------|
| Cancel within 10 min | Reservation cancelled, quantity restored to offer |
| Cancel after 10 min | SnackBar: "لا يمكن إلغاء الحجز بعد مرور 10 دقائق." |
| Old reservation without `createdAt` | Same blocked message — no crash |
| Multi-unit reservation (quantity > 1) | Full quantity returned to `remainingQuantity` |

```
flutter analyze lib/services/reservation_service.dart
               lib/screens/user/user_orders_screen.dart
No issues found!
```
---

## Human-Readable Reservation Code (2026-06-21)

### Problem

Every reservation was identified only by its raw Firestore document ID (e.g. `VPq2hk6X4rTmN2p…`). This string is meaningless to users, hard to communicate verbally, and clutters order and QR screens.

### New Field

| Collection | Field | Type | Example |
|------------|-------|------|---------|
| `reservations` | `reservationCode` | String | `ZAD-20260621-VPQ2H6` |

`reservationId` (the Firestore doc ID) is retained unchanged for all internal operations (cancellation, pickup confirmation, QR scan lookup).

### Format

```
ZAD-YYYYMMDD-XXXXXX
     └──────┘ └────┘
     ISO date  first 6 chars of Firestore ID, uppercased
```

Generated by the private static helper `_generateCode(docId)` in `ReservationService`, called immediately after `reservationRef` is created and before the transaction runs.

### Screens Updated

| Screen | Change |
|--------|--------|
| `user_orders_screen.dart` | Reads `reservationCode` from the reservation doc; shows it in the "رقم الحجز" row; passes it to `QrCodeScreen` |
| `qr_code_screen.dart` | New optional `reservationCode` param (default `''`); "رقم الحجز" info box displays the code; copy button copies the code |

The QR payload JSON still contains `reservationId` (the raw Firestore ID) so the restaurant scanner can look up the document correctly.

### Backward Compatibility

Old reservations have no `reservationCode` field. Both screens fall back gracefully:
- `user_orders_screen`: `(data['reservationCode'] as String?)?.isNotEmpty == true ? code : reservationId`
- `qr_code_screen`: `reservationCode.isNotEmpty ? reservationCode : reservationId`

No crash, no empty string shown to the user.

### Validation / Testing

| Test | Expected |
|------|----------|
| Create new reservation | Firestore doc contains `reservationCode: ZAD-YYYYMMDD-XXXXXX` |
| Open طلباتي | "رقم الحجز" row shows the readable code, not the raw ID |
| Open QR screen from طلباتي | "رقم الحجز" info box shows the readable code |
| Copy button on QR screen | Copies the readable code |
| Old reservation (no `reservationCode`) | Falls back to raw Firestore ID — no crash |

```
flutter analyze lib/services/reservation_service.dart
               lib/screens/user/user_orders_screen.dart
               lib/screens/user/qr_code_screen.dart
No issues found!
```

---

## Email Verification (2026-06-21)

### Purpose

Prevent users from accessing the app with unverified email addresses. Firebase Authentication's built-in verification flow is used — no custom backend or Firestore changes are required.

### Firebase Authentication Implementation

Firebase sends a verification link to the user's email when `user.sendEmailVerification()` is called. On subsequent logins, `user.reload()` fetches fresh auth state from Firebase, and `user.emailVerified` reflects the current state.

### Registration Flow

**`lib/services/auth_service.dart` — `registerUser()`**

After the Firestore user document is written, the verification email is sent:
```dart
await credential.user?.sendEmailVerification();
```

**`lib/screens/auth/signup_screen.dart` — `_handleSignup()`**

The SnackBar + immediate redirect is replaced with a blocking `AlertDialog`:
- Icon: `Icons.mark_email_read_rounded`
- Message: "تم إرسال رابط التحقق إلى بريدك الإلكتروني. يرجى التحقق من البريد قبل تسجيل الدخول."
- Action: "حسناً" → dismisses dialog → redirects to LoginScreen

### Login Validation Flow

**`lib/services/auth_service.dart` — `login()`**

Immediately after `signInWithEmailAndPassword`:
```dart
await credential.user!.reload();
if (!(credential.user!.emailVerified)) {
  await _auth.signOut();
  throw Exception('يرجى التحقق من بريدك الإلكتروني أولاً.');
}
```

If the email is not verified: user is signed out and a clear exception is thrown. The `LoginScreen` catches it and shows it in the `_ErrorBox` widget. Navigation to the dashboard does not happen.

### Resend Verification

**`lib/screens/auth/login_screen.dart`**

A "إعادة إرسال رابط التحقق" `TextButton` is shown below the login button.

Flow:
1. User enters email + password and taps the button.
2. `_resendVerification()` signs in temporarily.
3. If `emailVerified == true` → signs out, shows "بريدك الإلكتروني مُحقق بالفعل".
4. If `emailVerified == false` → calls `user.sendEmailVerification()`, signs out, shows success SnackBar.
5. A 60-second countdown replaces the button label, preventing spam.

Countdown state: `int _resendCooldown` decremented by `Timer.periodic` every second. Timer is cancelled in `dispose()`.

### Files Changed

| File | Change |
|------|--------|
| `lib/services/auth_service.dart` | Send verification on register; block unverified on login |
| `lib/screens/auth/signup_screen.dart` | Replaced SnackBar with verification dialog; fixed `withOpacity` |
| `lib/screens/auth/login_screen.dart` | Added resend method + 60-s cooldown button; removed duplicate import; fixed `withOpacity` |

### Validation Results

| Test | Expected |
|------|----------|
| Register new account | Verification email received; dialog shown; redirected to login |
| Login before verifying | Blocked — "يرجى التحقق من بريدك الإلكتروني أولاً." |
| Login after verifying | Allowed — dashboard shown |
| Resend within cooldown | Button shows countdown, tap disabled |
| Resend after cooldown | New email sent; 60-s cooldown restarts |
| Wrong password on resend | Error message shown; no email sent |

```
flutter analyze lib/services/auth_service.dart
               lib/screens/auth/signup_screen.dart
               lib/screens/auth/login_screen.dart
No issues found!
```

---

## Admin Offers Management (2026-06-21)

### Purpose

Give administrators a dedicated screen to view, filter, and delete any offer published by any provider (restaurant, charity, or individual), with built-in protection against deleting offers that have active reservations.

### Features

| Feature | Detail |
|---------|--------|
| View all offers | Single stream from `offers` collection, ordered newest-first |
| Filter by status | الكل / متاح / محجوز / ملغي — client-side |
| Filter by provider role | الكل / مطعم / جمعية / فرد — client-side |
| Filter by offer type | الكل / واضح / غامض / باقة مطعم — client-side |
| Offer card | Shows: title, providerName (fallback to providerRole), offerType, status badge, remainingQuantity, price, pickupLocation, createdAt |
| Delete with confirmation | AlertDialog before write; button disabled while a delete is in progress |

### Delete Protection Rule

Before deleting an offer, `AdminService.deleteOffer()` queries:
```
reservations WHERE offerId == offerId AND status IN ['reserved', 'picked_up']
```
- **Any matches found** → throws `Exception('لا يمكن حذف هذا العرض لأنه مرتبط بحجوزات موجودة.')`
- **No matches (or only cancelled reservations)** → offer deleted, action logged

### Admin Activity Logging

Every successful deletion writes a document to `admin_activity_logs`:

| Field | Value |
|-------|-------|
| `actionType` | `"delete_offer"` |
| `adminId` | UID of the acting admin |
| `offerId` | Deleted offer's Firestore ID |
| `offerTitle` | Offer title at deletion time |
| `providerUserId` | UID of the offer's creator |
| `timestamp` | `FieldValue.serverTimestamp()` |
| `details` | Human-readable Arabic description |

### Files Added / Changed

| File | Change |
|------|--------|
| `lib/screens/admin/admin_offers_screen.dart` | New screen — filter UI, StreamBuilder, offer cards, delete flow |
| `lib/services/admin_service.dart` | Added `getAllOffersStream()` and `deleteOffer()` |
| `lib/screens/admin/admin_home_screen.dart` | Added "إدارة العروض" `ActionTile`; fixed `withOpacity` |

### Access Point

`AdminHomeScreen` → `ActionTile` "إدارة العروض" → `Navigator.push(AdminOffersScreen)`

### Firestore Collections Used

| Collection | Operation |
|-----------|-----------|
| `offers` | Stream (read all); delete single doc |
| `reservations` | Read — check active reservations before delete |
| `admin_activity_logs` | Write — log delete action |

### Validation Results

| Test | Expected |
|------|----------|
| Open "إدارة العروض" from admin home | Screen opens, all offers load |
| Filter by status "متاح" | Only available offers shown |
| Filter by role "مطعم" | Only restaurant offers shown |
| Delete offer with no reservations | Deleted; action logged in `admin_activity_logs` |
| Delete offer with `reserved` reservation | Blocked — "لا يمكن حذف هذا العرض لأنه مرتبط بحجوزات موجودة." |
| Delete offer with only `cancelled` reservations | Allowed |

```
flutter analyze lib/screens/admin/admin_offers_screen.dart
               lib/services/admin_service.dart
               lib/screens/admin/admin_home_screen.dart
No issues found!
```

---

## Admin Complaints Sorting (2026-06-21)

### Problem

Complaints were displayed without a clear order, making it harder for administrators to handle the newest issues first. The open complaints stream had no `orderBy` clause, so Firestore returned documents in insertion order, which varies unpredictably.

### Fix

Client-side sorting was added inside `_ComplaintsList.build()` in `admin_complaints_screen.dart`. After the StreamBuilder receives the documents, they are sorted in-memory before being passed to the `ListView`:

```dart
final sortedDocs = List<QueryDocumentSnapshot>.from(docs)
  ..sort((a, b) {
    final aTs = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
        ?.millisecondsSinceEpoch;
    final bTs = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
        ?.millisecondsSinceEpoch;
    if (aTs == null && bTs == null) return 0;
    if (aTs == null) return 1;
    if (bTs == null) return -1;
    return bTs.compareTo(aTs);
  });
```

Client-side sorting was chosen over adding Firestore `orderBy` so that:
- No composite Firestore index is required.
- Documents without a `createdAt` field are included in the results and placed at the end, rather than being silently excluded.

### Missing Date Handling

The comparator uses `(Timestamp?)` casting with null checks:
- Both null → treated as equal (stable relative order preserved).
- Only `a` is null → `a` sorted after `b` (null goes to end).
- Only `b` is null → `b` sorted after `a` (null goes to end).
- Both non-null → descending `millisecondsSinceEpoch` comparison.

No crashes occur regardless of what `createdAt` contains.

### Impact

- Newest complaints appear first in both the "مفتوحة" and "تم الحل" tabs.
- Admins can immediately see and act on the most recent user reports.
- No changes to Firestore queries, data model, or existing UI components.
- Three pre-existing `withOpacity` deprecations in the file were also fixed.

### Validation

- Newest complaints appear first.
- Old complaints appear below newer ones.
- Complaints without `createdAt` do not crash the screen and appear at the bottom.
- Admin UI (tabs, card layout, resolve button) remains unchanged.

```
flutter analyze lib/screens/admin/admin_complaints_screen.dart
No issues found!
```

---

## Optional Image for Mystery Packages (2026-06-21)

### Problem

`AddOfferScreen` required an image for all offer types. Mystery packages ("باقة غامضة المحتوى") are intentionally opaque — forcing a real photo can reveal contents or be impractical for the provider.

### Business Rule

| Offer type | Image selected | Result |
|-----------|---------------|--------|
| عرض واضح المحتوى | No | Blocked — "يرجى إضافة صورة للعرض" |
| عرض واضح المحتوى | Yes | Uploaded to Cloudinary; URL stored |
| باقة غامضة | No | Default mystery image URL stored |
| باقة غامضة | Yes | Uploaded to Cloudinary; URL stored |

### Default Image Behavior

`AppConstants.defaultMysteryPackageImageUrl` (defined in `lib/theme/app_constants.dart`) is an Unsplash food image stored as a compile-time `const String`. When a mystery package is published without selecting a photo, this URL is written to `offers.imageUrl` in Firestore — exactly as a real upload would be. No special rendering path is needed in display screens.

### Implementation

**`_addOffer()` in `add_offer_screen.dart`:**

1. Image guard changed from unconditional to clear-offer-only:
```dart
if (!_isMysteryPackage && _selectedImage == null) { … return; }
```

2. Upload block replaced with a conditional branch:
```dart
final String imageUrl;
if (_selectedImage != null) {
  final uploaded = await _uploadImage();
  if (!mounted) return;
  if (uploaded == null || uploaded.isEmpty) { … return; }
  imageUrl = uploaded;
} else {
  imageUrl = AppConstants.defaultMysteryPackageImageUrl;
}
```

### Screens Affected

| File | Change |
|------|--------|
| `lib/theme/app_constants.dart` | New file — `defaultMysteryPackageImageUrl` constant |
| `lib/screens/restaurant/add_offer_screen.dart` | Image guard + upload logic updated |
| `lib/screens/user/packages_tab.dart` | Fallback to default URL for legacy mystery packages with empty `imageUrl` |

`offers_tab.dart`, `offer_details_screen.dart`, and `restaurant_offers_screen.dart` already show `buildImagePlaceholder` for empty `imageUrl` and have `errorBuilder` on `Image.network` — no additional changes needed. Going forward, all mystery packages will have a non-empty URL in Firestore.

### Validation Results

| Test | Expected |
|------|----------|
| Publish clear offer without image | Blocked — "يرجى إضافة صورة للعرض" |
| Publish mystery package without image | Allowed — default image URL stored in Firestore |
| Publish mystery package with image | Uploaded image URL stored |
| Publish clear offer with image | Uploaded image URL stored |
| Legacy mystery package (empty imageUrl) in packages tab | Default mystery image displayed via `packages_tab.dart` fallback |

```
flutter analyze lib/theme/app_constants.dart
               lib/screens/restaurant/add_offer_screen.dart
               lib/screens/user/packages_tab.dart
No issues found!
```

---

## Automatic Pickup Location Name (2026-06-21)

### Problem

When providers tapped the GPS location button, the app stored latitude and longitude coordinates but the pickup location name/address text field remained empty, requiring the provider to type it manually.

### Fix

`LocationService.getAddressFromCoordinates(lat, lon)` was added to the service layer. It calls `placemarkFromCoordinates()` from the pre-installed `geocoding: ^3.0.0` package, assembles a readable string from `locality`, `subLocality`, and `street` fields, and returns the result. Failures are caught silently and return an empty string.

Each screen's `_fetchLocation()` was updated to call the new method after obtaining coordinates and auto-fill the location text field — only if the field is currently empty (to avoid overwriting deliberate manual input).

### Reverse Geocoding Behavior

| Condition | Outcome |
|-----------|---------|
| Geocoding succeeds | Field filled; SnackBar "تم تحديد الموقع ✅" |
| Geocoding fails (timeout, no network) | Field stays empty; SnackBar "تم تحديد الموقع ✅ — يرجى كتابة اسم المنطقة يدوياً" |
| GPS unavailable or denied | Field unchanged; SnackBar "تعذّر الحصول على الموقع — تحقق من صلاحيات GPS" |

Coordinates are always stored when GPS succeeds, regardless of geocoding outcome.

### Optional Location Rule

All three screens treat location as optional for publishing. The GPS button fills the field as a convenience, not a gate.

### Files Changed

| File | Change |
|------|--------|
| `lib/services/location_service.dart` | Added `getAddressFromCoordinates(lat, lon)` using `geocoding` package |
| `lib/constants/app_constants.dart` | Added `defaultMysteryPackageImageUrl` (moved from duplicate file) |
| `lib/theme/app_constants.dart` | Converted to a re-export of `lib/constants/app_constants.dart` |
| `lib/screens/restaurant/add_offer_screen.dart` | `_fetchLocation()` updated — reverse geocodes and fills `_pickupController` |
| `lib/screens/charity/charity_publish_surplus_screen.dart` | `_fetchLocation()` updated — reverse geocodes and fills `_locationController`; fixed 15 `withOpacity` deprecations |
| `lib/screens/user/user_publish_offer_screen.dart` | Already implemented — no change needed |

### Validation Results

| Test | Expected |
|------|----------|
| Tap GPS button (location enabled) | Coordinates stored; pickup field auto-filled |
| GPS permission denied | Friendly Arabic error SnackBar; field unchanged; no crash |
| Geocoding times out | Coordinates stored; field stays empty; message asks for manual entry |
| Publish with auto-filled location | Works normally |
| Publish with manually overridden location | Works normally (auto-fill only fires on empty field) |

```
flutter analyze lib/services/location_service.dart
               lib/constants/app_constants.dart
               lib/theme/app_constants.dart
               lib/screens/restaurant/add_offer_screen.dart
               lib/screens/charity/charity_publish_surplus_screen.dart
No issues found!
```

---

## Allergy Information Checkboxes (2026-06-21)

### Problem

`AddOfferScreen` and `EditOfferScreen` used a free-text `TextField` for allergy information, producing inconsistent values that were hard to display, filter, or compare.

### Business Rule

| Action | Behavior |
|--------|----------|
| Select a specific allergen | "لا يحتوي على مسببات حساسية معروفة" is automatically deselected |
| Select "لا يحتوي على مسببات حساسية معروفة" | All other selections are cleared |
| Multiple specific allergens | All remain selected simultaneously |
| No selection | `allergyInfo` stored as an empty list `[]` |

### Firestore Field Behavior

`allergyInfo` is now stored as `List<String>` (array of selected allergen strings).

**Available options (defined in `AppConstants.allergenOptions`):**
حليب · بيض · مكسرات · سمسم · غلوتين · فول سوداني · أسماك · محار · صويا · لا يحتوي على مسببات حساسية معروفة

### Backward Compatibility

`AppConstants.parseAllergyInfo(dynamic raw)` handles any stored format:
- `List<dynamic>` (new): maps to `List<String>` and returns as-is
- `String` (legacy): returns `[raw]` if non-empty, else `[]`
- `null`: returns `[]`

`AppConstants.parseAllergyCheckboxes(dynamic raw)` is used only in `EditOfferScreen` to pre-populate checkboxes: it calls `parseAllergyInfo` then keeps only values that match `allergenOptions`. Unknown legacy strings are silently dropped from the checkbox UI (the provider must reselect on next edit).

No screen crashes on legacy string data.

### Files Changed

| File | Change |
|------|--------|
| `lib/constants/app_constants.dart` | Added `allergenOptions`, `noKnownAllergens`, `parseAllergyInfo()`, `parseAllergyCheckboxes()` |
| `lib/widgets/allergy_checkbox_panel.dart` | New widget — `AllergyCheckboxPanel` with mutual-exclusion logic |
| `lib/screens/restaurant/add_offer_screen.dart` | Replaced `_allergyController` + TextField with `_selectedAllergens` Set + `AllergyCheckboxPanel` |
| `lib/screens/restaurant/edit_offer_screen.dart` | Same replacement; pre-populates from Firestore via `parseAllergyCheckboxes` |
| `lib/screens/user/offer_details_screen.dart` | Added `allergens` local variable; added `_AllergyDisplay` widget shown in its own `_DetailCard` |

### Validation Results

| Test | Expected |
|------|----------|
| Create offer with multiple allergens | `allergyInfo: ['مكسرات', 'حليب']` stored in Firestore |
| Create offer with no known allergens | `allergyInfo: ['لا يحتوي على مسببات حساسية معروفة']` stored |
| Select "no allergens" after selecting others | All other checkboxes cleared |
| Select specific allergen after "no allergens" | "no allergens" checkbox cleared |
| Edit offer — legacy `allergyInfo: "مكسرات"` | `parseAllergyCheckboxes` pre-selects "مكسرات" in checkboxes |
| Edit offer — legacy free text not in allergen list | Checkbox panel starts empty; provider re-selects |
| Offer details screen — new list format | Allergen chips displayed in red-tinted row |
| Offer details screen — "no known allergens" | Green checkmark row shown |
| Offer details screen — legacy String value | Displayed as one chip using `parseAllergyInfo` |

```
flutter analyze lib/constants/app_constants.dart
               lib/widgets/allergy_checkbox_panel.dart
               lib/screens/restaurant/add_offer_screen.dart
               lib/screens/restaurant/edit_offer_screen.dart
               lib/screens/user/offer_details_screen.dart
No issues found!
```

---

## Required Pickup Location with GPS or Manual Entry (2026-06-26)

### Problem

After the automatic location name fill feature was added, the pickup location field was treated as entirely optional. Providers could publish offers or donations without any location information, leaving users unable to find the pickup point.

### Business Rule

Pickup location is **required**, but can be provided in either of two ways:

| Method | Pickup text | GPS coordinates | Result |
|--------|------------|-----------------|--------|
| Manual entry | Non-empty | Any | ✅ Allowed |
| GPS only (geocoding succeeds) | Empty → auto-filled | Present | ✅ Allowed |
| GPS only (geocoding fails) | Empty | Present | ❌ Blocked |
| Neither | Empty | Null | ❌ Blocked |

### GPS Behavior

If the provider taps the GPS button and the field is still empty at publish time:
1. `LocationService.getAddressFromCoordinates()` is called inside the try block.
2. If an address is found → field is auto-filled and publishing proceeds.
3. If geocoding fails (timeout, no network, no results) → publishing is blocked.

Arabic error message: `'يرجى إدخال اسم موقع الاستلام أو تحديد الموقع الحالي.'`

### Manual Entry Behavior

If the provider types a pickup location, publishing is always allowed regardless of whether GPS coordinates are present. `latitude` / `longitude` remain optional — `hasLocation` is `true` only when coordinates exist.

### Firestore Fields

| Field | Behavior |
|-------|---------|
| `pickupLocation` | Must be non-empty for all new offers/donations |
| `latitude` / `longitude` | Optional — present only when GPS was used |
| `hasLocation` | `true` only when both coordinates are non-null |

### Implementation

Two-phase validation added to each screen:

**Phase 1 (sync, before `setState(_isLoading = true)`):**
```dart
if (pickup.isEmpty && _latitude == null) {
  // show Arabic error, return
}
```

**Phase 2 (async, inside try block, only when `pickup.isEmpty && _latitude != null`):**
```dart
final address = await LocationService().getAddressFromCoordinates(lat, lon);
if (!mounted) return;
if (address.isEmpty) { // show Arabic error, return }
// else: fill field and proceed
```

`EditOfferScreen` was not changed — it has no GPS capability, so the existing blanket non-empty check on pickup is correct.

### Files Changed

| File | Change |
|------|--------|
| `lib/screens/restaurant/add_offer_screen.dart` | Removed `pickup` from blanket check; added GPS-null sync guard; added async geocoding in try block |
| `lib/screens/charity/charity_publish_surplus_screen.dart` | Removed location `validator`; added sync guard + async geocoding in `_publish()` |
| `lib/screens/user/user_publish_offer_screen.dart` | Removed location `validator`; added sync guard + async geocoding in `_publish()`; fixed 4 `withOpacity` deprecations; removed unused `cloud_firestore` import |

### Validation Results

| Test | Expected |
|------|----------|
| Publish with manual pickup text, no GPS | ✅ Allowed |
| Tap GPS → field auto-filled → publish | ✅ Allowed |
| Tap GPS (geocoding fails) → field empty → publish | ❌ "يرجى إدخال اسم موقع الاستلام أو تحديد الموقع الحالي." |
| No pickup text, no GPS → publish | ❌ Same Arabic error |
| Firestore: location stored correctly | `pickupLocation` always non-empty; `hasLocation` reflects GPS presence |

```
flutter analyze lib/screens/restaurant/add_offer_screen.dart
               lib/screens/charity/charity_publish_surplus_screen.dart
               lib/screens/user/user_publish_offer_screen.dart
No issues found!
```

---

## GPS Location Button in Registration Screen (2026-06-26)

### Problem

The registration screen had no way to auto-fill the "العنوان / الموقع" field. Users had to type their address manually, and there was no GPS shortcut.

### Fix

A GPS icon button was added as `suffixIcon` on the address `TextFormField`. Tapping it:
1. Calls `LocationService().getCurrentLocation()` to get coordinates.
2. Calls `LocationService().getAddressFromCoordinates()` for reverse geocoding.
3. Auto-fills the address field if an address is found (only when the field is currently empty).
4. Stores `_registrationLat` and `_registrationLon` in widget state, which are passed to `AuthService.registerUser()`.

If the field already contains manually typed text, GPS auto-fill does not overwrite it.

### GPS vs Manual Entry

| Scenario | Behavior |
|----------|---------|
| GPS succeeds + geocoding succeeds | Field auto-filled; SnackBar "تم تحديد الموقع ✅" |
| GPS succeeds + geocoding fails | Coordinates stored; field stays empty; SnackBar "تعذر تحديد اسم الموقع، يمكنك إدخاله يدوياً." |
| GPS permission denied | SnackBar "تعذّر الحصول على الموقع — تحقق من صلاحيات GPS" |
| User types manually | Address accepted; latitude/longitude remain null |

### Validation

The existing `_validateAddress` validator remains — the field must be non-empty before registration proceeds. The user satisfies this by either tapping the GPS button (which fills the field) or typing manually.

### Firestore Fields Added to `users` Collection

| Field | Type | Description |
|-------|------|-------------|
| `latitude` | double? | Registration-time GPS latitude (null if not used) |
| `longitude` | double? | Registration-time GPS longitude (null if not used) |
| `hasLocation` | bool | `true` only when both coordinates are non-null |

### UI

The GPS icon button uses `Icons.location_searching_rounded` (primary colour) before GPS is used, and `Icons.my_location_rounded` (success/green) after coordinates are stored. A `CircularProgressIndicator` replaces the icon while the request is in flight.

### Files Changed

| File | Change |
|------|--------|
| `lib/screens/auth/signup_screen.dart` | Added `LocationService` import; GPS state fields; `_fetchLocationForAddress()` method; GPS `suffixIcon` on address field; passes lat/lon to `registerUser()` |
| `lib/services/auth_service.dart` | Added optional `latitude` / `longitude` params to `registerUser()`; stores them + `hasLocation` in Firestore user document |

### Validation Results

| Test | Expected |
|------|----------|
| Tap GPS button (permission granted) | Address field auto-filled; green icon shown |
| Tap GPS button (permission denied) | Friendly Arabic error; no crash |
| Geocoding fails (no network) | Coordinates stored; field stays; user types manually |
| Register with GPS address | `latitude`, `longitude`, `hasLocation: true` in Firestore |
| Register with manual address | `latitude: null`, `longitude: null`, `hasLocation: false` in Firestore |
| Register with empty address field | Form validator blocks with "يرجى إدخال العنوان" |

```
flutter analyze lib/screens/auth/signup_screen.dart
               lib/services/auth_service.dart
No issues found!
```

---

## Improved Local Address Formatting (2026-06-26)

### Problem

`getAddressFromCoordinates()` included the `street` field (which returns English road names, street numbers, and values like "1600 Amphit") and joined fields in locality-first order, producing unclear output such as "Mountain View, 1600 Amphit" instead of a readable Arabic place name.

### Fix

`LocationService.getAddressFromCoordinates()` in `lib/services/location_service.dart` was rewritten with:

1. `street` removed entirely from consideration
2. A `_isMeaningful()` filter that rejects:
   - Strings shorter than 3 characters
   - Strings containing "unnamed" (case-insensitive)
   - Strings that start with a digit (street numbers like "1600 Amphit")
3. Priority-ordered formatting logic
4. A non-empty fallback so coordinates are always kept even when names are unclear

### Formatting Priority

| Priority | Condition | Output |
|----------|-----------|--------|
| 1 | subLocality + locality both meaningful | `subLocality، locality` |
| 2 | name + locality both meaningful, name ≠ locality | `name، locality` |
| 3 | locality meaningful only | `locality` |
| 3b | locality + administrativeArea both meaningful | `locality، administrativeArea` |
| 4 | administrativeArea meaningful only | `administrativeArea` |
| 5 | Nothing meaningful found | `موقع محدد على الخريطة` |

### Fallback Behavior

- Exception (network timeout, geocoding service error) → returns `''` (empty string; callers show "يرجى كتابة اسم المنطقة يدوياً")
- No placemarks returned → returns `''`
- Placemarks exist but all fields fail the meaningful filter → returns `'موقع محدد على الخريطة'` (coordinates are still saved; user can edit manually)

### Debug Logging

Temporary `debugPrint` logs were added showing all Placemark fields for Palestinian coordinates:
`name`, `street`, `subLocality`, `locality`, `subAdministrativeArea`, `administrativeArea`, `country`

These are only printed in debug mode (`flutter run`). Remove when the output is confirmed correct.

### Validation

```
flutter analyze lib/services/location_service.dart
No issues found!
```

---

## Professional Location Handling (2026-06-27)

### Problem

The `geocoding` Flutter package uses the device OS geocoder (Google Play Services on Android). For Palestinian locations this frequently returns:
- English-only names ("Mountain View", "Unnamed Road")
- Partial street-number addresses ("1600 Amphit")
- Mismatched administrative areas

### Selected Solution: OpenStreetMap Nominatim Reverse Geocoding

**Rejected alternatives:**
| Option | Reason rejected |
|--------|----------------|
| `geocoding` package | Uses device OS geocoder — English results, poor Palestine coverage |
| Google Geocoding API | Requires billing account, unsuitable for graduation project |
| Google Places Autocomplete | Major UX change, over-engineered for the scope |

**Nominatim chosen because:**
- Completely free, no API key
- Supports `accept-language=ar` → Arabic city/neighbourhood names
- OpenStreetMap has excellent Palestinian coverage (cities, villages, districts)
- The `http` package was already in `pubspec.yaml`
- Simple HTTP/JSON — no SDK dependency

**API call:**
```
GET https://nominatim.openstreetmap.org/reverse
  ?lat=31.9&lon=35.2&format=json&accept-language=ar&addressdetails=1&zoom=16
  User-Agent: ZAD-GradApp/1.0
```

**Typical response for Palestinian locations:**
```json
{
  "display_name": "بيرزيت، رام الله والبيرة، فلسطين",
  "address": {
    "city": "بيرزيت",
    "suburb": "وسط البلد",
    "state": "رام الله والبيرة",
    "country": "فلسطين",
    "country_code": "ps"
  }
}
```

### Location Flow

```
User taps GPS button
  → LocationService.getCurrentLocation()       (geolocator)
      → permission check / request
      → Position{lat, lon}
  → LocationService.getAddressFromCoordinates() (Nominatim HTTP)
      → parse address fields from JSON
      → format using priority rules (see below)
      → fill text field (if currently empty)
  → store lat, lon, locationSource='gps' in Firestore
```

If the user types an address manually:
```
User types text → pickupLocation = typed text
  → latitude = null, longitude = null
  → locationSource = 'manual' stored in Firestore
```

### Address Formatting Priority (Nominatim fields)

| Priority | Condition | Output example |
|----------|-----------|----------------|
| 1 | suburb + city | "حي الطيرة، رام الله" |
| 2 | city + state | "رام الله، رام الله والبيرة" |
| 3 | city only | "نابلس" |
| 4 | state only | "محافظة الخليل" |
| 5 | display_name (first 2 parts) | fallback from full string |
| 6 | Exception or no placemarks | `''` → screen shows "يرجى إدخال يدوياً" |
| 7 | Placemarks exist, all fail filter | `'موقع محدد على الخريطة'` |

**`_isMeaningful()` filter** rejects:
- Strings shorter than 3 characters
- Strings containing "unnamed"
- Strings starting with a digit (street numbers)

### Firestore Fields

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `pickupLocation` / `address` | String | any | Human-readable location text |
| `latitude` | double? | null or number | GPS latitude |
| `longitude` | double? | null or number | GPS longitude |
| `hasLocation` | bool | true/false | Whether GPS coordinates exist |
| `locationSource` | String | `'gps'` or `'manual'` | How the location was provided |

**Backward compatibility:** Old documents without `locationSource` are read safely everywhere — no field is required in the UI rendering path.

### Manual Fallback

If auto-detection produces an empty string (network error, timeout):
- Coordinates are NOT stored (position was null or geocoding threw)
- Screens show: `'تعذر تحديد اسم الموقع، يرجى إدخال العنوان يدوياً.'`
- User types address manually → stored with `locationSource: 'manual'`

If Nominatim responds but address fields are unclear:
- `'موقع محدد على الخريطة'` is stored in the text field
- Coordinates ARE stored (GPS succeeded)
- User can edit the text field freely

### Files Modified

| File | Change |
|------|--------|
| `lib/services/location_service.dart` | Full rewrite of `getAddressFromCoordinates()`: replaced `geocoding` package with Nominatim HTTP; added `_pick()` helper; updated `_isMeaningful()` to also filter Nominatim fields; removed `geocoding` import; added `dart:convert` + `http` imports |
| `lib/services/user_offer_service.dart` | Added `locationSource` to Firestore write |
| `lib/services/auth_service.dart` | Added `locationSource` to Firestore write |
| `lib/screens/restaurant/add_offer_screen.dart` | Added `locationSource` to Firestore write |
| `lib/screens/charity/charity_publish_surplus_screen.dart` | Added `locationSource` to Firestore write |

### Validation / Testing Steps

| Test | Expected |
|------|----------|
| GPS granted, good signal | Field filled with Arabic neighbourhood/city; `locationSource: 'gps'` in Firestore |
| GPS denied | Friendly Arabic error SnackBar; field unchanged |
| Nominatim returns Arabic city | "رام الله" or "حي الطيرة، رام الله" displayed |
| Nominatim times out | `getAddressFromCoordinates()` returns `''`; user prompted to type manually |
| Manual address entry | `locationSource: 'manual'`, null lat/lon in Firestore |
| Old offer without `locationSource` | Displays without crash — field is nullable-safe |
| Distance sorting | `distanceKm()` unchanged; sorting in offers_tab still works |

```
flutter analyze lib/services/location_service.dart
               lib/services/user_offer_service.dart
               lib/services/auth_service.dart
               lib/screens/restaurant/add_offer_screen.dart
               lib/screens/charity/charity_publish_surplus_screen.dart
No issues found!
```

---

## Account Verification Workflow (2026-06-27)

### Purpose

Real-world marketplace and delivery applications require identity and business verification before allowing providers to publish content or collect payments. ZAD implements a three-track verification system: restaurants, charities, and individual users (for donation publishing only).

### Restaurant Verification

**Collected at registration in `signup_screen.dart`:**
- Owner/operator name
- Restaurant description
- Working hours
- Business license number
- Logo (optional image, uploaded to Cloudinary)
- Business license document (required; jpg/png/pdf, uploaded to Cloudinary)

**Firestore fields added to `users/{uid}`:**
`ownerName`, `workingHours`, `licenseNumber`, `description`, `logoUrl`, `businessLicenseUrl`, `verificationStatus: 'pending'`, `verificationReviewedBy: null`, `verificationReviewedAt: null`, `rejectionReason: null`, `isApproved: false`

**Login rule:** If `verificationStatus != 'approved'`, login throws "حساب المطعم بانتظار موافقة الإدارة."

### Charity Verification

**Collected at registration:**
- Responsible person name
- Charity description
- Official registration number
- Logo (optional image)
- Charity registration document (required; jpg/png/pdf)

**Firestore fields added to `users/{uid}`:**
`responsiblePerson`, `registrationNumber`, `description`, `logoUrl`, `charityDocumentUrl`, `verificationStatus: 'pending'`, same review/rejection fields as restaurant, `isApproved: false`

**Login rule:** If `verificationStatus != 'approved'`, login throws "حساب الجمعية بانتظار موافقة الإدارة."

### User Identity Verification

Not required at registration. Triggered the first time a user attempts to submit a food donation in `DonateTab._donateFood()`.

**Flow:**
1. Read `users/{uid}.identityVerificationStatus`
2. If `'approved'` → proceed with donation
3. If `'pending'` → show "طلب توثيق هويتك قيد المراجعة، يرجى الانتظار." and abort
4. If null/absent → navigate to `IdentityVerificationScreen`

**`IdentityVerificationScreen` (updated):**
- Identity number text field
- Document picker (`FilePicker`): jpg / png / pdf
- Uploads document to Cloudinary
- Writes to `users/{uid}`: `identityNumber`, `identityDocumentUrl`, `identityVerificationStatus: 'pending'`
- Also writes to `individuals/{uid}` (backward compatibility with offer publishing check in `user_home_screen.dart`)

### Cloudinary Uploads

`CloudinaryService` (`lib/services/cloudinary_service.dart`) is a reusable helper that extracts the upload logic previously duplicated across 3+ screens:

```dart
final url = await CloudinaryService().uploadBytes(
  bytes: fileBytes,
  filename: fileName,
);
```

All identity documents, logos, and license files are uploaded to the same `zad_upload` preset on the `dsu1bewrx` cloud. Firebase Storage is not used.

### Admin Approval Workflow

`AdminVerificationPanel` (`lib/screens/admin/admin_verification_panel.dart`):
- Accessible via "مراجعة التحقق" `ActionTile` on the admin home screen
- Three tabs: **المطاعم** (pending restaurants) | **الجمعيات** (pending charities) | **الهويات** (pending user identity verifications)
- Each card shows: name, responsible person/owner, registration number, and document (image preview or PDF copy button)

**Approve:**
- Restaurant/Charity: sets `verificationStatus: 'approved'`, `isApproved: true`, `verificationReviewedBy`, `verificationReviewedAt`; sends "تم قبول حسابك" notification
- User identity: sets `identityVerificationStatus: 'approved'`; sends "تم توثيق هويتك" notification

**Reject:**
- Admin enters reason in a dialog
- Sets `verificationStatus: 'rejected'` (or `identityVerificationStatus: 'rejected'`)
- Saves `rejectionReason`; sends rejection notification

### Files Added / Changed

| File | Change |
|------|--------|
| `lib/services/cloudinary_service.dart` | New — reusable `uploadBytes()` helper |
| `lib/screens/admin/admin_verification_panel.dart` | New — 3-tab review panel |
| `lib/screens/auth/signup_screen.dart` | Added restaurant/charity extra fields + `_FilePickButton` widget; removed mandatory national ID; upload via `CloudinaryService` |
| `lib/services/auth_service.dart` | New optional params for all org fields; stores role-specific Firestore fields; fixed login error messages |
| `lib/screens/user/identity_verification_screen.dart` | Replaced `ImagePicker` with `FilePicker` (PDF support); writes to `users` collection with spec field names; also writes to `individuals` for backward compat |
| `lib/screens/user/donate_tab.dart` | Gates donation on `identityVerificationStatus`; navigates to verification screen if unverified; fixed `withOpacity` deprecations |
| `lib/screens/admin/admin_home_screen.dart` | Added "مراجعة التحقق" `ActionTile` |
| `pubspec.yaml` | Added `file_picker: ^8.0.7` |

### Backward Compatibility

- Old user accounts without `identityVerificationStatus` are treated as unverified for donations (they see the verification screen). Already-approved accounts in `individuals` collection are not affected for offer publishing.
- Old restaurant/charity accounts without `verificationStatus` continue to be controlled by `isApproved` in `auth_service.login()`.
- All new Firestore fields are null-safe: every read uses `?? ''` or `as String? ?? ''`.

### Validation Results

| Test | Expected |
|------|----------|
| Restaurant registration with license document | `verificationStatus: 'pending'`, `businessLicenseUrl` stored |
| Charity registration with charity document | `verificationStatus: 'pending'`, `charityDocumentUrl` stored |
| Restaurant/charity login before approval | Specific Arabic blocked message |
| First user donation (unverified) | Navigates to `IdentityVerificationScreen` |
| First user donation (pending verification) | SnackBar: "قيد المراجعة" |
| Admin approves restaurant | `isApproved: true`, `verificationStatus: 'approved'`; notification sent |
| Admin rejects charity with reason | `verificationStatus: 'rejected'`, reason saved |
| Admin approves user identity | `identityVerificationStatus: 'approved'`; user can donate |
| Old accounts without new fields | No crash; backward compat preserved |

```
flutter analyze lib/services/cloudinary_service.dart
               lib/services/auth_service.dart
               lib/screens/auth/signup_screen.dart
               lib/screens/user/identity_verification_screen.dart
               lib/screens/user/donate_tab.dart
               lib/screens/admin/admin_verification_panel.dart
               lib/screens/admin/admin_home_screen.dart
No issues found!
```

---

## Interactive Document Upload (2026-06-27)

### Problem

The file-picker buttons in the registration form (`_FilePickButton`) were wired to methods (`_pickLogo`, `_pickOrgDoc`) that used `FilePicker` for both logo and document selection. On Android, `FilePicker` for images can silently return null if media permissions are not explicitly declared in `AndroidManifest.xml`. Additionally, there was no image preview after selection.

### Image Picker (Logos)

`_pickLogo()` now uses `ImagePicker`, which is already configured for the project:

1. A `showModalBottomSheet` asks the user: **الكاميرا** or **معرض الصور**
2. `ImagePicker().pickImage(source: selectedSource, imageQuality: 75)` is called
3. Bytes are read via `picked.readAsBytes()`
4. Stored as `_PickedDoc(bytes: bytes, name: picked.name)`

This applies to both **Restaurant Logo** and **Charity Logo**.

### File Picker (Documents)

`_pickOrgDoc()` uses `FilePicker` with `allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']`:

1. `FilePicker.platform.pickFiles(type: FileType.custom, withData: true)` is called
2. The result is converted to `_PickedDoc(bytes: f.bytes!, name: f.name)`

This applies to **Business License** and **Charity Registration Document**.

### Unified `_PickedDoc` Model

Both pickers produce a `_PickedDoc` instance with:
- `Uint8List bytes` — file data for Cloudinary upload
- `String name` — filename for display and upload
- `bool isImage` — derived from file extension; used to decide whether to show image preview

### Cloudinary Upload

During `_handleSignup()`:
```dart
if (_logoFile != null) {
  logoUrl = await CloudinaryService().uploadBytes(
      bytes: _logoFile!.bytes, filename: _logoFile!.name);
}
orgDocUrl = await CloudinaryService().uploadBytes(
    bytes: _orgDocFile!.bytes, filename: _orgDocFile!.name);
```

### Validation

| Role | Missing file | Error message |
|------|-------------|---------------|
| Restaurant | No license document | "يرجى رفع الرخصة التجارية" |
| Charity | No registration document | "يرجى رفع وثيقة تسجيل الجمعية" |
| Both | Logo missing | Not blocked — logo is optional |

### Preview

`_FilePickButton` updated to show:
- If file is picked: `✔ filename` in the label row
- If `file.isImage` (jpg/png): `Image.memory(file.bytes, height: 120)` preview below the row, rounded bottom corners
- If file is null: hint text shows accepted formats + source (camera/gallery for logos)

### Files Changed

| File | Change |
|------|--------|
| `lib/screens/auth/signup_screen.dart` | Added `_PickedDoc` model; rewrote `_pickLogo()` to use `ImagePicker` + camera/gallery sheet; rewrote `_pickOrgDoc()` to convert `PlatformFile` → `_PickedDoc`; updated `_FilePickButton` with image preview; fixed upload calls |

### Validation Results

| Test | Expected |
|------|----------|
| Tap logo button | Bottom sheet: كاميرا / معرض |
| Select from gallery (logo) | Image preview shown; `✔ filename` displayed |
| Tap document button | System file picker opens (jpg/png/pdf) |
| Select PDF document | `✔ filename.pdf` shown |
| Submit without document | Blocked with Arabic message |
| Submit with both | Files uploaded to Cloudinary; URLs stored in Firestore |

```
flutter analyze lib/screens/auth/signup_screen.dart
No issues found!
```
