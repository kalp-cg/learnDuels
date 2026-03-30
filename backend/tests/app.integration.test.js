const request = require('supertest');
const { prisma } = require('../src/config/db');

describe('App Integration Smoke', () => {
  const originalNodeEnv = process.env.NODE_ENV;
  const originalFlag = process.env.ENABLE_TEST_TOKEN_ENDPOINT;
  const createdUserIds = [];

  beforeEach(() => {
    process.env.NODE_ENV = 'test';
    process.env.ENABLE_TEST_TOKEN_ENDPOINT = 'false';
  });

  afterEach(() => {
    process.env.NODE_ENV = originalNodeEnv;
    process.env.ENABLE_TEST_TOKEN_ENDPOINT = originalFlag;
    jest.resetModules();
  });

  afterAll(async () => {
    if (createdUserIds.length > 0) {
      await prisma.refreshToken.deleteMany({
        where: { userId: { in: createdUserIds } },
      });
      await prisma.user.deleteMany({ where: { id: { in: createdUserIds } } });
    }
    await prisma.$disconnect();
  });

  function loadApp() {
    jest.resetModules();
    const { createApp } = require('../src/app');
    return createApp();
  }

  test('GET /health returns healthy response', async () => {
    const app = loadApp();
    const res = await request(app).get('/health');

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toMatch(/healthy/i);
  });

  test('GET / returns welcome payload', async () => {
    const app = loadApp();
    const res = await request(app).get('/');

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toMatch(/Welcome to LearnDuels API/i);
  });

  test('GET /api returns endpoint map', async () => {
    const app = loadApp();
    const res = await request(app).get('/api');

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.endpoints).toBeDefined();
    expect(res.body.endpoints.auth).toBe('/api/auth');
    expect(res.body.endpoints.users).toBe('/api/users');
  });

  test('GET /api/test/token returns 404 when disabled', async () => {
    const app = loadApp();
    const res = await request(app).get('/api/test/token?id=1');

    expect(res.statusCode).toBe(404);
    expect(res.body.success).toBe(false);
  });

  test('POST /api/auth/signup validates payload', async () => {
    const app = loadApp();
    const res = await request(app).post('/api/auth/signup').send({
      username: 'u',
      email: 'bad-email',
      password: 'weak',
    });

    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toBe('Validation failed');
  });

  test('POST /api/auth/signup + /login + /me works for a new user', async () => {
    const app = loadApp();
    const now = Date.now();
    const signupPayload = {
      username: `itest_${now}`,
      email: `itest_${now}@example.com`,
      password: 'Password123',
      fullName: 'Integration Test User',
    };

    const signupRes = await request(app)
      .post('/api/auth/signup')
      .send(signupPayload);

    expect(signupRes.statusCode).toBe(201);
    expect(signupRes.body.success).toBe(true);
    expect(signupRes.body.data.user.email).toBe(signupPayload.email);
    expect(typeof signupRes.body.data.accessToken).toBe('string');

    createdUserIds.push(signupRes.body.data.user.id);

    const loginRes = await request(app).post('/api/auth/login').send({
      email: signupPayload.email,
      password: signupPayload.password,
    });

    expect(loginRes.statusCode).toBe(200);
    expect(loginRes.body.success).toBe(true);
    expect(typeof loginRes.body.data.accessToken).toBe('string');

    const meRes = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${loginRes.body.data.accessToken}`);

    expect(meRes.statusCode).toBe(200);
    expect(meRes.body.success).toBe(true);
    expect(meRes.body.data.email).toBe(signupPayload.email);
  });

  test('GET /api/auth/me rejects missing token', async () => {
    const app = loadApp();
    const res = await request(app).get('/api/auth/me');

    expect(res.statusCode).toBe(401);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toMatch(/access token required/i);
  });

});
