import type { DataSource } from 'typeorm';

export interface SqlParams {
  // Chỗ đặt tham số thứ `index` (đếm từ 1) trong câu SQL.
  p: (index: number) => string;
  // Mảng tham số truyền cho dataSource.query().
  params: unknown[];
}

// SQL viết tay chạy trên cả hai loại DB (#38) và dùng lại một tham số nhiều lần: Postgres có $1, $2…; better-sqlite3
// không dùng lại được `?` nên dùng tham số có tên (@p1…) truyền bằng một object.
export function sqlParams(dataSource: DataSource, values: unknown[]): SqlParams {
  if (dataSource.options.type === 'postgres') return { p: (index) => `$${index}`, params: values };
  return {
    p: (index) => `@p${index}`,
    params: [Object.fromEntries(values.map((value, index) => [`p${index + 1}`, value]))],
  };
}
