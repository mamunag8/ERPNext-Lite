# ERPNext-Lite

**NexERP Mobile (`ERPNext-Lite`)** is a native **Flutter (Android & iOS)** mobile application for **ERPNext (v14 / v15 / v16)** and **Frappe CRM (`FCRM`)**, built for **Drip Irrigation BD Ltd (DIBL)** and compatible with any self-hosted or cloud ERPNext instance.

---

## ✨ Key Features

- **🔐 1st-Time Multi-Server Login & Permanent Session:**
  - Connect to any ERPNext Server URL (`https://...`) via Email/Password or API Key/Secret.
  - Encrypted session & credential storage (`flutter_secure_storage`) with automatic silent session renewal until manual logout.
- **📍 Complete ERPNext HR Operations (All 9 Modules):**
  1. **Employee Attendance Tool:** Bulk & 1-tap individual daily attendance marking (`Present`, `Absent`, `On Leave`, `Half Day`, `Work From Home`) filtered by Date & Department/Branch, plus Geo-Fenced GPS & Front-Camera Selfie Check-In/Out (`Employee Checkin`).
  2. **Monthly Attendance Sheet:** Filterable by Month, Year & Employee with KPI summary badges (`Present`, `Absent`, `On Leave`, `HD/WFH`) and a visual **Day 1–31 Attendance Matrix Grid** per employee.
  3. **Leave Application Management:** View & create **`Leave Allocation`** and **`Leave Application`** records with 1-tap Manager **Approve / Reject** workflow.
  4. **Employee Advance Management:** **`Employee Advance`** with 4-Card BDT Summary (`Total Advance`, `Claimed`, `Returned`, `Pending`), requisition upload (`custom_requisitionapplication`), and 1-tap Expense Claim linking.
  5. **Expense Claim Management:** **`Expense Claim`** creation with camera/gallery receipt upload (`custom_add_documents`), strict project-advance validation, PDF download, and Manager approval.
  6. **Payroll Entry:** Create & manage monthly/departmental **`Payroll Entry`** runs with 1-tap bulk **Create Salary Slips** & PDF download.
  7. **Salary Structure Assignment:** View **`Salary Structure`** templates and create/submit **`Salary Structure Assignment`** records (`base` & `variable` pay) per employee.
  8. **Salary Slip Generation:** Generate individual or bulk **`Salary Slip`** documents, inspect itemized Earnings & Deductions, submit draft slips, and **1-Tap Official PDF Download**.
  9. **Additional Salary Slip Generation:** Create **`Additional Salary`** records (Performance Bonus, Project Overtime, Festival Bonus, Allowances, Deductions) and immediately generate the corresponding **`Salary Slip`**.
- **💰 Sales, Billing & Accounting:**
  - **`Sales Invoice`**, **`Sales Order`**, **`Quotation`**, **`Payment Entry`**, and **`Journal Entry` (`JV`)** creation & PDF download.
  - **Smart Mobile Number Customer Lookup** (`Contact` -> `Customer` auto-fill).
- **✅ Quick ToDo Dock & Activity Tracker (`ToDo` DocType on Main Menu):**
  - Dedicated **Quick ToDo & Activity** tab right on the bottom navigation bar + **Inline Quick-Add ToDo Bar** on the Home Dashboard.
  - 1-Tap task creation with Priority chips (`High`, `Medium`, `Low`) and Due Date selector, synced across **`ToDo`** and **`CRM Task`**.
  - 1-Tap task completion & **Log Activity** modal with 1-tap preset templates (`✅ Task completed & verified`, `📞 Called client`, `💬 Sent details on WhatsApp`, `📍 Site visit done`) + unified **Activity Timeline (`Comment` & `CRM Note`)**.
- **🤝 Frappe CRM (`FCRM`) Guided Maintenance UX:**
  - Horizontal **Pipeline Stage Filter Bars** for Leads (`New` → `Contacted` → `Nurture` → `Qualified` → `Converted`) and Deals (`Qualification` → `Demo/Making` → `Proposal/Quotation` → `Negotiation` → `Ready to Close` → `Won` / `Lost`).
  - **1-Tap Guided Maintenance Steps** on every Lead & Deal card: `1. Call / WhatsApp`, `2. Advance Stage`, `3. + Log Note` (with 1-tap call/visit outcome presets), `4. + Follow-up ToDo`, and `5. Convert Lead → Deal`.
  - **360° Lead/Deal Maintenance Sheet** showing interactive pipeline stepper, linked follow-up tasks, activity/notes history, and 1-tap conversion.
- **🏗️ Projects, Timesheets & Stock:**
  - **`Project`** & **`Task`** tracking, progress slider updates, and **`Timesheet`** hour logging.
  - **`Material Request`** creation & **1-Tap Fulfillment into `Stock Entry`**.
  - **`Delivery Note`** creation & PDF download + live **Warehouse Stock Balance (`Bin`)** and **`Item Price`** list.
- **🛒 Buying, Procurement & Company Assets:**
  - **`Purchase Order`**, **`Purchase Receipt`**, **`Purchase Invoice`**, and **`Supplier`** management.
  - **`Asset`** register and **`Asset Movement`** (`Issue`, `Transfer`, `Receipt`).
- **🗂️ Universal DocType Explorer:**
  - Browse, search, inspect all fields, download PDFs, and dynamically create records for **any** ERPNext DocType.

---

## 🚀 Getting Started

```bash
flutter pub get
flutter run
```

### Build Release Artifacts

```bash
# Android Play Store App Bundle (.aab)
flutter build appbundle --release

# Android APK (.apk)
flutter build apk --release
```
