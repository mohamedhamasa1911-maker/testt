"""Generate sample data files the user can upload immediately to try the system:
- /home/z/my-project/testt/sample_data/sample_archive.xlsx  — 12 قيود كشف أرشيف
- /home/z/my-project/testt/sample_data/sample_paper.xlsx     — 7 قيود موجودة ورقيًا
"""
from pathlib import Path
import openpyxl

OUT = Path(__file__).resolve().parent.parent / "sample_data"
OUT.mkdir(exist_ok=True)


def build_archive():
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Archive"
    ws.append([
        "Trans #", "Type", "Date", "Num", "Name", "Memo",
        "Accountant", "Debit", "Credit", "Project",
    ])
    rows = [
        [2001, "Bill", "2025-02-03", "INV-2001", "شركة الأمل للمقاولات",   "فاتورة مبيعات",       "a.mobarak", 18500,  0,    "مشروع القاهرة"],
        [2002, "Bill", "2025-02-04", "INV-2002", "مؤسسة النور للتجارة",    "فاتورة مشتريات",      "m.salah",      0, 9200, "مشروع الإسكندرية"],
        [2003, "Journal", "2025-02-05", "J-2003", "قيد إقفال مصروفات",     "إقفال حسابات",        "sherif",     3200, 3200, ""],
        [2004, "Bill", "2025-02-06", "INV-2004", "شركة المستقبل",          "فاتورة خدمات استشارية","omar.adel", 24500,  0,   "مشروع الجيزة"],
        [2005, "Bill", "2025-02-07", "INV-2005", "مكتب الهلال للاستشارات", "استشارات إدارية",     "eslam",        0, 7800, ""],
        [2006, "Bill", "2025-02-08", "INV-2006", "شركة البناء الحديث",     "توريد مواد بناء",     "mohsen",    56000,  0,   "مشروع القاهرة"],
        [2007, "Bill", "2025-02-09", "INV-2007", "مؤسسة الرياض",           "صيانة دورية",         "ali",          0, 4300, ""],
        [2008, "Bill", "2025-02-10", "INV-2008", "شركة الدلتا",            "توريد أجهزة",         "b.elabd",   32500,  0,   "مشروع الدلتا"],
        [2009, "Journal", "2025-02-11", "J-2009", "قيد تسوية بنكي",        "تسوية حساب البنك",    "i.akram",    1500, 1500, ""],
        [2010, "Bill", "2025-02-12", "INV-2010", "شركة النيل للمقاولات",   "أعمال ترميم",         "m.ashraf",  18700,  0,   "مشروع الصعيد"],
        [2011, "Bill", "2025-02-13", "INV-2011", "مكتب السلام",            "خدمات طباعة",         "m.yahya",      0, 2200, ""],
        [2012, "Bill", "2025-02-14", "INV-2012", "شركة الوادي",            "توريد أثاث",          "tolba",     14200,  0,   "مشروع الوادي"],
    ]
    for row in rows:
        ws.append(row)
    # Add a totals row to test the parser's filter (account empty + debit>0 + credit>0)
    ws.append(["", "", "", "", "الإجمالي", "", "", "=SUM(H2:H13)", "=SUM(I2:I13)", ""])
    path = OUT / "sample_archive.xlsx"
    wb.save(path)
    print(f"saved {path} ({len(rows)} entries)")


def build_paper():
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Paper"
    ws.append(["Trans #"])
    # Mark 7 entries as paper-received
    for trans_no in [2001, 2002, 2004, 2006, 2008, 2010, 2012]:
        ws.append([trans_no])
    path = OUT / "sample_paper.xlsx"
    wb.save(path)
    print(f"saved {path} (7 paper-received)")


if __name__ == "__main__":
    build_archive()
    build_paper()
