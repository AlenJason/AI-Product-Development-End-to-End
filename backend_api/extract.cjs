const fs = require('node:fs');
const path = require('node:path');

// Development helper. Use a separate output directory; never the live source tree.
// Existing files are never overwritten.
function destinationName(name) {
  if (
    typeof name !== 'string' ||
    !name ||
    /[\x00-\x1f]/.test(name) ||
    path.win32.isAbsolute(name) ||
    path.posix.isAbsolute(name) ||
    /^[A-Za-z]:/.test(name)
  ) {
    throw new Error('Unsafe absolute/drive/UNC output path');
  }
  const parts = name.replace(/\\/g, '/').split('/');
  if (
    parts.some(
      (part) =>
        !part ||
        part === '.' ||
        part === '..' ||
        /[<>:"|?*]/.test(part) ||
        /[. ]$/.test(part) ||
        /^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(part),
    )
  ) {
    throw new Error('Unsafe traversal or invalid output path');
  }
  if (parts[0] === 'backend_api') parts.shift();
  if (
    !['src', 'test', 'ai_workspace'].includes(parts[0]) ||
    parts.length < 2 ||
    !/\.(?:ts|json)$/i.test(parts.at(-1)) ||
    parts.some((part) => /^\.env(?:\.|$)/i.test(part))
  ) {
    throw new Error(
      'Output must be a TypeScript/JSON file under src, test or ai_workspace',
    );
  }
  return parts.join('/');
}

function checkParents(directory) {
  const full = path.resolve(directory);
  let cursor = path.parse(full).root;
  for (const part of full
    .slice(cursor.length)
    .split(path.sep)
    .filter(Boolean)) {
    cursor = path.join(cursor, part);
    try {
      const stat = fs.lstatSync(cursor);
      if (stat.isSymbolicLink() || !stat.isDirectory())
        throw new Error(
          'Output parent must be a real directory, without symlinks/junctions',
        );
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
}

function extractFile(input, outputDirectory = path.resolve('extracted')) {
  if (!input)
    throw new Error(
      'Usage: node extract.cjs <input.md> [--out <output-directory>]',
    );
  const inputStat = fs.lstatSync(input);
  if (inputStat.isSymbolicLink() || !inputStat.isFile())
    throw new Error('Input must be a regular Markdown file');
  const text = fs.readFileSync(input, 'utf8');
  const root = path.resolve(outputDirectory);
  checkParents(root);
  const pattern =
    /`([^`\r\n]+)`:[^\r\n]*\r?\n(?:[ \t]*\r?\n)*[ \t]*```(?:ts|json)[ \t]*\r?\n([\s\S]*?)```/g;
  const entries = [...text.matchAll(pattern)].map((match) => ({
    name: destinationName(match[1]),
    body: match[2],
  }));
  if (!entries.length)
    throw new Error('Input contains no supported file blocks');
  const seen = new Set();
  // Validate the complete input before creating any files.
  for (const entry of entries) {
    const dest = path.resolve(root, entry.name);
    const relative = path.relative(root, dest);
    if (
      !relative ||
      relative.startsWith(`..${path.sep}`) ||
      path.isAbsolute(relative)
    )
      throw new Error('Output escapes configured directory');
    const identity = dest.toLowerCase();
    if (seen.has(identity)) throw new Error('Duplicate output path');
    seen.add(identity);
    checkParents(path.dirname(dest));
    try {
      fs.lstatSync(dest);
      throw new Error('Refusing to overwrite existing output');
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  fs.mkdirSync(root, { recursive: true });
  const actualRoot = fs.realpathSync(root);
  for (const entry of entries) {
    const dest = path.resolve(root, entry.name);
    checkParents(path.dirname(dest));
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    const parent = fs.realpathSync(path.dirname(dest));
    const relative = path.relative(actualRoot, parent);
    if (
      relative.startsWith(`..${path.sep}`) ||
      relative === '..' ||
      path.isAbsolute(relative)
    )
      throw new Error('Resolved output escapes configured directory');
    fs.writeFileSync(dest, entry.body, { flag: 'wx', mode: 0o600 });
  }
  return entries.map((entry) => entry.name);
}

module.exports = { extractFile, destinationName };
if (require.main === module) {
  try {
    const args = process.argv.slice(2);
    if (
      ![1, 3].includes(args.length) ||
      (args.length === 3 && args[1] !== '--out')
    )
      throw new Error(
        'Usage: node extract.cjs <input.md> [--out <output-directory>]',
      );
    const files = extractFile(args[0], args[2]);
    console.log(
      `Extracted ${files.length} files into isolated output directory.`,
    );
  } catch (error) {
    console.error(`Extraction failed: ${error.code || error.message}`);
    process.exitCode = 1;
  }
}
