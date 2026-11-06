import PDFDocument from 'pdfkit';

type PdfDoc = InstanceType<typeof PDFDocument>;

export interface ReceiptPdfResult {
  buffer: Buffer;
  filename: string;
}

/** Visual tone for status badges. */
export type ReceiptStatusTone = 'success' | 'warning' | 'error' | 'neutral';

export interface ReceiptDetailRow {
  label: string;
  value: string;
  /** Use monospace font for IDs and hashes. */
  monospace?: boolean;
}

export interface ReceiptLineItem {
  date: string;
  description: string;
  amount: string;
}

export interface ReceiptSection {
  title: string;
  rows?: ReceiptDetailRow[];
  lineItems?: ReceiptLineItem[];
}

export interface ReceiptAmount {
  value: string;
  currency?: string;
  direction?: 'in' | 'out' | 'neutral';
}

/**
 * Structured receipt document — used for wallet, donations, transfers, and summaries.
 */
export interface ReceiptDocument {
  title: string;
  subtitle?: string;
  receiptId: string;
  issuedAt: Date;
  status?: string;
  statusTone?: ReceiptStatusTone;
  amount?: ReceiptAmount;
  parties?: { label: string; name: string }[];
  details?: ReceiptDetailRow[];
  sections?: ReceiptSection[];
  footerNote?: string;
}

const COLORS = {
  primary: '#7B2CBF',
  primaryDark: '#5A1F8F',
  pageBg: '#F4F2F8',
  card: '#FFFFFF',
  text: '#1A1A2E',
  muted: '#6B7280',
  border: '#E5E7EB',
  success: '#059669',
  successBg: '#D1FAE5',
  successText: '#065F46',
  warning: '#D97706',
  warningBg: '#FEF3C7',
  warningText: '#92400E',
  error: '#DC2626',
  errorBg: '#FEE2E2',
  errorText: '#991B1B',
  neutralBg: '#F3F4F6',
  neutralText: '#374151',
  incoming: '#059669',
  outgoing: '#DC2626',
};

const MONTHS = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export async function renderReceiptDocument(
  spec: ReceiptDocument,
  filename: string,
): Promise<ReceiptPdfResult> {
  const doc = new PDFDocument({
    size: 'A4',
    margin: 0,
    bufferPages: true,
  });
  const chunks: Buffer[] = [];
  doc.on('data', (chunk: Buffer) => chunks.push(chunk));

  drawReceiptPage(doc, spec);

  doc.end();
  const buffer = await new Promise<Buffer>((resolve) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
  });
  return { buffer, filename };
}

/** @deprecated Prefer renderReceiptDocument — kept for gradual migration. */
export async function renderPdf(
  build: (doc: PdfDoc) => void,
  filename: string,
): Promise<ReceiptPdfResult> {
  const doc = new PDFDocument({ margin: 50, size: 'A4' });
  const chunks: Buffer[] = [];
  doc.on('data', (chunk: Buffer) => chunks.push(chunk));
  drawLegacyBrandHeader(doc);
  build(doc);
  drawLegacyFooter(doc);
  doc.end();
  const buffer = await new Promise<Buffer>((resolve) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
  });
  return { buffer, filename };
}

export function drawKeyValue(doc: PdfDoc, label: string, value: string) {
  drawDetailRows(doc, [{ label, value }], 50, doc.page.width - 100, doc.y);
}

export function drawSectionTitle(doc: PdfDoc, title: string) {
  doc.moveDown(0.5);
  doc.fontSize(11).fillColor(COLORS.primary).text(title.toUpperCase(), 50);
  doc.moveDown(0.4);
}

export function formatDate(d: Date): string {
  const day = d.getUTCDate();
  const mon = MONTHS[d.getUTCMonth()] ?? '???';
  const year = d.getUTCFullYear();
  const hh = String(d.getUTCHours()).padStart(2, '0');
  const mm = String(d.getUTCMinutes()).padStart(2, '0');
  return `${day} ${mon} ${year}, ${hh}:${mm} UTC`;
}

export function formatShortDate(d: Date): string {
  const day = d.getUTCDate();
  const mon = MONTHS[d.getUTCMonth()] ?? '???';
  return `${day} ${mon} ${d.getUTCFullYear()}`;
}

// ---------------------------------------------------------------------------
// Layout engine
// ---------------------------------------------------------------------------

function drawReceiptPage(doc: PdfDoc, spec: ReceiptDocument) {
  const pageW = doc.page.width;
  const marginX = 44;
  const contentW = pageW - marginX * 2;

  // Page background
  doc.save();
  doc.rect(0, 0, pageW, doc.page.height).fill(COLORS.pageBg);
  doc.restore();

  // Header band
  const headerH = 108;
  doc.save();
  doc.rect(0, 0, pageW, headerH).fill(COLORS.primary);
  doc.rect(0, headerH - 4, pageW, 4).fill(COLORS.primaryDark);
  doc.restore();

  doc.fillColor('#FFFFFF');
  doc.font('Helvetica-Bold').fontSize(26).text('BYBATA', marginX, 28, {
    characterSpacing: 1.5,
  });
  doc.font('Helvetica').fontSize(10).fillColor('#E9D5FF');
  doc.text('Trade · Gift · Donate · Grow Together', marginX, 60);

  // Receipt meta (top-right in header)
  const metaX = pageW - marginX - 200;
  doc.font('Helvetica').fontSize(9).fillColor('#DDD6FE');
  doc.text('RECEIPT', metaX, 32, { width: 200, align: 'right' });
  doc.font('Helvetica').fontSize(8).fillColor('#C4B5FD');
  doc.text(truncateId(spec.receiptId), metaX, 46, { width: 200, align: 'right' });
  doc.text(formatDate(spec.issuedAt), metaX, 58, { width: 200, align: 'right' });

  let cursorY = headerH + 28;

  // Main card
  const cardPad = 24;
  let cardInnerH = estimateCardHeight(spec);

  doc.save();
  doc.fillColor('#000000').opacity(0.06);
  doc.roundedRect(marginX + 2, cursorY + 4, contentW, cardInnerH, 14).fill();
  doc.restore();

  doc.roundedRect(marginX, cursorY, contentW, cardInnerH, 14).fill(COLORS.card);
  doc.roundedRect(marginX, cursorY, contentW, cardInnerH, 14).lineWidth(1).stroke(COLORS.border);

  let innerY = cursorY + cardPad;

  // Title block
  doc.font('Helvetica-Bold').fontSize(20).fillColor(COLORS.text);
  doc.text(spec.title, marginX + cardPad, innerY, { width: contentW - cardPad * 2 });
  innerY += 28;

  if (spec.subtitle) {
    doc.font('Helvetica').fontSize(11).fillColor(COLORS.muted);
    doc.text(spec.subtitle, marginX + cardPad, innerY, { width: contentW - cardPad * 2 });
    innerY += 22;
  }

  // Status badge
  if (spec.status) {
    const tone = spec.statusTone ?? statusToneFromString(spec.status);
    innerY = drawStatusBadge(
      doc,
      marginX + cardPad,
      innerY,
      spec.status,
      tone,
    );
    innerY += 14;
  }

  // Amount hero
  if (spec.amount) {
    innerY = drawAmountHero(
      doc,
      marginX + cardPad,
      innerY,
      contentW - cardPad * 2,
      spec.amount,
    );
    innerY += 16;
  }

  // Parties (from / to)
  if (spec.parties?.length) {
    innerY = drawPartiesBlock(
      doc,
      marginX + cardPad,
      innerY,
      contentW - cardPad * 2,
      spec.parties,
    );
    innerY += 12;
  }

  // Primary details
  if (spec.details?.length) {
    innerY = drawSectionHeader(doc, marginX + cardPad, innerY, 'Transaction details');
    innerY = drawDetailRows(
      doc,
      spec.details,
      marginX + cardPad,
      contentW - cardPad * 2,
      innerY,
    );
    innerY += 8;
  }

  // Extra sections (yearly summary, verification, etc.)
  if (spec.sections?.length) {
    for (const section of spec.sections) {
      innerY = drawSectionHeader(doc, marginX + cardPad, innerY, section.title);
      if (section.rows?.length) {
        innerY = drawDetailRows(
          doc,
          section.rows,
          marginX + cardPad,
          contentW - cardPad * 2,
          innerY,
        );
      }
      if (section.lineItems?.length) {
        innerY = drawLineItemsTable(
          doc,
          marginX + cardPad,
          innerY,
          contentW - cardPad * 2,
          section.lineItems,
        );
      }
      innerY += 10;
    }
  }

  cursorY += cardInnerH + 24;

  // Footer
  drawModernFooter(doc, spec, marginX, contentW, cursorY);
}

function estimateCardHeight(spec: ReceiptDocument): number {
  let h = 48; // title area
  if (spec.subtitle) h += 22;
  if (spec.status) h += 36;
  if (spec.amount) h += 88;
  if (spec.parties?.length) h += spec.parties.length * 36 + 16;
  if (spec.details?.length) h += 28 + spec.details.length * 26;
  if (spec.sections?.length) {
    for (const s of spec.sections) {
      h += 28;
      h += (s.rows?.length ?? 0) * 26;
      h += (s.lineItems?.length ?? 0) * 22 + 36;
    }
  }
  return Math.max(h + 40, 200);
}

function drawAmountHero(
  doc: PdfDoc,
  x: number,
  y: number,
  w: number,
  amount: ReceiptAmount,
): number {
  const boxH = 76;
  doc.save();
  doc.roundedRect(x, y, w, boxH, 10).fill('#F8FAFC');
  doc.roundedRect(x, y, w, boxH, 10).lineWidth(1).stroke(COLORS.border);
  doc.restore();

  const currency = amount.currency ?? 'BYC';
  const numeric = amount.value.replace(/[^\d.-]/g, '');
  let display = `${numeric} ${currency}`.trim();
  let color = COLORS.text;
  if (amount.direction === 'in') {
    display = `+${display}`;
    color = COLORS.incoming;
  } else if (amount.direction === 'out') {
    display = `−${display}`.replace('−-', '−');
    color = COLORS.outgoing;
  }

  doc.font('Helvetica').fontSize(10).fillColor(COLORS.muted);
  doc.text('AMOUNT', x, y + 14, { width: w, align: 'center' });

  doc.font('Helvetica-Bold').fontSize(28).fillColor(color);
  doc.text(display, x, y + 32, { width: w, align: 'center' });

  return y + boxH;
}

function drawPartiesBlock(
  doc: PdfDoc,
  x: number,
  y: number,
  w: number,
  parties: { label: string; name: string }[],
): number {
  let cy = y;
  for (const p of parties) {
    doc.font('Helvetica').fontSize(9).fillColor(COLORS.muted);
    doc.text(p.label.toUpperCase(), x, cy, { width: w * 0.35 });
    doc.font('Helvetica-Bold').fontSize(11).fillColor(COLORS.text);
    doc.text(p.name, x + w * 0.35, cy, { width: w * 0.65, align: 'right' });
    cy += 28;
    if (parties.indexOf(p) < parties.length - 1) {
      doc.moveTo(x, cy - 8).lineTo(x + w, cy - 8).strokeColor(COLORS.border).lineWidth(0.5).stroke();
    }
  }
  return cy;
}

function drawSectionHeader(doc: PdfDoc, x: number, y: number, title: string): number {
  doc.font('Helvetica-Bold').fontSize(9).fillColor(COLORS.primary);
  doc.text(title.toUpperCase(), x, y);
  doc.moveTo(x, y + 14).lineTo(x + 80, y + 14).strokeColor(COLORS.primary).lineWidth(2).stroke();
  return y + 22;
}

function drawDetailRows(
  doc: PdfDoc,
  rows: ReceiptDetailRow[],
  x: number,
  w: number,
  startY: number,
): number {
  let y = startY;
  const labelW = w * 0.42;
  const valueW = w * 0.58;

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    doc.font('Helvetica').fontSize(9).fillColor(COLORS.muted);
    doc.text(row.label, x, y + 2, { width: labelW });

    const font = row.monospace ? 'Courier' : 'Helvetica-Bold';
    doc.font(font).fontSize(row.monospace ? 8.5 : 10).fillColor(COLORS.text);
    doc.text(row.value, x + labelW, y, { width: valueW, align: 'right' });

    y += 24;
    if (i < rows.length - 1) {
      doc.moveTo(x, y - 10)
        .lineTo(x + w, y - 10)
        .strokeColor(COLORS.border)
        .lineWidth(0.5)
        .stroke();
    }
  }
  return y;
}

function drawLineItemsTable(
  doc: PdfDoc,
  x: number,
  y: number,
  w: number,
  items: ReceiptLineItem[],
): number {
  const colDate = x;
  const colDesc = x + 72;
  const colAmt = x + w - 72;
  const headerH = 22;

  doc.save();
  doc.rect(x, y, w, headerH).fill('#F3F4F6');
  doc.restore();

  doc.font('Helvetica-Bold').fontSize(8).fillColor(COLORS.muted);
  doc.text('DATE', colDate + 8, y + 7, { width: 60 });
  doc.text('DESCRIPTION', colDesc, y + 7, { width: w - 160 });
  doc.text('AMOUNT', colAmt, y + 7, { width: 64, align: 'right' });

  let cy = y + headerH;
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    if (i % 2 === 1) {
      doc.save();
      doc.rect(x, cy, w, 20).fill('#FAFAFA');
      doc.restore();
    }
    doc.font('Helvetica').fontSize(8.5).fillColor(COLORS.muted);
    doc.text(item.date, colDate + 8, cy + 5, { width: 60 });
    doc.font('Helvetica').fontSize(9).fillColor(COLORS.text);
    doc.text(item.description, colDesc, cy + 5, { width: w - 160 });
    doc.font('Helvetica-Bold').fontSize(9).fillColor(COLORS.text);
    doc.text(item.amount, colAmt, cy + 5, { width: 64, align: 'right' });
    cy += 20;
  }

  return cy + 8;
}

function drawStatusBadge(
  doc: PdfDoc,
  x: number,
  y: number,
  status: string,
  tone: ReceiptStatusTone,
): number {
  const palette = {
    success: { bg: COLORS.successBg, fg: COLORS.successText },
    warning: { bg: COLORS.warningBg, fg: COLORS.warningText },
    error: { bg: COLORS.errorBg, fg: COLORS.errorText },
    neutral: { bg: COLORS.neutralBg, fg: COLORS.neutralText },
  }[tone];

  const label = status.replace(/_/g, ' ');
  doc.font('Helvetica-Bold').fontSize(9);
  const textW = doc.widthOfString(label);
  const padX = 12;
  const badgeW = textW + padX * 2;
  const badgeH = 22;

  doc.roundedRect(x, y, badgeW, badgeH, 11).fill(palette.bg);
  doc.fillColor(palette.fg).text(label, x + padX, y + 6);

  return y + badgeH;
}

function drawModernFooter(
  doc: PdfDoc,
  spec: ReceiptDocument,
  marginX: number,
  contentW: number,
  y: number,
) {
  const note =
    spec.footerNote ??
    'This document was generated electronically by BYBATA for your records. ' +
      'It is not a tax invoice unless your jurisdiction requires otherwise. ' +
      'Keep this receipt for wallet and donation history.';

  doc.font('Helvetica').fontSize(8).fillColor(COLORS.muted);
  doc.text(note, marginX, y, { width: contentW, align: 'center', lineGap: 2 });

  const footerY = doc.page.height - 36;
  doc.moveTo(marginX, footerY - 12)
    .lineTo(marginX + contentW, footerY - 12)
    .strokeColor(COLORS.border)
    .lineWidth(0.5)
    .stroke();

  doc.font('Helvetica').fontSize(7.5).fillColor(COLORS.muted);
  doc.text(
    `© ${new Date().getUTCFullYear()} BYBATA · bybata.com · Generated ${formatDate(new Date())}`,
    marginX,
    footerY,
    { width: contentW, align: 'center' },
  );
}

function statusToneFromString(status: string): ReceiptStatusTone {
  const s = status.toUpperCase();
  if (['SUCCESS', 'COMPLETED', 'CONFIRMED', 'SETTLED'].includes(s)) return 'success';
  if (['PENDING', 'PROCESSING', 'IN_PROGRESS'].includes(s)) return 'warning';
  if (['FAILED', 'CANCELLED', 'REJECTED', 'REFUNDED'].includes(s)) return 'error';
  return 'neutral';
}

function truncateId(id: string, max = 22): string {
  if (id.length <= max) return id;
  return `${id.slice(0, 10)}…${id.slice(-8)}`;
}

// Legacy helpers (old renderPdf path)
function drawLegacyBrandHeader(doc: PdfDoc) {
  doc.fontSize(22).fillColor(COLORS.primary).text('BYBATA', { align: 'center' });
  doc.moveDown(0.3);
  doc.fontSize(10).fillColor(COLORS.muted).text('Building communities through sharing', {
    align: 'center',
  });
  doc.moveDown(1.2);
  doc.strokeColor(COLORS.border).lineWidth(1).moveTo(50, doc.y).lineTo(545, doc.y).stroke();
  doc.moveDown(0.8);
}

function drawLegacyFooter(doc: PdfDoc) {
  const bottom = doc.page.height - 60;
  doc.fontSize(8).fillColor(COLORS.muted).text(
    'This document is generated by BYBATA for your records. It is not a tax invoice unless stated otherwise.',
    50,
    bottom,
    { align: 'center', width: 495 },
  );
}
