import { DataSource } from 'typeorm';
import { dataSourceOptions } from '../src/database/data-source-options.js';

// SQLite trong RAM, tạo bảng bằng đúng migration của app — test không đụng file DB thật.
export function createMemoryDataSource(): Promise<DataSource> {
  return new DataSource(dataSourceOptions(':memory:')).initialize();
}
