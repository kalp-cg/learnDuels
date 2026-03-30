const healthController = require('../src/controllers/health.controller');
const httpMocks = require('node-mocks-http');

// Mock config
jest.mock('../src/config/env', () => ({
    NODE_ENV: 'test',
}));

describe('Health Controller', () => {
    it('should return 200 and success message', () => {
        const req = httpMocks.createRequest();
        const res = httpMocks.createResponse();

        healthController.getHealth(req, res);

        const data = res._getJSONData(); // accessing the json data from mock response

        expect(res.statusCode).toBe(200);
        expect(data.success).toBe(true);
        expect(data.message).toBe('LearnDuels API is healthy');
        expect(data.environment).toBe('test');
    });
});
