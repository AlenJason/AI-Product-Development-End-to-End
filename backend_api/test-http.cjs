const { execSync, spawn } = require('child_process');

async function run() {
  const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  const curlCmd = process.platform === 'win32' ? 'curl.exe' : 'curl';

  console.log('Building...');
  execSync(`${npmCmd} run build`, { stdio: 'inherit' });

  console.log('Starting server...');
  const server = spawn(npmCmd, ['run', 'start'], { stdio: 'ignore' });
  
  // wait for server
  console.log('Waiting for server...');
  let up = false;
  for (let i = 0; i < 20; i++) {
    try {
      execSync(`${curlCmd} -s http://localhost:3000/health`);
      up = true;
      break;
    } catch {
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  if (!up) {
    console.error('Server did not start');
    server.kill();
    process.exit(1);
  }

  console.log('\n--- Test 1 (Sample with warnings) ---');
  try {
    const res1 = execSync(`${curlCmd} -s -X POST http://localhost:3000/api/v1/generate-plan -H "Content-Type: application/json" -d "{\\"age\\":22,\\"gender\\":\\"female\\",\\"height_cm\\":168,\\"weight_kg\\":62,\\"activity_level\\":\\"light\\",\\"goal\\":\\"cut\\",\\"restrictions\\":{\\"allergies\\":\\"Hải sản\\"}}"`, { encoding: 'utf8' });
    console.log(res1.includes('"source":"sample"') ? '"source":"sample" FOUND' : 'NOT FOUND');
    console.log(res1.includes('Đang dùng thực đơn mẫu') ? 'Đang dùng thực đơn mẫu FOUND' : 'NOT FOUND');
  } catch (e) {
    console.log('Error:', e.message);
  }

  console.log('\n--- Test 2 (400 for array) ---');
  try {
    const res2 = execSync(`${curlCmd} -s -o NUL -w "%{http_code}\\n" -X POST http://localhost:3000/api/v1/generate-plan -H "Content-Type: application/json" -d "{\\"age\\":22,\\"gender\\":\\"female\\",\\"height_cm\\":168,\\"weight_kg\\":62,\\"activity_level\\":\\"light\\",\\"goal\\":\\"cut\\",\\"restrictions\\":{\\"allergies\\":[\\"Hải sản\\"]}}"`, { encoding: 'utf8' });
    console.log('HTTP Code:', res2.trim());
  } catch (e) {
    console.log('Error:', e.message);
  }

  console.log('\n--- Test 3 (200 for no restrictions) ---');
  try {
    const res3 = execSync(`${curlCmd} -s -o NUL -w "%{http_code}\\n" -X POST http://localhost:3000/api/v1/generate-plan -H "Content-Type: application/json" -d "{\\"age\\":22,\\"gender\\":\\"female\\",\\"height_cm\\":168,\\"weight_kg\\":62,\\"activity_level\\":\\"light\\",\\"goal\\":\\"cut\\"}"`, { encoding: 'utf8' });
    console.log('HTTP Code:', res3.trim());
  } catch (e) {
    console.log('Error:', e.message);
  }

  console.log('\n--- Test 4 (Swagger MealPlanResponseDto) ---');
  try {
    const res4 = execSync(`${curlCmd} -s http://localhost:3000/docs-json`, { encoding: 'utf8' });
    console.log(res4.includes('"MealPlanResponseDto"') ? '"MealPlanResponseDto" FOUND' : 'NOT FOUND');
  } catch (e) {
    console.log('Error:', e.message);
  }

  server.kill();
  process.exit(0);
}
run();
