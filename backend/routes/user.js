const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Update password
router.post('/update-password', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { currentPassword, newPassword } = req.body;
    const cleanCurrentPassword = currentPassword != null ? String(currentPassword).trim() : '';
    const cleanNewPassword = newPassword != null ? String(newPassword).trim() : '';

    if (!cleanCurrentPassword || !cleanNewPassword) {
      return res.status(400).json({ error: 'Current password and new password are required' });
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (cleanCurrentPassword === cleanNewPassword) {
      return res.status(400).json({ error: 'Mật khẩu mới không được trùng với mật khẩu hiện tại' });
    }

    const isValid = await bcrypt.compare(cleanCurrentPassword, user.password);
    if (!isValid) {
      return res.status(400).json({ error: 'Mật khẩu hiện tại không chính xác' });
    }

    if (cleanNewPassword.length < 6) {
      return res.status(400).json({ error: 'Mật khẩu mới phải từ 6 ký tự trở lên (không tính khoảng trắng đầu/cuối)' });
    }

    const hashedPassword = await bcrypt.hash(cleanNewPassword, 10);
    await prisma.user.update({
      where: { id: user.id },
      data: { password: hashedPassword },
    });

    res.json({ message: 'Cập nhật mật khẩu thành công' });
  } catch (error) {
    console.error('Error updating password:', error);
    res.status(500).json({ error: 'Không thể cập nhật mật khẩu' });
  }
});

// Update PIN
router.post('/update-pin', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { currentPin, newPin } = req.body;
    const strNewPin = newPin != null ? String(newPin).trim() : '';
    const strCurrentPin = currentPin != null ? String(currentPin).trim() : '';

    if (!/^\d{6}$/.test(strNewPin)) {
      return res.status(400).json({ error: 'Mã PIN mới phải gồm đúng 6 chữ số' });
    }

    if (strCurrentPin && strCurrentPin === strNewPin) {
      return res.status(400).json({ error: 'Mã PIN mới không được trùng với Mã PIN hiện tại' });
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.pin && user.pin.trim() !== '') {
      if (!strCurrentPin) {
        return res.status(400).json({ error: 'Vui lòng nhập Mã PIN hiện tại' });
      }
      const isValidPin = await bcrypt.compare(strCurrentPin, user.pin);
      if (!isValidPin) {
        return res.status(400).json({ error: 'Mã PIN hiện tại không chính xác' });
      }
      const isSamePin = await bcrypt.compare(strNewPin, user.pin);
      if (isSamePin) {
        return res.status(400).json({ error: 'Mã PIN mới không được trùng với Mã PIN hiện tại' });
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

// Verify PIN for unlocking app or sensitive operations
router.post('/verify-pin', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { pin } = req.body;
    const strPin = pin != null ? String(pin).trim() : '';

    if (!/^\d{6}$/.test(strPin)) {
      return res.status(400).json({ error: 'Vui lòng nhập Mã PIN gồm đúng 6 chữ số' });
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.pin) {
      return res.status(400).json({ error: 'Tài khoản chưa cài đặt Mã PIN' });
    }

    const isValid = await bcrypt.compare(strPin, user.pin);
    if (!isValid) {
      return res.status(400).json({ error: 'Mã PIN bảo mật không chính xác' });
    }

    res.json({ success: true, message: 'Xác thực Mã PIN thành công' });
  } catch (error) {
    console.error('Error verifying pin:', error);
    res.status(500).json({ error: 'Lỗi hệ thống khi xác thực Mã PIN' });
  }
});

// Reset / Forgot PIN (via current account password)
router.post('/reset-pin', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { password, newPin } = req.body;
    const cleanPassword = password != null ? String(password).trim() : '';
    const strNewPin = newPin != null ? String(newPin).trim() : '';

    if (!cleanPassword || !strNewPin) {
      return res.status(400).json({ error: 'Vui lòng nhập mật khẩu tài khoản và Mã PIN mới' });
    }
    if (!/^\d{6}$/.test(strNewPin)) {
      return res.status(400).json({ error: 'Mã PIN mới phải gồm đúng 6 chữ số' });
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const isValidPassword = await bcrypt.compare(cleanPassword, user.password);
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
    const userId = req.user.userId;
    const user = await prisma.user.findUnique({ where: { id: userId } });

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
    const userId = req.user.userId;
    const { fullName, phone, address, dob, username } = req.body;

    const user = await prisma.user.findUnique({ where: { id: userId } });
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
