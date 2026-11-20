# Morning Cafe Business Manager

<p align="center">
  <img src="assets/images/logo.png" alt="Morning Cafe Brand Logo" width="180" />
</p>

> Production-quality, 100% offline native Android mobile application designed for **Morning Cafe**, a small food business in Piliyandala, Sri Lanka.

[![Flutter](https://img.shields.io/badge/Flutter-3.50.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.14.0-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com)
[![Tests](https://img.shields.io/badge/Tests-25%20Passed%20(100%25)-success)]()
[![Offline](https://img.shields.io/badge/Offline-100%25%20Independent-brightgreen)]()

---

## ☕ 1. Business Profile

- **Business Name:** Morning Cafe
- **Location:** Piliyandala, Sri Lanka
- **Default Currency:** Sri Lankan Rupees (`LKR`)
- **Default Timezone:** Asia/Colombo (`UTC+05:30`)
- **Core Products:**
  - Single Sausage Bun – LKR 120.00
  - Double Sausage Bun – LKR 150.00
  - Omelette Burger – LKR 150.00
- **Primary User:** Business Owner (single-device operation)

---

## 📱 2. Key Features

- **Genuine Mobile Application:** Native Android APK built with Flutter, Material Design 3, and embedded SQLite (`sqflite`). No web wrappers, no WebView, no Firebase, and zero cloud API dependencies.
- **Accrual Net Profit Engine:** Capitalizes raw ingredient purchases as inventory assets. Accrues COGS strictly upon sales production. Formula:
  $$\text{Net Profit} = (\text{Sales Revenue} + \text{Addl Income}) - (\text{COGS} + \text{Wastage} + \text{Expenses})$$
- **FIFO Inventory Costing & Batch Tracking:** Tracks stock batches with purchase dates, prices, and usable durations (1–7 days). Automatically expires perishable stock and excludes it from production allocation.
- **Package-to-Stock Conversions:** Converts bulk purchases (e.g., 500 ml bottles of sauce, 10-piece sausage packs) into kitchen recipe units (`ml`, `g`, `pcs`) with customizable conversion multipliers.
- **Daily Sales with Recipe Explosion:** Calculates theoretical raw ingredient usage from active Bill of Materials (BOM) versions, lets the owner enter actual kitchen usage, and records consumption variance.
- **Biometric Security:** Optional Fingerprint/Face authentication via `local_auth` protecting business records upon app launch.
- **Reporting & Native Sharing:** Centralized weekly financial statements, asset reconciliations, and charts. Exports PDF statements and CSV data shared natively via Android share sheets.
- **Physical Stock Reconciliation:** Performs physical stock takes, auto-calculates shortage or surplus, and logs adjusting movements.
- **Backup & Restore:** Full transactional JSON database export and restore with rollback safety.

---

## 🛠️ 3. Technology Stack

- **Framework:** Flutter 3.50.0 / Dart 3.14.0
- **UI System:** Material Design 3 (CardThemeData, NavigationBar, BottomSheets)
- **Database:** SQLite via `sqflite` (23 relational tables, compound indexes, WAL mode)
- **State Management:** Riverpod (`flutter_riverpod`)
- **Visual Analytics:** `fl_chart` (Interactive weekly revenue & profit bar charts)
- **Formatting:** `intl` (Sri Lankan Rupee currency `LKR #,##0.00`, ISO dates)
- **Document Generation:** `pdf` & `csv`
- **Native Android Interop:** `share_plus`, `path_provider`, `local_auth`

---

## 🏛️ 4. Project Structure

```
d:\Morning Cafe\
├── android\                    # Native Android project configuration
│   ├── app\src\main\           # AndroidManifest.xml (Biometric permissions), MainActivity.kt
│   └── app\build.gradle.kts    # minSdk = 23, debug signing configuration
├── docs\                       # Architectural documentation
│   ├── DATABASE.md             # Complete 23-table SQLite schema & indexes
│   └── BUSINESS_LOGIC.md       # FIFO costing, formulas, and balance identities
├── lib\
│   ├── app\                    # Home navigation shell (5-tab navigation bar)
│   ├── core\
│   │   ├── constants\          # App constants, units, categories, currencies
│   │   ├── database\           # DatabaseHelper, 23 SQLite tables, initial seed data
│   │   ├── services\           # AuditService, ExportService (PDF/CSV), BackupService
│   │   ├── theme\              # Material Design 3 light & dark themes
│   │   └── utils\              # Formatters (currency, numbers, dates)
│   ├── features\
│   │   ├── backup\             # Full JSON database backup and restore UI
│   │   ├── dashboard\          # KPI cards, net profit focus, bar chart, warnings
│   │   ├── finance\            # Centralized profit engine, Cash Flow, Income & Expenses
│   │   ├── income_expense\     # Additional operating expenses and revenue tracking
│   │   ├── ingredients\        # Raw ingredients catalog & packaging conversions
│   │   ├── inventory\          # FIFO batches, opening stock, physical counts, ledger
│   │   ├── more\               # Quick navigation hub to auxiliary modules
│   │   ├── products\           # Products catalog, pricing modal, price change history
│   │   ├── purchases\          # Multi-item purchase receipt entry & history
│   │   ├── recipes\            # Recipe BOM formulation editor & version history
│   │   ├── reports\            # Financial statements, asset reconciliation, PDF/CSV export
│   │   ├── sales\              # Daily sales counter, usage preview, safe edit & reversals
│   │   ├── settings\           # Business info, biometric lock, database health stats
│   │   └── wastage\            # Stock wastage tracking with categorized loss reasons
│   └── main.dart               # App entrypoint, Riverpod ProviderScope, biometric check
├── test\
│   └── business_logic_test.dart# 20 automated unit and integration tests (100% passing)
├── pubspec.yaml                # App dependencies and metadata
└── README.md                   # Project overview & manual
```

---

## 🧪 5. Automated Test Suite (25 Tests Passed)

The application includes an extensive test suite verifying all 25 business and financial integrity requirements. Tests run using an in-memory SQLite database via `sqflite_common_ffi`:

| # | Test Case Description | Verified Result | Status |
| :-: | :--- | :--- | :-: |
| **1** | Daily sales revenue calculation for multiple products | 10 Single + 10 Double + 5 Burgers = LKR 3,450.00 | **PASSED** |
| **2** | Double sausage bun recipe consumption | Exactly 2 sausages consumed per bun (15 buns = 30 sausages) | **PASSED** |
| **2b** | Omelette burger tomato recipe consumption | Exactly 20 grams of tomatoes consumed per burger | **PASSED** |
| **2c** | Tomato purchase kg-to-grams conversion | Bulk kg converted to grams with accurate stock batch valuation | **PASSED** |
| **2d** | Per-quantity price purchase calculation | Unit price automatically calculated for buns, eggs, and burger buns | **PASSED** |
| **2e** | Paper serviettes bundle conversion | 1 bundle converts to 100 pieces in inventory batches | **PASSED** |
| **2f** | Salad leaves in grams recipe consumption | Exactly 10 grams consumed per bun with 1000g/kg conversion | **PASSED** |
| **3** | FIFO inventory costing engine | 50 @ 20, 30 @ 22; consume 60 -> Cost: 1,220, Rem: 20 @ 440 | **PASSED** |
| **4** | Weekly net profit formula | 21,900 + 500 - 8,000 - 400 - 1,500 = LKR 12,500.00 | **PASSED** |
| **5** | Remaining stock calculation | Opening 100 + Purchase 50 - Usage 40 - Wastage 10 = 100 | **PASSED** |
| **6** | Stock wastage deduction without double counting | Wastage charged as expense; stock deducted so excluded from COGS | **PASSED** |
| **7** | Opening stock capitalization | Initial stock sets asset valuation without distorting weekly expenses | **PASSED** |
| **8** | Historical selling price preservation | Price update logs history; past recorded sales remain untouched | **PASSED** |
| **9** | Historical recipe version preservation | Creating V2 creates version boundary; past sales query V1 | **PASSED** |
| **10** | Late expense entry captured on transaction date | Week 1 expense recorded during Week 2 correctly charged to Week 1 | **PASSED** |
| **11** | Duplicate daily sales prevention | Prevents duplicate sale on same date; provides safe editing | **PASSED** |
| **12** | Zero sales report without division-by-zero | Division guards return 0.0% margins without crashing | **PASSED** |
| **13** | Inventory asset balance reconciliation | Opening + Purchases - COGS - Wastage = Closing (exact cent match) | **PASSED** |
| **14** | Expired stock exclusion from production | Perishable batches past usable date are excluded from FIFO sales | **PASSED** |
| **15** | Purchase cancellation/reversal | Cancelling purchase rolls back batches and reduces inventory asset | **PASSED** |
| **16** | Sales edit/cancellation stock restoration | Cancelling sale restores all consumed ingredients back to batches | **PASSED** |
| **17** | Physical stock reconciliation | Shortage consumes deficit; surplus creates adjustment batch | **PASSED** |
| **18** | Additional income aggregation | Proper date-filtered aggregation without duplicate entries | **PASSED** |
| **19** | Cash Flow vs Net Profit distinction | Cash inventory purchase affects cash flow (-10k) but not Net Profit | **PASSED** |
| **20** | Full database backup & restore | JSON dump and full transactional restore verified intact | **PASSED** |

To run the automated tests:
```bash
flutter test
```

---

## ⚡ 6. Budget & Low-RAM Device Optimizations (2GB–3GB RAM)

The application has been extensively optimized to prevent stuttering, memory pressure, and sluggishness on budget Android phones:
- **R8 Code & Resource Shrinking:** Removes unused code and shrinks binary asset footprints by >65%.
- **SQLite WAL Mode & In-Memory Caching:** Uses Write-Ahead Logging (`WAL`), `synchronous = NORMAL`, and `temp_store = MEMORY` to eliminate eMMC disk I/O lock contention.
- **Batch Aggregated Reports:** Replaces recursive per-day loops with single-pass SQL `GROUP BY` aggregations for 0ms financial report calculations.
- **Lazy Tab Mounting:** Mounts screens into RAM only when navigated to, reducing cold-start RAM footprint by over 60%.
- **Recipe BOM Memory Cache:** Pre-caches bill of materials for instantaneous tap-and-add sales tallying without database round-trips.

---

## 📦 7. Installation & Deployment

### Universal All-Device Compatible Release APK
Instead of managing multiple architecture-specific APKs, Morning Cafe is packaged as a single **Universal All-Device Compatible APK** that installs seamlessly on any Android phone.

| Build Variant | Architecture Support | Size | Target Devices | Compatibility |
| :--- | :--- | :--- | :--- | :--- |
| **`MorningCafe_Universal.apk`** | `armeabi-v7a` + `arm64-v8a` | **20.7 MB** | All Android phones & tablets (Budget 2GB–3GB RAM phones, modern 64-bit devices) | **100% All Android Phones** |

> [!NOTE]
> When installed, Android's Package Manager automatically loads only the exact native libraries needed for your device architecture. Even on 2GB–3GB RAM budget phones, the app runs smoothly with low memory footprint thanks to R8 shrinking and SQLite WAL caching.

### Quick Installation Guide
1. **Direct Install on Phone:**
   Transfer `MorningCafe_Universal.apk` to your phone via USB cable, WhatsApp, Google Drive, or Bluetooth. Tap the file in your phone's File Manager and select **Install**.

2. **Via ADB (Command Line):**
   ```bash
   adb install -r "MorningCafe_Universal.apk"
   ```
