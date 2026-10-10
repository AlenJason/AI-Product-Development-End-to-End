const fs = require('fs');
const path = require('path');
const text = fs.readFileSync('d:/AI-Product-Development-End-to-End/docs/superpowers/plans/phase-4-swap-feedback/specs/F01-calories-restrictions.md', 'utf-8');

const regex = /`((?:backend_api\/)?(?:src|test|ai_workspace)\/[^`]+)`:[\s\S]*?```(ts|json)\r?\n([\s\S]*?)```/g;
let m;
while ((m = regex.exec(text)) !== null) {
  let filepath = m[1];
  if (filepath.startsWith('backend_api/')) filepath = filepath.replace('backend_api/', '');
  else if (filepath.startsWith('ai_workspace/')) filepath = '../' + filepath;
  
  console.log('Writing:', filepath);
  fs.mkdirSync(path.dirname(filepath), { recursive: true });
  fs.writeFileSync(filepath, m[3]);
}
