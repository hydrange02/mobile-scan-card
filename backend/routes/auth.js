const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

router.post('/register', async (req, res) => {
  try {
    const { username, email, password, pin } = req.body;
    const strPin = pin != null ? String(pin).trim() : '';

    if (!username || !email || !password || !strPin) {
      return res.status(400).json({ error: 'All fields including PIN are required' });
    }
    if (!/^\d{6}$/.test(strPin)) {
      return res.status(400).json({ error: 'Mã PIN bảo mật phải gồm đúng 6 chữ số' });
    }
    const cleanEmail = email.trim().toLowerCase();
    const cleanUsername = username.trim();

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      return res.status(400).json({ error: 'Định dạng email không hợp lệ' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'Mật khẩu phải từ 6 ký tự trở lên' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const hashedPin = await bcrypt.hash(strPin, 10);
    const user = await prisma.user.create({
      data: { username: cleanUsername, email: cleanEmail, password: hashedPassword, pin: hashedPin }
    });
    res.status(201).json({ id: user.id, username: user.username, email: user.email });
  } catch (error) {
    console.error("Register error:", error);
    res.status(400).json({ error: 'Registration failed: Email might already exist' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    const cleanEmail = email.trim().toLowerCase();
    const user = await prisma.user.findUnique({ where: { email: cleanEmail } });
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    const secret = process.env.JWT_SECRET || 'supersecretnfcwalletkey123';
    const token = jwt.sign({ userId: user.id }, secret, { expiresIn: '24h' });
    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        fullName: user.fullName || '',
        phone: user.phone || '',
        address: user.address || '',
        dob: user.dob || '',
        hasPin: Boolean(user.pin),
      },
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
