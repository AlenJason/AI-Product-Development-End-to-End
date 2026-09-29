export function normalizeKey(text: string): string {
  return text.trim().replace(/\s+/g, ' ').toLowerCase();
}

// Bỏ < > để người dùng không giả được thẻ phân cách dữ liệu trong prompt; gộp xuống dòng để không giả được dòng chỉ dẫn mới.
export function sanitizeUserText(text: string | null | undefined): string {
  if (!text) return '';
  return text.replace(/[<>]/g, '').replace(/\s+/g, ' ').trim();
}
