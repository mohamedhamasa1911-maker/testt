#!/usr/bin/env bash
# Accountant user acceptance test — walk through a real day's workflow
# and capture friction points honestly.
set -u
cd /home/z/my-project/testt
rm -rf data
rm -f /tmp/q.log
python3 app.py > /tmp/q.log 2>&1 &
PID=$!
trap "kill $PID 2>/dev/null; agent-browser close 2>/dev/null" EXIT
sleep 1.5

BASE=http://127.0.0.1:8787
OUT=/home/z/my-project/download/accountant_uat
mkdir -p $OUT
rm -f $OUT/*.png

# Admin setup (admin-only tasks done by admin, not accountant)
curl -s -X POST $BASE/api/users -H 'Content-Type: application/json' \
  -d '{"username":"admin","display_name":"مدير النظام","password":"admin12345","role":"admin"}' > /dev/null
COOKIE=/tmp/admin.txt
curl -s -c $COOKIE -X POST $BASE/api/login -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin12345"}' > /dev/null
# Import archive
curl -s -b $COOKIE -X POST $BASE/api/import \
  -F "file=@/home/z/my-project/testt/sample_data/sample_archive.xlsx" \
  -F "authoritative_archive=1" > /dev/null

# Admin creates an accountant user (a.mobarak)
curl -s -b $COOKIE -X POST $BASE/api/users -H 'Content-Type: application/json' \
  -d '{"username":"a.mobarak","display_name":"ا. أحمد مبارك","password":"mobarak123","role":"user"}' > /dev/null
echo "Admin set up the archive + created accountant user a.mobarak"

# Make a real PDF for entry 2001 (so accountant has something to look at)
python3 -c "
import fitz
doc = fitz.open()
page = doc.new_page()
page.insert_text((50,72),'فاتورة رقم INV-2001', fontsize=18)
page.insert_text((50,110),'Trans #: 2001', fontsize=14)
page.insert_text((50,140),'Amount: 18,500.00 EGP', fontsize=14)
page.insert_text((50,170),'Date: 2025-02-03', fontsize=14)
page.insert_text((50,200),'Project: مشروع القاهرة', fontsize=14)
page.insert_text((50,230),'Supplier: شركة الأمل للمقاولات', fontsize=14)
doc.save('/tmp/inv2001.pdf')
doc.close()
"
curl -s -b $COOKIE -X POST "$BASE/api/entries/2001/attachments" \
  -F "files=@/tmp/inv2001.pdf;type=application/pdf" > /dev/null
echo "Admin uploaded real invoice PDF to entry 2001"

# Now accountant logs in
agent-browser open $BASE/ 2>&1 | tail -1
sleep 1
echo ""
echo "=========================================="
echo "ACCOUNTANT UAT — logged in as a.mobarak"
echo "=========================================="
agent-browser find placeholder "مثال: a.mobarak" fill "a.mobarak" 2>&1 | tail -1
agent-browser find placeholder "••••••••" fill "mobarak123" 2>&1 | tail -1
agent-browser find role button click --name "دخول" 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/01_accountant_dashboard.png 2>&1 | tail -1

# Verify accountant identity
agent-browser eval 'JSON.stringify({name: document.getElementById("userName").textContent, role: document.getElementById("userRole").textContent})' 2>&1 | tail -1

echo ""
echo "=== Task 1: Find my entries (filter by accountant name) ==="
agent-browser find role button click --name "القيود" 2>&1 | tail -1
sleep 1.5
# Filter by accountant
agent-browser eval '
  const sel = document.getElementById("fAccountant");
  for (const o of sel.options) if (o.text.includes("أحمد مبارك")) o.selected = true;
  sel.dispatchEvent(new Event("change"));
  document.getElementById("fQ").value = "";
' 2>&1 | tail -1
agent-browser find role button click --name "تطبيق" 2>&1 | tail -1
sleep 1
agent-browser screenshot $OUT/02_my_entries.png 2>&1 | tail -1
# Count rows
agent-browser eval 'document.querySelectorAll("table.data tbody tr").length + " rows shown"' 2>&1 | tail -1

echo ""
echo "=== Task 2: Open entry 2001, verify it shows the invoice ==="
agent-browser eval 'Views.openEntryByTransNo("2001")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/03_entry_detail.png 2>&1 | tail -1
agent-browser eval '
  const att = document.querySelectorAll(".attach").length;
  const notif = document.querySelector(".empty")?.innerText || "";
  JSON.stringify({attachments: att, emptyText: notif.substring(0,80)})
' 2>&1 | tail -1

echo ""
echo "=== Task 3: Run OCR on the invoice ==="
agent-browser eval 'Views.runOcr(1)' 2>&1 | tail -1
sleep 2
agent-browser screenshot $OUT/04_ocr_result.png 2>&1 | tail -1
# Capture OCR result text
agent-browser eval '
  const text = document.getElementById("modalBody").innerText.substring(0, 500);
  text
' 2>&1 | tail -2
agent-browser eval 'App.closeModal()' 2>&1 | tail -1

echo ""
echo "=== Task 4: Run matching — does the system agree the invoice matches the entry? ==="
agent-browser eval 'Views.runMatching("2001")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/05_matching_result.png 2>&1 | tail -1
# Read matching status from the page
agent-browser eval '
  const m = document.querySelector(".card .bd .badge");
  m ? m.textContent : "no match badge found"
' 2>&1 | tail -1

echo ""
echo "=== Task 5: Send to reviewer ==="
agent-browser eval 'Views.workflow("2001","send-to-reviewer")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/06_after_send.png 2>&1 | tail -1
agent-browser eval '
  const badges = Array.from(document.querySelectorAll(".badge")).map(b => b.textContent);
  JSON.stringify(badges)
' 2>&1 | tail -1

echo ""
echo "=== Task 6: Add a note about the invoice ==="
agent-browser eval '
  document.getElementById("noteText").value = "الفاتورة مطابقة للقيد، تم الإرسال للمراجع";
  Views.addNote("2001");
' 2>&1 | tail -1
sleep 1
agent-browser screenshot $OUT/07_note_added.png 2>&1 | tail -1

echo ""
echo "=== Task 7: Try to access admin-only Users page (should be hidden) ==="
agent-browser eval '
  const usersBtn = document.querySelector("button[data-view=users]");
  usersBtn ? "visible" : "hidden"
' 2>&1 | tail -1

echo ""
echo "=== Task 8: Search by trans number from top bar ==="
agent-browser eval '
  document.getElementById("globalSearch").value = "2004";
  App.gotoEntryFromSearch();
' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/08_search_result.png 2>&1 | tail -1
agent-browser eval '
  const num = document.querySelector(".entry-head .num")?.textContent || "not found";
  num
' 2>&1 | tail -1

echo ""
echo "=== Task 9: Export daily report as Excel ==="
agent-browser eval 'App.navigate("reports")' 2>&1 | tail -1
sleep 1
agent-browser screenshot $OUT/09_reports.png 2>&1 | tail -1

echo ""
echo "=== Task 10: Check audit log shows MY activity ==="
agent-browser eval 'App.navigate("audit")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/10_audit.png 2>&1 | tail -1
agent-browser eval '
  const rows = Array.from(document.querySelectorAll("table.data tbody tr")).slice(0,5).map(r => r.cells[1]?.textContent + " | " + r.cells[2]?.textContent);
  JSON.stringify(rows)
' 2>&1 | tail -1

echo ""
echo "=== Task 11: Logout ==="
agent-browser eval 'App.logout()' 2>&1 | tail -1
sleep 1
agent-browser screenshot $OUT/11_logged_out.png 2>&1 | tail -1

echo ""
echo "=== Console errors during the whole session ==="
agent-browser errors 2>&1 | tail -10
echo "=== Console messages ==="
agent-browser console 2>&1 | tail -10

echo ""
echo "=========================================="
echo "ACCOUNTANT UAT COMPLETE"
echo "=========================================="
ls -la $OUT/*.png | awk '{print $NF, $5}'
