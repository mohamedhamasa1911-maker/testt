#!/usr/bin/env bash
# Test runner: starts the server, runs all tests, kills the server.
set -u
cd /home/z/my-project/testt
rm -rf data
rm -f /tmp/qoyod.log
python3 app.py > /tmp/qoyod.log 2>&1 &
PID=$!
trap "kill $PID 2>/dev/null" EXIT
sleep 1.5

BASE=http://127.0.0.1:8787
COOKIE=/tmp/qoyod_cookie.txt
rm -f "$COOKIE"

ok=0; fail=0
# Check that actual contains expected (substring, no space normalization needed)
check() {
  local name="$1"; local expected="$2"; local actual="$3"
  if echo "$actual" | grep -qF "$expected"; then
    echo "  ✓ $name"
    ok=$((ok+1))
  else
    echo "  ✗ $name"
    echo "    expected to contain: $expected"
    echo "    actual: ${actual:0:300}"
    fail=$((fail+1))
  fi
}
check_nonascii() {
  local name="$1"; local expected="$2"; local actual="$3"
  if echo "$actual" | python3 -c "import sys; sys.exit(0 if '$expected' in sys.stdin.read() else 1)"; then
    echo "  ✓ $name"
    ok=$((ok+1))
  else
    echo "  ✗ $name — expected to contain: $expected"
    echo "    actual: ${actual:0:300}"
    fail=$((fail+1))
  fi
}
# Check that actual does NOT contain expected
check_not() {
  local name="$1"; local expected="$2"; local actual="$3"
  if echo "$actual" | grep -qF "$expected"; then
    echo "  ✗ $name (should NOT contain: $expected)"
    echo "    actual: ${actual:0:300}"
    fail=$((fail+1))
  else
    echo "  ✓ $name"
    ok=$((ok+1))
  fi
}

echo "=== 1. /health ==="
R=$(curl -s $BASE/health)
check "health healthy" '"status": "healthy"' "$R"

echo "=== 2. /api/setup (no users) ==="
R=$(curl -s $BASE/api/setup)
check "has_users=false initially" '"has_users": false' "$R"

echo "=== 3. Create first admin (no auth needed) ==="
R=$(curl -s -X POST $BASE/api/users \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","display_name":"مدير النظام","password":"admin12345","role":"admin"}')
check "admin created" '"username": "admin"' "$R"

echo "=== 4. Try creating another user without auth (should fail) ==="
R=$(curl -s -X POST $BASE/api/users \
  -H 'Content-Type: application/json' \
  -d '{"username":"hacker","display_name":"Hacker","password":"hack12345"}')
check_nonascii "non-auth create blocked" 'فقط المدير' "$R"

echo "=== 5. Login as admin ==="
R=$(curl -s -c $COOKIE -X POST $BASE/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin12345"}')
check "login ok" '"ok": true' "$R"
check "admin role" '"role": "admin"' "$R"

echo "=== 6. /api/me with cookie ==="
R=$(curl -s -b $COOKIE $BASE/api/me)
check "me returns admin" '"username": "admin"' "$R"

echo "=== 7. /api/meta ==="
R=$(curl -s -b $COOKIE $BASE/api/meta)
check "meta has statuses" '"statuses"' "$R"

echo "=== 8. /api/dashboard (empty) ==="
R=$(curl -s -b $COOKIE $BASE/api/dashboard)
check "dashboard ok" '"ok": true' "$R"

echo "=== 9. /api/stats (empty) ==="
R=$(curl -s -b $COOKIE $BASE/api/stats)
check "stats ok" '"ok": true' "$R"
check "stats total=0" '"total": 0' "$R"

echo "=== 10. /api/entries (empty) ==="
R=$(curl -s -b $COOKIE $BASE/api/entries)
check "entries empty array" '"entries": []' "$R"

echo "=== 11. Create sample Excel archive ==="
python3 -c "
import openpyxl
wb = openpyxl.Workbook()
ws = wb.active
ws.append(['Trans #','Type','Date','Num','Name','Memo','Accountant','Debit','Credit','Project'])
data = [
  [1001,'Bill','2025-01-05','INV-1001','شركة الأمل للمقاولات','فاتورة مبيعات','a.mobarak',15000,0,'مشروع القاهرة'],
  [1002,'Bill','2025-01-06','INV-1002','مؤسسة النور','فاتورة مشتريات','m.salah',0,8500,'مشروع الإسكندرية'],
  [1003,'Journal','2025-01-07','J-1003','قيد إقفال','إقفال حسابات','sherif',4200,4200,''],
  [1004,'Bill','2025-01-08','INV-1004','شركة المستقبل','فاتورة خدمات','omar.adel',22000,0,'مشروع الجيزة'],
  [1005,'Bill','2025-01-09','INV-1005','مكتب الهلال','استشارات','eslam',0,7800,''],
]
for r in data: ws.append(r)
wb.save('/tmp/sample_archive.xlsx')
print('sample saved')
"

echo "=== 12. Preview Excel ==="
R=$(curl -s -b $COOKIE -X POST $BASE/api/excel/preview -F "file=@/tmp/sample_archive.xlsx")
check "preview ok" '"ok": true' "$R"
check "preview found Trans #" '"Trans #"' "$R"

echo "=== 13. Import Excel (authoritative) ==="
R=$(curl -s -b $COOKIE -X POST $BASE/api/import \
  -F "file=@/tmp/sample_archive.xlsx" \
  -F "authoritative_archive=1")
check "import ok" '"ok": true' "$R"
check "imported 5 entries" '"imported": 5' "$R"

echo "=== 14. /api/entries (5 entries) ==="
R=$(curl -s -b $COOKIE $BASE/api/entries)
check "has entry 1005" '"trans_no": "1005"' "$R"
check "has entry 1001" '"trans_no": "1001"' "$R"
check "accountant normalized" '"ا. أحمد مبارك"' "$R"

echo "=== 15. /api/stats with data ==="
R=$(curl -s -b $COOKIE $BASE/api/stats)
check "total=5" '"total": 5' "$R"
check "missing=5 (no attachments)" '"missing": 5' "$R"

echo "=== 16. Open entry detail ==="
R=$(curl -s -b $COOKIE $BASE/api/entries/1001)
check "entry 1001 found" '"trans_no": "1001"' "$R"
check "entry has name" '"شركة الأمل للمقاولات"' "$R"

echo "=== 17. Upload attachment (session user is admin — should work) ==="
echo "fake pdf content" > /tmp/fake.pdf
R=$(curl -s -b $COOKIE -X POST "$BASE/api/entries/1001/attachments" \
  -F "files=@/tmp/fake.pdf;type=application/pdf")
check "upload ok" '"ok": true' "$R"
check "count=1" '"count": 1' "$R"

echo "=== 18. Upload attachment to non-existent entry (should fail) ==="
R=$(curl -s -b $COOKIE -X POST "$BASE/api/entries/9999/attachments" \
  -F "files=@/tmp/fake.pdf;type=application/pdf")
check "non-existent entry rejected" 'رقم القيد غير موجود في كشف الأرشيف' "$R"

echo "=== 19. Run OCR on attachment 1 (fallback mode — Tesseract not installed) ==="
R=$(curl -s -b $COOKIE -X POST "$BASE/api/documents/1/extract" \
  -H 'Content-Type: application/json' \
  -d '{"provider":"local","user_name":"مدير النظام"}')
check "ocr returns ok" '"ok": true' "$R"
check "ocr has fields" '"fields"' "$R"
check "ocr fallback used" '"fallback_used": true' "$R"
# Verify no path leak into the project field:
echo "$R" | python3 -c "
import sys, json
r = json.load(sys.stdin)
proj = r.get('result',{}).get('fields',{}).get('project',{}).get('value','')
if '/testt/' in proj or '/home/' in proj:
  print('  ✗ file path leaked into project field: ' + proj); sys.exit(1)
else:
  print('  ✓ no path leak in project field')
" && ok=$((ok+1)) || fail=$((fail+1))

echo "=== 20. Run matching for entry 1001 ==="
R=$(curl -s -b $COOKIE -X POST "$BASE/api/matching/run" \
  -H 'Content-Type: application/json' \
  -d '{"trans_no":"1001","user_name":"مدير النظام"}')
check "matching ok" '"ok": true' "$R"
check "matching has reasons" '"reasons"' "$R"

echo "=== 21. Workflow: send 1001 to reviewer ==="
R=$(curl -s -b $COOKIE -X POST "$BASE/api/entries/1001/send-to-reviewer" \
  -H 'Content-Type: application/json' \
  -d '{"user_name":"مدير النظام"}')
check "workflow ok" '"ok": true' "$R"
check "status at reviewer" '"عند المراجع"' "$R"

echo "=== 22. Add note ==="
R=$(curl -s -b $COOKIE -X POST "$BASE/api/entries/1001/notes" \
  -H 'Content-Type: application/json' \
  -d '{"note":"تم استلام الورق اليوم","author":"مدير النظام"}')
check "note added" '"ok": true' "$R"

echo "=== 23. Paper status update ==="
R=$(curl -s -b $COOKIE -X POST "$BASE/api/entries/1002/paper-status" \
  -H 'Content-Type: application/json' \
  -d '{"present":true,"user_name":"مدير النظام"}')
check "paper status updated" '"ok": true' "$R"
check "paper_received true" '"paper_received": true' "$R"

echo "=== 24. Audit log ==="
R=$(curl -s -b $COOKIE $BASE/api/audit)
check "audit ok" '"ok": true' "$R"
check "audit has logs" '"logs"' "$R"

echo "=== 25. Reports: daily JSON ==="
R=$(curl -s -b $COOKIE "$BASE/api/reports/daily?format=json")
check "daily report ok" '"ok": true' "$R"

echo "=== 26. Reports: paper-received CSV (has data) ==="
R=$(curl -s -b $COOKIE "$BASE/api/reports/paper-received?format=csv")
echo "$R" | python3 -c "import sys; r=sys.stdin.read(); sys.exit(0 if 'trans_no' in r else 1)" && { echo '  ✓ csv has header'; ok=$((ok+1)); } || { echo '  ✗ csv missing header'; fail=$((fail+1)); }
echo "$R" | python3 -c "import sys; r=sys.stdin.read(); sys.exit(0 if '1001' in r else 1)" && { echo '  ✓ csv has entry 1001'; ok=$((ok+1)); } || { echo '  ✗ csv missing 1001'; fail=$((fail+1)); }

echo "=== 27. Reports: attachments-missing Excel ==="
HTTP_CODE=$(curl -s -o /tmp/r.xlsx -w "%{http_code}" -b $COOKIE "$BASE/api/reports/attachments-missing?format=xlsx")
check "xlsx http 200" '200' "$HTTP_CODE"
SIZE=$(stat -c%s /tmp/r.xlsx 2>/dev/null || echo 0)
if [ "$SIZE" -gt 1000 ]; then echo "  ✓ xlsx size=$SIZE"; ok=$((ok+1)); else echo "  ✗ xlsx too small: $SIZE"; fail=$((fail+1)); fi

echo "=== 28. Cover sheet (QR) ==="
HTTP_CODE=$(curl -s -o /tmp/cov.html -w "%{http_code}" -b $COOKIE "$BASE/api/entries/1001/cover-sheet")
check "cover sheet 200" '200' "$HTTP_CODE"
HTML=$(head -c 50 /tmp/cov.html 2>/dev/null || echo "")
check "cover sheet has html" '<!doctype html>' "$HTML"
check "cover sheet has QR" 'base64' "$(cat /tmp/cov.html 2>/dev/null | head -c 5000)"

echo "=== 29. Settings page ==="
R=$(curl -s -b $COOKIE $BASE/api/settings)
check "settings ok" '"ok": true' "$R"
check "settings lists local provider" '"local"' "$R"

echo "=== 30. Users list (admin only) ==="
R=$(curl -s -b $COOKIE $BASE/api/users)
check "users list ok" '"ok": true' "$R"
check "users list has admin" '"admin"' "$R"

echo "=== 31. Search by name ==="
R=$(curl -s -b $COOKIE -G "$BASE/api/entries" --data-urlencode "q=الأمل")
check "search returns 1001" '"trans_no": "1001"' "$R"

echo "=== 32. Filter by status ==="
R=$(curl -s -b $COOKIE -G "$BASE/api/entries" --data-urlencode "status=عند المراجع")
check "filter returns 1001" '"trans_no": "1001"' "$R"
echo "$R" | grep -q '"trans_no": "1002"' && { echo "  ✗ 1002 should not appear"; fail=$((fail+1)); } || { echo "  ✓ 1002 correctly excluded"; ok=$((ok+1)); }

echo "=== 33. Logout ==="
R=$(curl -s -b $COOKIE -c $COOKIE -X POST $BASE/api/logout)
check "logout ok" '"ok": true' "$R"

echo "=== 34. After logout: /api/me returns no user ==="
R=$(curl -s -b $COOKIE $BASE/api/me)
check "no user after logout" '"user": null' "$R"

echo "=== 35. After logout: /api/users is 403 ==="
HTTP_CODE=$(curl -s -o /tmp/r.json -w "%{http_code}" -b $COOKIE $BASE/api/users)
if [ "$HTTP_CODE" = "403" ]; then echo "  ✓ users protected after logout"; ok=$((ok+1)); else echo "  ✗ expected 403, got $HTTP_CODE"; fail=$((fail+1)); fi

echo ""
echo "==================="
echo "PASS=$ok FAIL=$fail"
echo "==================="
[ $fail -eq 0 ]
