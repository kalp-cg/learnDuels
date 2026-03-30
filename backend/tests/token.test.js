jest.mock('../src/config/env', () => ({
  JWT_SECRET: 'test_access_secret',
  JWT_REFRESH_SECRET: 'test_refresh_secret',
  JWT_EXPIRE: '1h',
  JWT_REFRESH_EXPIRE: '7d',
}));

const {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  generateTokenPair,
  decodeToken,
  isTokenExpired,
} = require('../src/utils/token');

describe('Token Utilities', () => {
  const payload = { userId: 123, email: 'user@example.com' };

  it('generates and verifies access token', () => {
    const token = generateAccessToken(payload);
    const decoded = verifyAccessToken(token);

    expect(typeof token).toBe('string');
    expect(decoded).toBeTruthy();
    expect(decoded.userId).toBe(payload.userId);
    expect(decoded.email).toBe(payload.email);
  });

  it('generates unique refresh tokens for same payload', () => {
    const tokenA = generateRefreshToken(payload);
    const tokenB = generateRefreshToken(payload);

    expect(tokenA).not.toBe(tokenB);

    const decodedA = verifyRefreshToken(tokenA);
    const decodedB = verifyRefreshToken(tokenB);
    expect(decodedA.nonce).toBeTruthy();
    expect(decodedB.nonce).toBeTruthy();
    expect(decodedA.nonce).not.toBe(decodedB.nonce);
  });

  it('returns full token pair with expected shape', () => {
    const pair = generateTokenPair(payload);

    expect(pair).toHaveProperty('accessToken');
    expect(pair).toHaveProperty('refreshToken');
    expect(pair).toHaveProperty('expiresIn', '1h');
    expect(pair).toHaveProperty('tokenType', 'Bearer');
  });

  it('detects invalid token verification as null', () => {
    expect(verifyAccessToken('invalid.token.value')).toBeNull();
    expect(verifyRefreshToken('invalid.token.value')).toBeNull();
  });

  it('decodes token and checks expiration helper', () => {
    const token = generateAccessToken(payload);
    const decoded = decodeToken(token);

    expect(decoded).toBeTruthy();
    expect(decoded.payload.userId).toBe(payload.userId);
    expect(isTokenExpired(token)).toBe(false);
    expect(isTokenExpired('bad.token')).toBe(true);
  });
});
