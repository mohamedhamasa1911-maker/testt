#!/usr/bin/env bash
# Final UI verification with polish + interactive flows.
set -u
cd /home/z/my-project/testt
rm -rf data
rm -f /tmp/q.log
python3 app.py > /tmp/q.log 2>&1 &
PID=$!
trap "kill $PID 2>/dev/null; agent-browser close 2>/dev/null" EXIT
sleep 1.5

BASE=http://127.0.0.1:8787
OUT=/home/z/my-project/download
mkdir -p $OUT
rm -f $OUT/ui_*.png

click_btn() { agent-browser find role button click --name "$1" 2>&1 | tail -1; }

# 1. Setup admin via API
curl -s -X POST $BASE/api/users -H 'Content-Type: application/json' \
  -d '{"username":"admin","display_name":"مدير","password":"admin12345","role":"admin"}' > /dev/null
COOKIE=/tmp/c.txt; rm -f $COOKIE
curl -s -c $COOKIE -X POST $BASE/api/login -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin12345"}' > /dev/null
curl -s -b $COOKIE -X POST $BASE/api/import \
  -F "file=@/home/z/my-project/testt/sample_data/sample_archive.xlsx" \
  -F "authoritative_archive=1" > /dev/null

# Upload a real PDF attachment to entry 2001
python3 -c "
import fitz
doc = fitz.open()
page = doc.new_page()
page.insert_text((50,72),'Trans 2001', fontsize=24)
page.insert_text((50,120),'Amount: 18500 EGP', fontsize=14)
page.insert_text((50,150),'Date: 2025-02-03', fontsize=14)
page.insert_text((50,180),'Project: مشروع القاهرة', fontsize=14)
doc.save('/tmp/real.pdf')
doc.close()
print('pdf created')
"
curl -s -b $COOKIE -X POST "$BASE/api/entries/2001/attachments" \
  -F "files=@/tmp/real.pdf;type=application/pdf" > /dev/null
echo "Attachment uploaded"

# 2. Open UI and login
agent-browser open $BASE/ 2>&1 | tail -1
sleep 1
agent-browser find placeholder "مثال: a.mobarak" fill "admin" 2>&1 | tail -1
agent-browser find placeholder "••••••••" fill "admin12345" 2>&1 | tail -1
click_btn "دخول"
sleep 1.5

# 3. Dashboard
agent-browser screenshot $OUT/ui_04_dashboard_full.png 2>&1 | tail -1

# 4. Entries table (with polish)
click_btn "القيود"
sleep 1.5
agent-browser screenshot $OUT/ui_05_entries.png 2>&1 | tail -1

# 5. Open entry 2001 (now has 1 attachment)
agent-browser eval 'Views.openEntryByTransNo("2001")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/ui_06_entry_detail.png 2>&1 | tail -1

# 6. Run OCR on attachment 1
agent-browser eval 'Views.runOcr(1)' 2>&1 | tail -1
sleep 2
agent-browser screenshot $OUT/ui_06b_ocr_modal.png 2>&1 | tail -1
# Close modal via JS (button click is intercepted by backdrop in headless mode)
agent-browser eval 'App.closeModal()' 2>&1 | tail -1
sleep 1

# 7. Workflow: send to reviewer
agent-browser eval 'Views.workflow("2001","send-to-reviewer")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/ui_07_after_workflow.png 2>&1 | tail -1

# 8. Audit log (should have many entries now)
agent-browser eval 'App.navigate("audit")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/ui_10_audit.png 2>&1 | tail -1

# 9. Reports view
agent-browser eval 'App.navigate("reports")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/ui_09_reports.png 2>&1 | tail -1

# 10. Settings
agent-browser eval 'App.navigate("settings")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/ui_11_settings.png 2>&1 | tail -1

echo ""
echo "=== Console errors ==="
agent-browser errors 2>&1 | tail -5
echo "=== Console messages ==="
agent-browser console 2>&1 | tail -10

echo ""
echo "=== Files ==="
ls -la $OUT/ui_*.png | awk '{print $NF, $5}'
