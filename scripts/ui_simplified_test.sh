#!/usr/bin/env bash
# UI smoke test after simplification
set -u
cd /home/z/my-project/testt
rm -rf data
rm -f /tmp/q.log
python3 app.py > /tmp/q.log 2>&1 &
PID=$!
trap "kill $PID 2>/dev/null; agent-browser close 2>/dev/null" EXIT
sleep 1.5
BASE=http://127.0.0.1:8787

# Setup via API
curl -s -X POST $BASE/api/users -H 'Content-Type: application/json' \
  -d '{"username":"admin","display_name":"مدير","password":"admin12345","role":"admin"}' > /dev/null
COOKIE=/tmp/c.txt
curl -s -c $COOKIE -X POST $BASE/api/login -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin12345"}' > /dev/null
curl -s -b $COOKIE -X POST $BASE/api/import \
  -F "file=@/home/z/my-project/testt/sample_data/sample_archive.xlsx" \
  -F "authoritative_archive=1" > /dev/null
# Archive one entry to test workflow
curl -s -b $COOKIE -X POST "$BASE/api/entries/2001/archive" \
  -H 'Content-Type: application/json' -d '{}' > /dev/null

OUT=/home/z/my-project/download
mkdir -p $OUT
rm -f $OUT/simplified_*.png

agent-browser open $BASE/ 2>&1 | tail -1
sleep 1
agent-browser find placeholder "مثال: a.mobarak" fill "admin" 2>&1 | tail -1
agent-browser find placeholder "••••••••" fill "admin12345" 2>&1 | tail -1
agent-browser find role button click --name "دخول" 2>&1 | tail -1
sleep 1.5

echo "=== 1. Dashboard (simplified — 4 KPIs, no risk/ready) ==="
agent-browser screenshot $OUT/simplified_01_dashboard.png 2>&1 | tail -1

echo "=== 2. Entries ==="
agent-browser find role button click --name "القيود" 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/simplified_02_entries.png 2>&1 | tail -1

echo "=== 3. Entry 2001 (archived — should show unarchive button) ==="
agent-browser eval 'Views.openEntryByTransNo("2001")' 2>&1 | tail -1
sleep 1.5
agent-browser screenshot $OUT/simplified_03_entry_archived.png 2>&1 | tail -1
# Verify unarchive button shows
agent-browser eval '
  const hasArchive = document.body.innerHTML.includes("أرشفة القيد");
  const hasUnarchive = document.body.innerHTML.includes("إلغاء الأرشفة");
  JSON.stringify({hasArchiveBtn: hasArchive, hasUnarchiveBtn: hasUnarchive, hasOcrBtn: document.body.innerHTML.includes("تشغيل OCR"), hasMatchingBtn: document.body.innerHTML.includes("تشغيل المراجعة")})
' 2>&1 | tail -1

echo "=== 4. Entry 2002 (not archived — should show archive button) ==="
agent-browser eval 'Views.openEntryByTransNo("2002")' 2>&1 | tail -1
sleep 1
agent-browser screenshot $OUT/simplified_04_entry_pending.png 2>&1 | tail -1

echo "=== 5. Reports (should NOT have risk/reviewer-ready; SHOULD have archived) ==="
agent-browser find role button click --name "التقارير" 2>&1 | tail -1
sleep 1
agent-browser screenshot $OUT/simplified_05_reports.png 2>&1 | tail -1
agent-browser eval '
  const html = document.getElementById("view").innerText;
  JSON.stringify({
    hasRisk: html.includes("تقرير المخاطر"),
    hasReviewerReady: html.includes("الجاهزة للمراجع"),
    hasArchived: html.includes("المؤرشفة"),
    hasActivity: html.includes("سجل النشاط")
  })
' 2>&1 | tail -1

echo "=== 6. Settings (should NOT have OCR providers section) ==="
agent-browser find role button click --name "الإعدادات" 2>&1 | tail -1
sleep 1
agent-browser screenshot $OUT/simplified_06_settings.png 2>&1 | tail -1
agent-browser eval '
  const html = document.getElementById("view").innerText;
  JSON.stringify({
    hasOcrProviders: html.includes("مزودات OCR"),
    hasArchiveInfo: html.includes("معلومات الأرشفة"),
    hasLocalPrivacy: html.includes("محلي 100%")
  })
' 2>&1 | tail -1

echo "=== 7. Nav (should NOT have matching) ==="
agent-browser eval '
  const nav = document.getElementById("nav").innerText;
  JSON.stringify({
    hasMatching: nav.includes("المراجعة والمطابقة"),
    hasDocuments: nav.includes("المستندات"),
    hasReports: nav.includes("التقارير"),
    hasAudit: nav.includes("سجل النشاط"),
    hasDashboardArchive: nav.includes("لوحة الأرشيف")
  })
' 2>&1 | tail -1

echo ""
echo "=== Console errors ==="
agent-browser errors 2>&1 | tail -5
echo "=== Console messages ==="
agent-browser console 2>&1 | tail -10

echo ""
echo "=== Screenshots ==="
ls -la $OUT/simplified_*.png | awk '{print $NF, $5}'