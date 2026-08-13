const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Update password
router.post('/update-password', async (req, res) => {
  try {
    const { currentPassword, newPassword, userId } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current password and new password are required' });
    }

    let user;
    const parsedUserId = parseInt(userId);
    if (parsedUserId && !isNaN(parsedUserId)) {
      user = await prisma.user.findUnique({ where: { id: parsedUserId } });
    } else {
      user = await prisma.user.findFirst();
    }
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const isValid = await bcrypt.compare(currentPassword, user.password);
    if (!isValid) {
      return res.status(400).json({ error: 'Incorrect current password' });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({
      where: { id: user.id },
      data: { password: hashedPassword },
    });

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    console.error('Error updating password:', error);
    res.status(500).json({ error: 'Failed to update password' });
  }
});

// Update PIN
router.post('/update-pin', async (req, res) => {
  try {
    const { currentPin, newPin, userId } = req.body;
    const strNewPin = newPin != null ? String(newPin).trim() : '';
    const strCurrentPin = currentPin != null ? String(currentPin).trim() : '';

    if (!strNewPin || strNewPin.length < 4 || strNewPin.length > 6) {
      return res.status(400).json({ error: 'Mã PIN mới phải từ 4-6 chữ số' });
    }

    let user;
    const parsedUserId = parseInt(userId);
    if (parsedUserId && !isNaN(parsedUserId)) {
      user = await prisma.user.findUnique({ where: { id: parsedUserId } });
    } else {
      user = await prisma.user.findFirst();
    }
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.pin) {
      if (!strCurrentPin) {
        return res.status(400).json({ error: 'Vui lòng nhập Mã PIN hiện tại' });
      }
      const isValidPin = await bcrypt.compare(strCurrentPin, user.pin);
      if (!isValidPin) {
        return res.status(400).json({ error: 'Mã PIN hiện tại không chính xác' });
      }
    }

    const hashedPin = await bcrypt.hash(strNewPin, 10);
    await prisma.user.update({
      where: { id: user.id },
      data: { pin: hashedPin },
    });

    res.json({ message: 'Cập nhật Mã PIN thành công' });
  } catch (error) {
    console.error('Error updating pin:', error);
    res.status(500).json({ error: 'Không thể cập nhật Mã PIN' });
  }
});

// Reset / Forgot PIN (via current account password)
router.post('/reset-pin', async (req, res) => {
  try {
    const { password, newPin, userId } = req.body;
    const strNewPin = newPin != null ? String(newPin).trim() : '';

    if (!password || !strNewPin) {
      return res.status(400).json({ error: 'Vui lòng nhập mật khẩu tài khoản và Mã PIN mới' });
    }
    if (strNewPin.length < 4 || strNewPin.length > 6) {
      return res.status(400).json({ error: 'Mã PIN mới phải từ 4-6 chữ số' });
    }

    let user;
    const parsedUserId = parseInt(userId);
    if (parsedUserId && !isNaN(parsedUserId)) {
      user = await prisma.user.findUnique({ where: { id: parsedUserId } });
    } else {
      user = await prisma.user.findFirst();
    }
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(400).json({ error: 'Mật khẩu tài khoản không đúng' });
    }

    const hashedPin = await bcrypt.hash(strNewPin, 10);
    await prisma.user.update({
      where: { id: user.id },
      data: { pin: hashedPin },
    });

    res.json({ message: 'Đặt lại Mã PIN thành công' });
  } catch (error) {
    console.error('Error resetting pin:', error);
    res.status(500).json({ error: 'Không thể đặt lại Mã PIN' });
  }
});

// Get User Profile Info
router.get('/profile', async (req, res) => {
  try {
    const { userId } = req.query;
    let user;
    const parsedUserId = parseInt(userId);
    if (parsedUserId && !isNaN(parsedUserId)) {
      user = await prisma.user.findUnique({ where: { id: parsedUserId } });
    } else {
      user = await prisma.user.findFirst();
    }

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      id: user.id,
      username: user.username,
      email: user.email,
      fullName: user.fullName || '',
      phone: user.phone || '',
      address: user.address || '',
      dob: user.dob || '',
      hasPin: Boolean(user.pin),
    });
  } catch (error) {
    console.error('Error fetching profile:', error);
    res.status(500).json({ error: 'Failed to fetch user profile' });
  }
});

// Update User Profile Info
router.put('/update-profile', async (req, res) => {
  try {
    const { userId, fullName, phone, address, dob, username } = req.body;
    let user;
    const parsedUserId = parseInt(userId);
    if (parsedUserId && !isNaN(parsedUserId)) {
      user = await prisma.user.findUnique({ where: { id: parsedUserId } });
    } else {
      user = await prisma.user.findFirst();
    }

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const updatedUser = await prisma.user.update({
      where: { id: user.id },
      data: {
        username: username !== undefined ? username : user.username,
        fullName: fullName !== undefined ? fullName : user.fullName,
        phone: phone !== undefined ? phone : user.phone,
        address: address !== undefined ? address : user.address,
        dob: dob !== undefined ? dob : user.dob,
      },
    });

    res.json({
      message: 'Cập nhật thông tin thành công',
      user: {
        id: updatedUser.id,
        username: updatedUser.username,
        email: updatedUser.email,
        fullName: updatedUser.fullName || '',
        phone: updatedUser.phone || '',
        address: updatedUser.address || '',
        dob: updatedUser.dob || '',
      },
    });
  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({ error: 'Failed to update user profile' });
  }
});

module.exports = router;
