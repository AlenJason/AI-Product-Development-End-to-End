import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { RestrictionsDto } from './dto/restrictions.dto.js';
import type { ExerciseContentDto, MealContentDto } from './dto/plan-content.dto.js';
import { ExerciseTag } from './enums/exercise.enum.js';

// Bộ khớp từ khoá cho chế độ giả lập (D4, BRD FR-1.4): nhận ra dị ứng, chấn thương phổ biến trong văn bản tự do
// để lọc thực đơn mẫu và kho món/động tác. Chỉ trả về kết quả khớp, không giữ lại chữ người dùng nhập (#12).

interface AllergyGroup {
  labels: string[];
  avoid: string[];
}

interface InjuryGroup {
  labels: string[];
  avoid_tags: ExerciseTag[];
}

interface KeywordData {
  allergies: AllergyGroup[];
  injuries: InjuryGroup[];
  none: string[];
}

export interface RestrictionMatch {
  // Từ khoá nguyên liệu cần tránh, có dấu, chữ thường — so với tên món và tên nguyên liệu.
  avoidIngredients: string[];
  avoidTags: ExerciseTag[];
  // Có đoạn dị ứng/chấn thương không khớp từ khoá nào → app cảnh báo chung, không nhắc lại đoạn đó.
  hasUnrecognized: boolean;
}

const KEYWORDS_PATH = fileURLToPath(new URL('./data/restriction-keywords.json', import.meta.url));
const KEYWORDS = loadKeywords();
const FRAGMENT_SEPARATOR = /[,;.\n/+&]|\s(?:và|hoặc|với|va|hoac|voi)\s/i;

export function matchRestrictions(restrictions: RestrictionsDto): RestrictionMatch {
  const allergies = matchGroups(restrictions.allergies, KEYWORDS.allergies);
  const injuries = matchGroups(restrictions.injuries, KEYWORDS.injuries);
  return {
    avoidIngredients: unique(allergies.groups.flatMap((group) => group.avoid)),
    avoidTags: unique(injuries.groups.flatMap((group) => group.avoid_tags)),
    hasUnrecognized: allergies.hasUnrecognized || injuries.hasUnrecognized,
  };
}

// Trả về từ khoá đầu tiên có trong tên món hoặc tên nguyên liệu, hoặc null.
// So có dấu: bỏ dấu thì "cá" trùng "cà chua", "bò" trùng "bơ".
export function findAvoidedIngredient(meal: MealContentDto, avoid: string[]): string | null {
  const texts = [meal.name, ...meal.ingredients.map((ingredient) => ingredient.name)].map(accentTokens);
  return avoid.find((keyword) => texts.some((tokens) => containsSequence(tokens, accentTokens(keyword)))) ?? null;
}

export function hasAvoidedTag(exercise: Pick<ExerciseContentDto, 'tags'>, avoidTags: ExerciseTag[]): boolean {
  return exercise.tags.some((tag) => avoidTags.includes(tag));
}

function matchGroups<T extends { labels: string[] }>(
  text: string | undefined,
  groups: T[],
): { groups: T[]; hasUnrecognized: boolean } {
  const matched = new Set<T>();
  let hasUnrecognized = false;
  for (const fragment of (text ?? '').split(FRAGMENT_SEPARATOR)) {
    const hasAccents = foldAccents(fragment) !== fragment.toLowerCase();
    // Người dùng gõ có dấu → so có dấu ("cà chua" không khớp "cá"); gõ không dấu → so không dấu.
    const tokens = hasAccents ? accentTokens(fragment) : foldedTokens(fragment);
    if (tokens.length === 0 || isNone(tokens)) continue;
    const hits = groups.filter((group) =>
      group.labels.some((label) => containsSequence(tokens, hasAccents ? accentTokens(label) : foldedTokens(label))),
    );
    if (hits.length === 0) hasUnrecognized = true;
    for (const hit of hits) matched.add(hit);
  }
  return { groups: [...matched], hasUnrecognized };
}

function isNone(tokens: string[]): boolean {
  const folded = foldedTokens(tokens.join(' ')).join(' ');
  return KEYWORDS.none.some((phrase) => foldedTokens(phrase).join(' ') === folded);
}

function containsSequence(tokens: string[], sequence: string[]): boolean {
  if (sequence.length === 0) return false;
  for (let start = 0; start + sequence.length <= tokens.length; start++) {
    if (sequence.every((word, offset) => tokens[start + offset] === word)) return true;
  }
  return false;
}

function accentTokens(text: string): string[] {
  return text.normalize('NFC').toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean);
}

function foldedTokens(text: string): string[] {
  return accentTokens(foldAccents(text));
}

// NFD tách dấu thanh và dấu mũ, nhưng không tách "đ" — phải thay tay.
function foldAccents(text: string): string {
  return text
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();
}

function unique<T>(values: T[]): T[] {
  return [...new Set(values)];
}

function loadKeywords(): KeywordData {
  const data = JSON.parse(readFileSync(KEYWORDS_PATH, 'utf-8')) as KeywordData;
  const tags = new Set<string>(Object.values(ExerciseTag));
  const badTag = data.injuries.flatMap((group) => group.avoid_tags).find((tag) => !tags.has(tag));
  if (badTag) throw new Error(`restriction-keywords.json: tag "${badTag}" không có trong ExerciseTag`);
  return data;
}
