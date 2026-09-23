import type { DataSource } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';

describe('database migrations', () => {
  let dataSource: DataSource;

  beforeEach(async () => {
    dataSource = await createMemoryDataSource();
  });

  afterEach(async () => {
    if (dataSource.isInitialized) await dataSource.destroy();
  });

  // Sửa entity mà quên viết migration → test này in ra đúng câu SQL còn thiếu.
  it('creates exactly the schema the entities describe', async () => {
    const { upQueries } = await dataSource.driver.createSchemaBuilder().log();
    expect(upQueries.map((query) => query.query)).toEqual([]);
  });

  it('enforces foreign keys, so deleting a user deletes their plans', async () => {
    expect(await dataSource.query('PRAGMA foreign_keys')).toEqual([{ foreign_keys: 1 }]);
  });

  it('reverts cleanly', async () => {
    await dataSource.undoLastMigration();
    const tables = await dataSource.query(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('users', 'plan_records')",
    );
    expect(tables).toEqual([]);
  });
});
