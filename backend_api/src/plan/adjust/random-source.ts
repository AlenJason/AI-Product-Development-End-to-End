import { Injectable } from '@nestjs/common';

// Nguồn ngẫu nhiên khi chọn món/động tác thay thế trong kho, để đổi nhiều lần không lặp đi lặp lại một cặp món.
// Test thay bằng giá trị cố định để kết quả lặp lại được.
@Injectable()
export class RandomSource {
  next(): number {
    return Math.random();
  }
}

export function pickOne<T>(items: T[], random: RandomSource): T | undefined {
  if (items.length === 0) return undefined;
  return items[Math.min(items.length - 1, Math.floor(random.next() * items.length))];
}
