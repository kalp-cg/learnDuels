const express = require('express');
const router = express.Router();
const savedController = require('../controllers/saved.controller');
const { authenticate } = require('../middlewares/auth.middleware');

router.use(authenticate);

router.post('/toggle', savedController.toggleSave);
router.get('/', savedController.getSavedQuestions);

module.exports = router;
