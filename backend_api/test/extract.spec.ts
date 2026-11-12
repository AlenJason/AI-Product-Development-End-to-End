import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  existsSync,
  symlinkSync,
  rmSync,
  realpathSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, sep } from 'node:path';
import { spawnSync } from 'node:child_process';

const script = resolve('extract.cjs');
describe('extract helper filesystem security (isolated temporary directory)', () => {
  let sandbox: string, out: string, input: string;
  const block = (name: string, body = 'export const value = 1;') =>
    '`' + name + '`:\n```ts\n' + body + '\n```\n';
  const run = (text: string) => {
    writeFileSync(input, text);
    return spawnSync(process.execPath, [script, input, '--out', out], {
      cwd: out,
      encoding: 'utf8',
    });
  };
  beforeEach(() => {
    sandbox = mkdtempSync(join(tmpdir(), 'smartfit-extract-'));
    out = join(sandbox, 'output');
    input = join(sandbox, 'input.md');
    mkdirSync(out);
  });
  afterEach(() => {
    const absolute = realpathSync(sandbox),
      base = realpathSync(tmpdir());
    if (!absolute.startsWith(base + sep))
      throw new Error('Unsafe test cleanup path');
    rmSync(absolute, { recursive: true, force: true });
  });
  it('extracts supported project-relative paths inside configured output', () => {
    const result = run(
      block('backend_api/src/example.ts') +
        block('test/example.ts') +
        block('ai_workspace/example.ts'),
    );
    expect(result.status).toBe(0);
    expect(readFileSync(join(out, 'src/example.ts'), 'utf8')).toContain(
      'export const',
    );
    expect(existsSync(join(out, 'ai_workspace/example.ts'))).toBe(true);
  });
  it.each([
    'src/../../sentinel.ts',
    'src/..\\..\\sentinel.ts',
    'src/nested/../../../sentinel.ts',
    'src/../secret.ts',
  ])('rejects traversal %s without changing outside sentinel', (name) => {
    const sentinel = join(sandbox, 'sentinel.ts');
    writeFileSync(sentinel, 'UNCHANGED');
    const result = run(block(name));
    expect(result.status).not.toBe(0);
    expect(readFileSync(sentinel, 'utf8')).toBe('UNCHANGED');
  });
  it.each([
    '/tmp/outside.ts',
    'C:\\outside.ts',
    'C:/outside.ts',
    '\\\\server\\share\\outside.ts',
    '//server/share/outside.ts',
  ])('rejects absolute/drive/UNC path %s', (name) => {
    expect(run(block(name)).status).not.toBe(0);
  });
  it('refuses existing file overwrite', () => {
    mkdirSync(join(out, 'src'));
    writeFileSync(join(out, 'src/keep.ts'), 'UNCHANGED');
    expect(run(block('src/keep.ts')).status).not.toBe(0);
    expect(readFileSync(join(out, 'src/keep.ts'), 'utf8')).toBe('UNCHANGED');
  });
  it('rejects a directory symlink/junction leading outside output', () => {
    const outside = join(sandbox, 'outside');
    mkdirSync(outside);
    writeFileSync(join(outside, 'keep.ts'), 'UNCHANGED');
    symlinkSync(
      outside,
      join(out, 'src'),
      process.platform === 'win32' ? 'junction' : 'dir',
    );
    expect(run(block('src/keep.ts')).status).not.toBe(0);
    expect(readFileSync(join(outside, 'keep.ts'), 'utf8')).toBe('UNCHANGED');
  });
  it('does not overwrite sensitive files and validates all paths before writing', () => {
    const sentinel = join(sandbox, '.env');
    writeFileSync(sentinel, 'SYNTHETIC SENTINEL');
    const result = run(block('src/good.ts') + block('src/../../.env'));
    expect(result.status).not.toBe(0);
    expect(readFileSync(sentinel, 'utf8')).toBe('SYNTHETIC SENTINEL');
    expect(existsSync(join(out, 'src/good.ts'))).toBe(false);
  });
  it('reports invalid input without writing output', () => {
    expect(run('no extractable blocks').status).not.toBe(0);
    const missing = spawnSync(process.execPath, [script], {
      cwd: out,
      encoding: 'utf8',
    });
    expect(missing.status).not.toBe(0);
    expect(missing.stderr).toMatch(/usage|input/i);
  });
  it('accepts mixed separators within the root and blank lines in legacy specifications', () => {
    const result = run(block('src\\nested/valid.ts').replace(':\n', ':\n\n'));
    expect(result.status).toBe(0);
    expect(existsSync(join(out, 'src/nested/valid.ts'))).toBe(true);
  });
  it.each([
    'src/private.ts:stream',
    'src/CON.ts',
    'src/nested./evil.ts',
    'src/.env',
    'src/config.db',
  ])('rejects unsafe or sensitive output name %s', (name) => {
    expect(run(block(name)).status).not.toBe(0);
  });
  it('rejects duplicate normalized output names before creating files', () => {
    expect(
      run(block('src/duplicate.ts') + block('backend_api/src/duplicate.ts'))
        .status,
    ).not.toBe(0);
    expect(existsSync(join(out, 'src/duplicate.ts'))).toBe(false);
  });
  it('refuses a symlink/junction used as the configured output root', () => {
    const linked = join(sandbox, 'linked');
    symlinkSync(out, linked, process.platform === 'win32' ? 'junction' : 'dir');
    writeFileSync(input, block('src/escape.ts'));
    const result = spawnSync(
      process.execPath,
      [script, input, '--out', linked],
      { cwd: out, encoding: 'utf8' },
    );
    expect(result.status).not.toBe(0);
    expect(existsSync(join(out, 'src/escape.ts'))).toBe(false);
  });
});
