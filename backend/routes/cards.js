const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get all cards for authenticated user
router.get('/', async (req, res) => {
  try {
    const userId = req.user.userId;
    const cards = await prisma.card.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    res.json(cards);
  } catch (error) {
    console.error("Error fetching cards:", error);
    res.status(500).json({ error: 'Failed to fetch cards' });
  }
});

// Create a new card for authenticated user
router.post('/', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { cardName, cardNumber, cardHolder, expiryDate, phone, balance } = req.body;

    const rawCardNumber = cardNumber ? String(cardNumber).replace(/\s+/g, '') : '4111222233339999';
    if (!/^\d{12,19}$/.test(rawCardNumber)) {
      return res.status(400).json({ error: 'Số thẻ ngân hàng không hợp lệ (phải từ 12 đến 19 chữ số)' });
    }

    const parsedBalance = balance !== undefined ? parseFloat(balance) : 0.0;
    const safeBalance = isNaN(parsedBalance) || parsedBalance < 0 ? 0.0 : Math.round(parsedBalance * 100) / 100;

    const card = await prisma.$transaction(async (txPrisma) => {
      const existingCount = await txPrisma.card.count({ where: { userId } });
      const isFirstCard = existingCount === 0;

      return await txPrisma.card.create({
        data: {
          userId,
          cardName: cardName || 'Thẻ NFC Mới',
          cardNumber: rawCardNumber,
          cardHolder: cardHolder || 'Chủ Thẻ NFC',
          expiryDate: expiryDate || '12/28',
          phone: phone || '',
          balance: safeBalance,
          isDefault: isFirstCard
        }
      });
    });
    res.status(201).json(card);
  } catch (error) {
    console.error("Error creating card:", error);
    res.status(400).json({ error: 'Failed to create card', details: error.message });
  }
});

// Get single card detail by ID (must belong to authenticated user)
router.get('/:id', async (req, res) => {
  try {
    const userId = req.user.userId;
    const cardId = parseInt(req.params.id);
    const card = await prisma.card.findFirst({
      where: { id: cardId, userId },
      include: { transactions: { orderBy: { createdAt: 'desc' } } }
    });
    if (!card) {
      return res.status(404).json({ error: 'Card not found or access denied' });
    }
    res.json(card);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch card details' });
  }
});

// Update card info by ID
router.put('/:id', async (req, res) => {
  try {
    const userId = req.user.userId;
    const cardId = parseInt(req.params.id);
    const { cardName, cardHolder, expiryDate, phone } = req.body;

    const card = await prisma.card.findFirst({ where: { id: cardId, userId } });
    if (!card) {
      return res.status(404).json({ error: 'Card not found or access denied' });
    }

    if (expiryDate !== undefined && expiryDate.toString().trim().length > 0) {
      const cleanExpiry = expiryDate.toString().trim();
      if (!/^(0[1-9]|1[0-2])\/?([0-9]{2})$/.test(cleanExpiry)) {
        return res.status(400).json({ error: 'Ngày hết hạn thẻ phải theo định dạng MM/YY (ví dụ: 12/28)' });
      }
    }

    const updatedCard = await prisma.card.update({
      where: { id: cardId },
      data: {
        ...(cardName !== undefined && { cardName: cardName.trim() }),
        ...(cardHolder !== undefined && { cardHolder: cardHolder.trim() }),
        ...(expiryDate !== undefined && { expiryDate: expiryDate.trim() }),
        ...(phone !== undefined && { phone: phone.trim() }),
      }
    });

    res.json(updatedCard);
  } catch (error) {
    res.status(400).json({ error: 'Failed to update card' });
  }
});

// Set card as default
router.put('/:id/default', async (req, res) => {
  try {
    const userId = req.user.userId;
    const cardId = parseInt(req.params.id);
    const targetCard = await prisma.card.findFirst({ where: { id: cardId, userId } });
    if (!targetCard) {
      return res.status(404).json({ error: 'Card not found or access denied' });
    }

    const updated = await prisma.$transaction(async (txPrisma) => {
      // 1. Unset current default cards for user
      await txPrisma.card.updateMany({
        where: { userId },
        data: { isDefault: false }
      });

      // 2. Set target card as default
      return await txPrisma.card.update({
        where: { id: cardId },
        data: { isDefault: true }
      });
    });

    res.json(updated);
  } catch (error) {
    console.error("Error setting default card:", error);
    res.status(500).json({ error: 'Failed to set default card' });
  }
});

// Delete card by ID
router.delete('/:id', async (req, res) => {
  try {
    const userId = req.user.userId;
    const cardId = parseInt(req.params.id);
    const targetCard = await prisma.card.findFirst({ where: { id: cardId, userId } });

    if (!targetCard) {
      return res.status(404).json({ error: 'Card not found or access denied' });
    }

    await prisma.$transaction(async (txPrisma) => {
      await txPrisma.card.delete({ where: { id: cardId } });

      // If deleted card was default, set first remaining card as default (if any remain)
      if (targetCard.isDefault) {
        const firstCard = await txPrisma.card.findFirst({ where: { userId } });
        if (firstCard) {
          await txPrisma.card.update({
            where: { id: firstCard.id },
            data: { isDefault: true }
          });
        }
      }
    });

    res.status(204).send();
  } catch (error) {
    res.status(400).json({ error: 'Failed to delete card' });
  }
});

module.exports = router;
