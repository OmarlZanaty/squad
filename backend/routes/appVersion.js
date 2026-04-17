const express = require('express');
  const router  = express.Router();
  const ctrl    = require('../controllers/appVersionController');
 
  router.get('/version-policy',  ctrl.getVersionPolicy);
  router.put('/version-policy',  ctrl.updateVersionPolicy);   // admin
 
  module.exports = router;
 
