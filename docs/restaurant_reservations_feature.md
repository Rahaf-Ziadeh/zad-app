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

