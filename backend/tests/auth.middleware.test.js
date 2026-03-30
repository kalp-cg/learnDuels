const { authRateLimit } = require('../src/middlewares/auth.middleware');

function createMockRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

describe('authRateLimit middleware', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('allows requests up to max attempts and then blocks', () => {
    const limiter = authRateLimit(2, 60 * 1000);
    const req = { ip: '127.0.0.1' };

    const nextFirst = jest.fn();
    limiter(req, createMockRes(), nextFirst);
    expect(nextFirst).toHaveBeenCalledTimes(1);

    const nextSecond = jest.fn();
    limiter(req, createMockRes(), nextSecond);
    expect(nextSecond).toHaveBeenCalledTimes(1);

    const blockedRes = createMockRes();
    const nextThird = jest.fn();
    limiter(req, blockedRes, nextThird);

    expect(nextThird).not.toHaveBeenCalled();
    expect(blockedRes.statusCode).toBe(429);
    expect(blockedRes.body.success).toBe(false);
    expect(blockedRes.body.message).toMatch(/too many authentication attempts/i);
  });

  test('tracks attempts independently per IP', () => {
    const limiter = authRateLimit(1, 60 * 1000);

    const nextA = jest.fn();
    limiter({ ip: '10.0.0.1' }, createMockRes(), nextA);
    expect(nextA).toHaveBeenCalledTimes(1);

    const nextB = jest.fn();
    limiter({ ip: '10.0.0.2' }, createMockRes(), nextB);
    expect(nextB).toHaveBeenCalledTimes(1);
  });

  test('resets attempts after time window expires', () => {
    const limiter = authRateLimit(1, 1000);
    const nowSpy = jest.spyOn(Date, 'now');

    nowSpy.mockReturnValue(1000);
    const firstNext = jest.fn();
    limiter({ ip: '192.168.1.10' }, createMockRes(), firstNext);
    expect(firstNext).toHaveBeenCalledTimes(1);

    nowSpy.mockReturnValue(1500);
    const blockedRes = createMockRes();
    limiter({ ip: '192.168.1.10' }, blockedRes, jest.fn());
    expect(blockedRes.statusCode).toBe(429);

    nowSpy.mockReturnValue(2501);
    const nextAfterWindow = jest.fn();
    limiter({ ip: '192.168.1.10' }, createMockRes(), nextAfterWindow);
    expect(nextAfterWindow).toHaveBeenCalledTimes(1);
  });
});
