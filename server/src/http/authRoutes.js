const express = require("express");
const authService = require("../services/authService");

const router = express.Router();

router.post("/register", async (req, res) => {
  try {
    const result = await authService.register(req.body);
    return res.status(201).json({ ok: true, ...result });
  } catch (err) {
    return res.status(400).json({ ok: false, message: err.message });
  }
});

router.post("/login", async (req, res) => {
  try {
    const result = await authService.login(req.body);
    return res.status(200).json({ ok: true, ...result });
  } catch (err) {
    return res.status(401).json({ ok: false, message: err.message });
  }
});

module.exports = router;

