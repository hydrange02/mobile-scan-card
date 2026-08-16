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

function validateBankCardNumber(cardNumber) {
  const clean = cardNumber ? String(cardNumber).replace(/\s+/g, '') : '';
  if (!/^\d{15,19}$/.test(clean)) {
    return 'Số thẻ ngân hàng không hợp lệ (phải gồm từ 15 đến 19 chữ số theo chuẩn quốc tế)';
  }

  const isValidBin =
    clean.startsWith('4') || // Visa
    /^(5[1-5]|2[2-7])/.test(clean) || // Mastercard
    clean.startsWith('9704') || // Napas
    /^(34|37)/.test(clean) || // Amex
    /^35(2[89]|[3-8][0-9])/.test(clean) || // JCB
    /^(62|81)/.test(clean); // UnionPay

  if (!isValidBin) {
    return 'Đầu số thẻ (BIN) không hợp lệ (Visa bắt đầu bằng 4, Mastercard bằng 5/2, Napas bằng 9704, Amex 34/37, JCB 35)';
  }

  return null;
}

function validateCardInputs({ cardName, cardHolder, expiryDate, phone }) {
  if (cardName !== undefined && cardName !== null && String(cardName).trim().length > 0) {
    const cleanName = String(cardName).trim();
    if (cleanName.length < 2 || cleanName.length > 50) {
      return 'Tên thẻ phải gồm từ 2 đến 50 ký tự';
    }
    if (/[<>{}[\]\\\/@#$%^&*()=~|]/.test(cleanName)) {
      return 'Tên thẻ không được chứa các ký tự đặc biệt nguy hiểm';
    }
  }

  if (cardHolder !== undefined && cardHolder !== null && String(cardHolder).trim().length > 0) {
    const cleanHolder = String(cardHolder).trim();
    if (cleanHolder.length < 2 || cleanHolder.length > 50) {
      return 'Tên chủ thẻ phải gồm từ 2 đến 50 ký tự';
    }
    if (!/^[A-Za-z\s.\-]+$/.test(cleanHolder)) {
      return 'Tên chủ thẻ chỉ được gồm chữ cái không dấu (A-Z) và khoảng trắng (Ví dụ: NGUYEN VAN A)';
    }
  }

  if (expiryDate !== undefined && expiryDate !== null && String(expiryDate).trim().length > 0) {
    const cleanExpiry = String(expiryDate).trim();
    if (!/^(0[1-9]|1[0-2])\/?([0-9]{2})$/.test(cleanExpiry)) {
      return 'Ngày hết hạn thẻ phải theo định dạng MM/YY (ví dụ: 12/28)';
    }
  }

  if (phone !== undefined && phone !== null && String(phone).trim().length > 0) {
    const cleanPhone = String(phone).trim();
    if (!/^(\+84|0)[35789][0-9]{8}$/.test(cleanPhone)) {
      return 'Số điện thoại liên kết không hợp lệ (phải gồm 10 chữ số bắt đầu bằng 03, 05, 07, 08, 09 hoặc +84)';
    }
  }

  return null;
}

// Create a new card for authenticated user
router.post('/', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { cardName, cardNumber, cardHolder, expiryDate, phone, balance } = req.body;

    const validationErr = validateCardInputs({ cardName, cardHolder, expiryDate, phone });
    if (validationErr) {
      return res.status(400).json({ error: validationErr });
    }

    const rawCardNumber = cardNumber ? String(cardNumber).replace(/\s+/g, '') : '4111222233339999';
    const cardNumErr = validateBankCardNumber(rawCardNumber);
    if (cardNumErr) {
      return res.status(400).json({ error: cardNumErr });
    }

    // Auto-generate default card name with last 4 digits if not provided
    const last4 = rawCardNumber.substring(rawCardNumber.length - 4);
    let defaultCardName = `Thẻ NFC (${last4})`;
    if (rawCardNumber.startsWith('4')) {
      defaultCardName = `Thẻ Visa (${last4})`;
    } else if (/^(5[1-5]|2[2-7])/.test(rawCardNumber)) {
      defaultCardName = `Thẻ Mastercard (${last4})`;
    } else if (rawCardNumber.startsWith('9704')) {
      defaultCardName = `Thẻ Napas (${last4})`;
    } else if (/^(34|37)/.test(rawCardNumber)) {
      defaultCardName = `Thẻ Amex (${last4})`;
    } else if (/^35/.test(rawCardNumber)) {
      defaultCardName = `Thẻ JCB (${last4})`;
    }

    const finalCardName = (cardName && String(cardName).trim().length > 0)
      ? String(cardName).trim()
      : defaultCardName;

    const parsedBalance = balance !== undefined ? parseFloat(balance) : 0.0;
    const safeBalance = isNaN(parsedBalance) || parsedBalance < 0 ? 0.0 : Math.round(parsedBalance * 100) / 100;

    const card = await prisma.$transaction(async (txPrisma) => {
      const existingCount = await txPrisma.card.count({ where: { userId } });
      const isFirstCard = existingCount === 0;

      return await txPrisma.card.create({
        data: {
          userId,
          cardName: finalCardName,
          cardNumber: rawCardNumber,
          cardHolder: cardHolder && String(cardHolder).trim().length > 0 ? String(cardHolder).trim().toUpperCase() : 'CHỦ THẺ NFC',
          expiryDate: expiryDate && String(expiryDate).trim().length > 0 ? String(expiryDate).trim() : '12/28',
          phone: phone ? String(phone).trim() : '',
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

    const validationErr = validateCardInputs({ cardName, cardHolder, expiryDate, phone });
    if (validationErr) {
      return res.status(400).json({ error: validationErr });
    }

    const updatedCard = await prisma.card.update({
      where: { id: cardId },
      data: {
        ...(cardName !== undefined && { cardName: cardName.trim() }),
        ...(cardHolder !== undefined && { cardHolder: cardHolder.trim().toUpperCase() }),
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
