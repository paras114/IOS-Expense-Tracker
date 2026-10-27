/**
 * Cash Expense Tracker — Google Apps Script backend
 * - iPhone Shortcut and the Cash Book app send expenses here (doPost)
 * - The Cash Book app reads them back (doGet ?format=json)
 * - Also serves the web dashboard (doGet)
 */

// ===== EDIT THESE =====
const SECRET = 'change-me-to-a-long-random-phrase'; // same value goes in the Shortcut, the app and the dashboard link
const CURRENCY = 'USD';                              // e.g. USD, EUR, GBP, INR, PKR, AED
const SHEET_NAME = 'Expenses';
// ======================

const HEADERS = ['Timestamp', 'Amount', 'Category', 'Remarks', 'Address', 'Latitude', 'Longitude', 'Map', 'ID'];
const ID_COL = 9;

function getSheet_() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(SHEET_NAME);
    sh.appendRow(HEADERS);
    sh.setFrozenRows(1);
    sh.getRange(1, 1, 1, HEADERS.length).setFontWeight('bold');
    sh.getRange('A:A').setNumberFormat('yyyy-mm-dd hh:mm');
    sh.getRange('B:B').setNumberFormat('#,##0.00');
  }
  if (sh.getRange(1, ID_COL).getValue() !== 'ID') {
    sh.getRange(1, ID_COL).setValue('ID').setFontWeight('bold');
  }
  return sh;
}

/** Gives every row an ID (older rows added before the app existed won't have one). */
function ensureIds_(sh) {
  const n = sh.getLastRow() - 1;
  if (n < 1) return;
  const range = sh.getRange(2, ID_COL, n, 1);
  const ids = range.getValues();
  let changed = false;
  for (let i = 0; i < ids.length; i++) {
    if (!ids[i][0]) { ids[i][0] = Utilities.getUuid(); changed = true; }
  }
  if (changed) range.setValues(ids);
}

function findRow_(sh, id) {
  if (!id) return -1;
  const n = sh.getLastRow() - 1;
  if (n < 1) return -1;
  const ids = sh.getRange(2, ID_COL, n, 1).getValues();
  for (let i = 0; i < ids.length; i++) {
    if (String(ids[i][0]) === id) return i + 2;
  }
  return -1;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function toNum_(v) {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return isFinite(v) ? v : null;
  let s = String(v).trim().replace(/[^0-9.,\-]/g, '');
  // "1,500" or "1,500.50" → thousands separator; "12,50" → decimal comma
  if (s.includes(',') && (s.includes('.') || /,\d{3}$/.test(s))) s = s.replace(/,/g, '');
  else s = s.replace(',', '.');
  if (s === '') return null;
  const n = Number(s);
  return isFinite(n) ? n : null;
}

/** Called by the Shortcut and the app. action = add (default) | update | delete */
function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(10000);
    const raw = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    // Accept field names regardless of capitals or stray spaces ("Amount ", "AMOUNT" → "amount")
    const d = {};
    Object.keys(raw).forEach(k => d[String(k).trim().toLowerCase()] = raw[k]);
    if (String(d.key || '').trim() !== SECRET) return json_({ ok: false, error: 'Unauthorized' });

    const sh = getSheet_();
    const action = String(d.action || 'add').trim().toLowerCase();
    const id = String(d.id || '').trim();

    if (action === 'delete') {
      const r = findRow_(sh, id);
      if (r > 0) sh.deleteRow(r);
      return json_({ ok: true, deleted: r > 0 });
    }

    const amount = toNum_(d.amount);
    if (amount === null || amount <= 0) {
      return json_({ ok: false, error: 'Invalid amount', received_amount: d.amount === undefined ? '(no amount field)' : d.amount, fields_received: Object.keys(raw) });
    }

    let ts = d.timestamp ? new Date(d.timestamp) : new Date();
    if (isNaN(ts.getTime())) ts = new Date();

    const lat = toNum_(d.lat);
    const lng = toNum_(d.lng);
    let address = String(d.address || '').trim();

    // Turn coordinates into a readable address (built into Apps Script, no API key needed)
    if (!address && lat !== null && lng !== null) {
      try {
        const geo = Maps.newGeocoder().reverseGeocode(lat, lng);
        if (geo.results && geo.results.length) address = geo.results[0].formatted_address;
      } catch (err) { /* keep going without an address */ }
    }

    const mapLink = (lat !== null && lng !== null)
      ? 'https://maps.apple.com/?ll=' + lat + ',' + lng + '&q=Expense'
      : '';

    const rowId = id || Utilities.getUuid();
    const row = [
      ts,
      amount,
      String(d.category || 'Other').trim(),
      String(d.remarks || '').trim(),
      address,
      lat === null ? '' : lat,
      lng === null ? '' : lng,
      mapLink,
      rowId
    ];

    const existing = findRow_(sh, id);
    if (existing > 0) {
      // update, or a repeat of an add that already arrived (app retried after a dropped connection)
      if (action === 'update') sh.getRange(existing, 1, 1, row.length).setValues([row]);
      return json_({ ok: true, id: rowId, updated: action === 'update' });
    }

    sh.appendRow(row);
    return json_({ ok: true, id: rowId, amount: amount, category: row[2] });
  } catch (err) {
    return json_({ ok: false, error: String(err) });
  } finally {
    try { lock.releaseLock(); } catch (e2) {}
  }
}

/** ?format=json&key=… → data for the app. Otherwise → web dashboard. */
function doGet(e) {
  const p = (e && e.parameter) || {};
  if (p.format === 'json') return json_(getData(p.key || ''));
  return HtmlService.createHtmlOutputFromFile('Index')
    .setTitle('Expenses')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1, viewport-fit=cover')
    .addMetaTag('apple-mobile-web-app-capable', 'yes');
}

/** Used by the app and the web dashboard */
function getData(key) {
  if (String(key).trim() !== SECRET) return { ok: false, error: 'Invalid or missing key in the link.' };
  const sh = getSheet_();
  ensureIds_(sh);
  const n = sh.getLastRow() - 1;
  if (n < 1) return { ok: true, currency: CURRENCY, rows: [] };

  const values = sh.getRange(2, 1, n, ID_COL).getValues();
  const rows = values
    .filter(r => r[0] !== '' && r[1] !== '' && !isNaN(new Date(r[0]).getTime()))
    .map(r => ({
      id: String(r[ID_COL - 1]),
      ts: new Date(r[0]).toISOString(),
      amount: Number(r[1]) || 0,
      category: String(r[2] || 'Other'),
      remarks: String(r[3] || ''),
      address: String(r[4] || ''),
      lat: r[5] === '' ? null : Number(r[5]),
      lng: r[6] === '' ? null : Number(r[6])
    }));
  return { ok: true, currency: CURRENCY, rows: rows };
}
