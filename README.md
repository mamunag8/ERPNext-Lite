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
- **🤝 Dual CRM Engine (`FCRM` + Standard ERPNext `CRM`):**
  - Auto-detects **Frappe CRM (`CRM Lead`, `CRM Deal`, `CRM Task`)** or standard ERPNext **`Lead`**, **`Opportunity`**, and **`ToDo`** with 1-tap Call, WhatsApp, and Email actions.
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
