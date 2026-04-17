const express = require('express');
const router = express.Router();
const careerController = require('../controllers/careerController');
const { authenticateToken } = require('../middleware/authMiddleware');

// POST /api/career - Add a new career entry
router.post('/', authenticateToken, careerController.addCareerEntry);

// GET /api/career/:userId - Get all career history for a user
router.get('/:userId', careerController.getCareerHistory);

// PUT /api/career/:entryId - Update a career entry
router.put('/:entryId', authenticateToken, careerController.updateCareerEntry);

// DELETE /api/career/:entryId - Delete a career entry
router.delete('/:entryId', authenticateToken, careerController.deleteCareerEntry);

module.exports = router;
