import os
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = r"D:\DIBL\erpnext_mobile_app\store_assets"
os.makedirs(OUT_DIR, exist_ok=True)

def get_font(size, bold=False):
    for name in [
        "segoeuib.ttf" if bold else "segoeui.ttf",
        "arialbd.ttf" if bold else "arial.ttf",
        "calibrib.ttf" if bold else "calibri.ttf",
    ]:
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            pass
    return ImageFont.load_default()

def draw_gradient(img, top_color, bottom_color):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    for y in range(h):
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * y / h)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * y / h)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * y / h)
        draw.line([(0, y), (w, y)], fill=(r, g, b))

# 1. App Icon (512x512)
icon = Image.new("RGB", (512, 512), (13, 148, 136))
draw_gradient(icon, (15, 23, 42), (13, 148, 136))
d = ImageDraw.Draw(icon)
d.rounded_rectangle([56, 56, 456, 456], radius=90, fill=(255, 255, 255, 25), outline=(45, 212, 191), width=6)
# Draw stylized ERP cube / hex badge
d.rounded_rectangle([116, 116, 396, 396], radius=64, fill=(13, 148, 136))
d.text((256, 215), "Nex", fill=(255, 255, 255), font=get_font(96, True), anchor="mm")
d.text((256, 315), "ERP", fill=(153, 246, 228), font=get_font(76, True), anchor="mm")
icon.save(os.path.join(OUT_DIR, "app_icon_512.png"), "PNG")

# 2. Feature Graphic (1024x500)
fg = Image.new("RGB", (1024, 500), (15, 23, 42))
draw_gradient(fg, (15, 23, 42), (17, 94, 89))
d = ImageDraw.Draw(fg)
# Left text block
d.rounded_rectangle([48, 56, 280, 100], radius=22, fill=(13, 148, 136))
d.text((164, 78), "ERPNEXT NATIVE APP", fill=(255, 255, 255), font=get_font(18, True), anchor="mm")
d.text((48, 135), "NexERP Mobile", fill=(255, 255, 255), font=get_font(58, True))
d.text((48, 210), "Complete Enterprise Suite for ERPNext", fill=(153, 246, 228), font=get_font(28, False))
bullets = [
    "• Geo-Fenced & Selfie HR Attendance",
    "• Leave Approval, Expense Claims & Advances",
    "• Sales Invoices, Orders, CRM & Stock Entry",
    "• Multi-Server Permanent Encrypted Login",
]
y = 275
for b in bullets:
    d.text((54, y), b, fill=(226, 232, 240), font=get_font(22, False))
    y += 40

# Right mockup card on Feature Graphic
d.rounded_rectangle([650, 45, 965, 455], radius=32, fill=(255, 255, 255), outline=(45, 212, 191), width=4)
d.rounded_rectangle([670, 65, 945, 145], radius=18, fill=(15, 23, 42))
d.text((807, 95), "Drip Irrigation BD Ltd", fill=(255, 255, 255), font=get_font(20, True), anchor="mm")
d.text((807, 123), "Connected • Active Session", fill=(45, 212, 191), font=get_font(15, False), anchor="mm")

cards = [
    ("HR & Selfie Check-In", "GPS Verified • Inside Office", (13, 148, 136)),
    ("Expense & Advance", "Balance: BDT 14,500", (37, 99, 235)),
    ("Sales & Billing", "Invoices • Orders • Quotations", (124, 58, 237)),
    ("Projects & Stock", "Material Request • Timesheet", (217, 119, 6)),
]
cy = 165
for title, sub, col in cards:
    d.rounded_rectangle([670, cy, 945, cy + 60], radius=14, fill=(241, 245, 249))
    d.rounded_rectangle([682, cy + 12, 720, cy + 48], radius=10, fill=col)
    d.text((735, cy + 14), title, fill=(15, 23, 42), font=get_font(17, True))
    d.text((735, cy + 36), sub, fill=(100, 116, 139), font=get_font(13, False))
    cy += 70

fg.save(os.path.join(OUT_DIR, "feature_graphic_1024x500.png"), "PNG")

# 3. Phone Screenshots (1080x1920)
screens = [
    (
        "phone_1.png",
        "HR & Selfie Attendance",
        "GPS Geo-Fencing, Front-Camera Selfie & Shift Requests",
        (13, 148, 136),
        [
            ("Branch Geo-Fence Status", "Head Office (Dhaka) • 24m (Inside Fence)", (220, 252, 231), (22, 101, 52)),
            ("Employee Selfie Attached", "Front Camera Verified • 09:02 AM", (224, 242, 254), (3, 105, 161)),
            ("PUNCH IN (CHECK-IN)", "Instant sync with ERPNext Employee Checkin", (13, 148, 136), (255, 255, 255)),
            ("Recent Check-In Logs", "EMP-CHK-2026-00412 • IN • Head Office\nEMP-CHK-2026-00409 • OUT • Field Site", (248, 250, 252), (30, 41, 59)),
        ],
    ),
    (
        "phone_2.png",
        "Leave, Claims & Advances",
        "Receipt Upload, Project Advance Filter & 4-Card Summary",
        (37, 99, 235),
        [
            ("Employee Advance Summary", "Total Taken: BDT 45,000  |  Claimed: BDT 30,500\nReturned: BDT 0          |  Balance: BDT 14,500", (239, 246, 255), (30, 64, 175)),
            ("Expense Claim + Receipt", "Camera & Gallery Receipt Upload Attached", (240, 253, 244), (22, 101, 52)),
            ("Leave Application & Approval", "1-Tap Manager Approval for Open Applications", (254, 243, 199), (146, 64, 14)),
            ("Strict Project-Advance Filter", "Auto-links Paid/Unclaimed Advances by Project", (248, 250, 252), (30, 41, 59)),
        ],
    ),
    (
        "phone_3.png",
        "Sales, Billing & CRM",
        "Invoices, Orders, Quotations, Payments & Mobile Lookup",
        (124, 58, 237),
        [
            ("Sales Summary Bar", "20 Docs  |  Total BDT 4,85,200  |  Unpaid BDT 32,000", (245, 243, 255), (91, 33, 182)),
            ("Customer Lookup by Mobile", "Instant Customer auto-fill via phone number", (224, 242, 254), (3, 105, 161)),
            ("Sales Invoices & Orders", "SINV-26-00192 • Paid • BDT 42,500\nSAL-ORD-2026-00084 • To Deliver and Bill", (248, 250, 252), (30, 41, 59)),
            ("Dual-Engine CRM & Tasks", "Supports Frappe CRM (Deals/Leads) & ERPNext CRM", (240, 253, 244), (22, 101, 52)),
        ],
    ),
    (
        "phone_4.png",
        "Projects, Stock & Payroll",
        "Material Requests, 1-Tap Stock Entry & PDF Salary Slips",
        (217, 119, 6),
        [
            ("Material Request Fulfillment", "MAT-MR-2026-00118 • Approved • 1-Tap Fulfill -> Stock Entry", (254, 243, 199), (146, 64, 14)),
            ("Project & Timesheet Logging", "Log field engineering hours directly to Projects", (239, 246, 255), (30, 64, 175)),
            ("Official PDF Salary Slips", "View Net Pay breakdown & download official PDF", (220, 252, 231), (22, 101, 52)),
            ("Multi-Server Permanent Login", "Connect any ERPNext URL once • Stay logged in", (248, 250, 252), (30, 41, 59)),
        ],
    ),
]

for fname, title, subtitle, accent, items in screens:
    im = Image.new("RGB", (1080, 1920), (15, 23, 42))
    draw_gradient(im, (15, 23, 42), (30, 41, 59))
    d = ImageDraw.Draw(im)
    # Top header
    d.rounded_rectangle([80, 90, 1000, 155], radius=32, fill=accent)
    d.text((540, 122), "NEXERP MOBILE • ERPNEXT SUITE", fill=(255, 255, 255), font=get_font(28, True), anchor="mm")
    d.text((540, 230), title, fill=(255, 255, 255), font=get_font(56, True), anchor="mm")
    d.text((540, 305), subtitle, fill=(148, 163, 184), font=get_font(30, False), anchor="mm")

    # Phone frame
    d.rounded_rectangle([90, 380, 990, 1820], radius=56, fill=(248, 250, 252), outline=accent, width=8)
    # App bar inside phone
    d.rounded_rectangle([98, 388, 982, 520], radius=48, fill=(15, 23, 42))
    d.text((150, 454), title, fill=(255, 255, 255), font=get_font(34, True), anchor="lm")

    cy = 565
    for ctitle, cbody, bg, fg_col in items:
        d.rounded_rectangle([140, cy, 940, cy + 265], radius=28, fill=bg, outline=(203, 213, 225), width=2)
        d.text((180, cy + 45), ctitle, fill=fg_col, font=get_font(34, True))
        lines = cbody.split("\n")
        ly = cy + 115
        for line in lines:
            d.text((180, ly), line, fill=(51, 65, 85) if bg != accent else (255, 255, 255), font=get_font(28, False))
            ly += 45
        cy += 300

    im.save(os.path.join(OUT_DIR, fname), "PNG")

# 4. Tablet Screenshots (1920x1080)
for idx, fname in enumerate(["tablet_1.png", "tablet_2.png"]):
    im = Image.new("RGB", (1920, 1080), (15, 23, 42))
    draw_gradient(im, (15, 23, 42), (17, 94, 89))
    d = ImageDraw.Draw(im)
    d.text((960, 80), "NexERP Mobile — Enterprise ERPNext Dashboard (Tablet & Phone)", fill=(255, 255, 255), font=get_font(46, True), anchor="mm")
    d.rounded_rectangle([120, 150, 1800, 980], radius=40, fill=(248, 250, 252), outline=(45, 212, 191), width=6)
    d.rounded_rectangle([126, 156, 1794, 260], radius=34, fill=(15, 23, 42))
    d.text((180, 208), "NexERP Mobile • Connected to ERPNext Server", fill=(255, 255, 255), font=get_font(32, True), anchor="lm")

    boxes = [
        ("HR & Selfie Attendance", "GPS Geo-Fence + Front Camera Selfie + Shift Request", (13, 148, 136)),
        ("Leave & Expense Claims", "1-Tap Leave Approval + Receipt Upload + Advance Balance", (37, 99, 235)),
        ("Payroll & Salary Slips", "Monthly Net Pay Breakdown + Official ERPNext PDF", (5, 150, 105)),
        ("Sales, Orders & Billing", "Sales Invoice, Order, Quotation, Payment Entry", (124, 58, 237)),
        ("CRM Leads, Deals & Tasks", "Dual-Engine Frappe CRM + ERPNext Lead/Opportunity", (225, 29, 72)),
        ("Projects, Timesheet & Stock", "Material Request Creation & 1-Tap Stock Entry", (217, 119, 6)),
    ]
    for i, (btitle, bsub, col) in enumerate(boxes):
        row = i // 3
        col_idx = i % 3
        x1 = 170 + col_idx * 535
        y1 = 310 + row * 310
        d.rounded_rectangle([x1, y1, x1 + 500, y1 + 270], radius=24, fill=(255, 255, 255), outline=(203, 213, 225), width=3)
        d.rounded_rectangle([x1 + 30, y1 + 30, x1 + 110, y1 + 110], radius=20, fill=col)
        d.text((x1 + 30, y1 + 145), btitle, fill=(15, 23, 42), font=get_font(28, True))
        d.text((x1 + 30, y1 + 195), bsub[:42], fill=(100, 116, 139), font=get_font(20, False))
        if len(bsub) > 42:
            d.text((x1 + 30, y1 + 225), bsub[42:], fill=(100, 116, 139), font=get_font(20, False))

    im.save(os.path.join(OUT_DIR, fname), "PNG")

print("Generated all Play Store visual assets successfully!")
