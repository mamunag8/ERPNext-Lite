# ERPNext-Lite

**NexERP Mobile (`ERPNext-Lite`)** is a native **Flutter (Android & iOS)** mobile application for **ERPNext (v14 / v15 / v16)** and **Frappe CRM (`FCRM`)**, built for **Drip Irrigation BD Ltd (DIBL)** and compatible with any self-hosted or cloud ERPNext instance.

---

## ✨ Key Features

- **🔐 1st-Time Multi-Server Login & Permanent Session:**
  - Connect to any ERPNext Server URL (`https://...`) via Email/Password or API Key/Secret.
  - Encrypted session & credential storage (`flutter_secure_storage`) with automatic silent session renewal until manual logout.
- **📍 HR & Attendance:**
  - **Geo-Fenced Check-In / Check-Out (`Employee Checkin`)** with live GPS & Haversine distance calculation + Field/Site mode.
  - **Front-Camera Selfie Attendance** photo capture and upload.
  - Monthly **`Attendance`** history and **`Shift Request`** management.
- **🧾 Leave, Expense Claims & Employee Advance:**
  - **`Leave Application`** & **`Leave Allocation`** with Manager **Approve / Reject** workflow.
  - **`Expense Claim`** creation with camera/gallery receipt upload (`custom_add_documents`) & Manager approval.
  - **`Employee Advance`** with 4-Card BDT Summary (`Total Advance`, `Claimed`, `Returned`, `Pending`) & requisition document upload.
- **💵 Payroll:**
  - **`Salary Slip`** viewer (Gross Pay, Deductions, Net Pay) + **1-Tap Official PDF Download**.
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
