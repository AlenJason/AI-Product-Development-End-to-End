import request from 'supertest';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

describe('Profile Persistence E2E Tests (Lưu & Nạp hồ sơ người dùng tự động)', () => {
  let testApp: TestApp;
  const http = () => request(testApp.app.getHttpServer());

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('1. New user has no saved profile initially ({ profile: null })', async () => {
    const { access_token } = await loginMock(testApp, 'new-user@vku.edu.vn');
    const res = await http()
      .get('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .expect(200);

    expect(res.body).toEqual({ profile: null });
  });

  it('2. PUT /api/v1/me/profile persists physical metrics and GET returns identical profile', async () => {
    const { access_token } = await loginMock(testApp, 'active-user@vku.edu.vn');

    const profileData = {
      age: 22,
      gender: 'male',
      height_cm: 175,
      weight_kg: 68.5,
      activity_level: 'moderate',
      goal: 'maintain',
    };

    const putRes = await http()
      .put('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .send(profileData)
      .expect(200);

    expect(putRes.body.success).toBe(true);
    expect(putRes.body.profile).toEqual(profileData);

    const getRes = await http()
      .get('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .expect(200);

    expect(getRes.body.profile).toEqual(profileData);
  });

  it('3. Clinical Privacy D4/D5: Sensitive health data (allergies, injuries, conditions) are never stored in DB', async () => {
    const { access_token } = await loginMock(testApp, 'privacy-user@vku.edu.vn');

    await http()
      .put('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .send({
        age: 25,
        gender: 'female',
        height_cm: 162,
        weight_kg: 52,
        activity_level: 'light',
        goal: 'maintain',
        restrictions: {
          allergies: 'Tôm, cua, đậu phộng',
          health_conditions: 'Tiểu đường type 2, huyết áp',
          injuries: 'Đau thắt lưng, chấn thương khớp gối',
        },
        credit_card: '1234-5678-9012',
        unauthorized_field: 'should-be-dropped',
      })
      .expect(200);

    const getRes = await http()
      .get('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .expect(200);

    const profile = getRes.body.profile;
    expect(profile).toBeDefined();
    expect(profile.age).toBe(25);
    expect(profile.gender).toBe('female');
    expect(profile.height_cm).toBe(162);
    expect(profile.weight_kg).toBe(52);

    // Verify restrictions, sensitive medical conditions and arbitrary fields are stripped completely
    expect(profile.restrictions).toBeUndefined();
    expect(profile.allergies).toBeUndefined();
    expect(profile.health_conditions).toBeUndefined();
    expect(profile.injuries).toBeUndefined();
    expect(profile.credit_card).toBeUndefined();
    expect(profile.unauthorized_field).toBeUndefined();
  });

  it('4. Security: unauthenticated access to /api/v1/me/profile is denied with HTTP 401', async () => {
    await http().get('/api/v1/me/profile').expect(401);
    await http().put('/api/v1/me/profile').send({ age: 25 }).expect(401);
    await http().get('/api/v1/me/profile').set('Authorization', 'Bearer invalid-token').expect(401);
  });

  it('5. Generating a plan with auth token automatically persists user profile to database', async () => {
    const { access_token } = await loginMock(testApp, 'plan-user@vku.edu.vn');

    // Initially profile is null
    const before = await http()
      .get('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .expect(200);
    expect(before.body.profile).toBeNull();

    // User generates plan with valid CreatePlanDto
    await http()
      .post('/api/v1/generate-plan')
      .set('Authorization', `Bearer ${access_token}`)
      .send({
        age: 26,
        gender: 'female',
        height_cm: 165,
        weight_kg: 58,
        activity_level: 'light',
        goal: 'maintain',
        restrictions: {
          dietary_preference: '',
          allergies: 'Hải sản',
          injuries: '',
          health_conditions: '',
        },
      })
      .expect(200);

    // Profile should now be automatically saved in DB
    const after = await http()
      .get('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .expect(200);

    expect(after.body.profile).toEqual({
      age: 26,
      gender: 'female',
      height_cm: 165,
      weight_kg: 58,
      activity_level: 'light',
      goal: 'maintain',
      pregnant_or_breastfeeding: false,
    });
  });

  it('6. Multiple updates to profile overwrite previous metrics reliably', async () => {
    const { access_token } = await loginMock(testApp, 'multi-update@vku.edu.vn');

    // First update
    await http()
      .put('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .send({ age: 20, gender: 'male', height_cm: 170, weight_kg: 65, activity_level: 'light', goal: 'maintain' })
      .expect(200);

    // Second update: user lost 3kg and increased activity
    await http()
      .put('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .send({ age: 20, gender: 'male', height_cm: 170, weight_kg: 62, activity_level: 'moderate', goal: 'maintain' })
      .expect(200);

    const res = await http()
      .get('/api/v1/me/profile')
      .set('Authorization', `Bearer ${access_token}`)
      .expect(200);

    expect(res.body.profile.weight_kg).toBe(62);
    expect(res.body.profile.activity_level).toBe('moderate');
  });
});
