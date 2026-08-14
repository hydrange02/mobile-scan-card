const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get all transactions for authenticated user
router.get('/', async (req, res) => {
  try {
    const userId = req.user.userId;

    const transactions = await prisma.transaction.findMany({
      where: { userId },
      include: { card: true },
      orderBy: { createdAt: 'desc' },
    });

    const formatted = transactions.map(tx => ({
      id: `TX${tx.id}`,
      dbId: tx.id,
      title: tx.title,
      category: tx.category,
      date: tx.createdAt.toISOString(),
      cardName: tx.card ? tx.card.cardName : 'NFC Direct',
      cardType: tx.card 
        ? (tx.card.cardName.toLowerCase().includes('visa') ? 'Visa' : tx.card.cardName.toLowerCase().includes('mastercard') ? 'Mastercard' : 'NFC')
        : 'NFC',
      amount: tx.amount,
      isExpense: tx.isExpense,
      status: tx.status,
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Error fetching transactions:', error);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

// Create new transaction
router.post('/', async (req, res) => {
  try {
    const userId = req.user.userId;
    let { cardId, title, category, amount, isExpense, status } = req.body;

    let targetCardId = cardId ? parseInt(cardId) : null;
    if (!targetCardId) {
      // Look up default card for user if no cardId was provided
      const defaultCard = await prisma.card.findFirst({
        where: { userId, isDefault: true }
      });
      if (defaultCard) {
        targetCardId = defaultCard.id;
      }
    }

    const txAmount = parseFloat(amount) || 0.0;
    const isExp = isExpense !== undefined ? Boolean(isExpense) : true;
    const txStatus = status || 'Success';

    // Verify card ownership and balance if card is attached
    let targetCard = null;
    if (targetCardId) {
      targetCard = await prisma.card.findFirst({ where: { id: targetCardId, userId } });
      if (!targetCard) {
        return res.status(404).json({ error: 'Thẻ thanh toán không tồn tại hoặc không hợp lệ' });
      }

      // Check balance for expenses
      if (isExp && txStatus === 'Success' && targetCard.balance < txAmount) {
        return res.status(400).json({ error: 'Số dư thẻ không đủ để thực hiện giao dịch' });
      }
    }

    // Atomic DB transaction for data integrity
    const result = await prisma.$transaction(async (txPrisma) => {
      // 1. Create transaction record
      const newTx = await txPrisma.transaction.create({
        data: {
          userId,
          cardId: targetCardId,
          title: title || 'Thanh toán NFC 1-Chạm',
          category: category || 'Giao dịch NFC',
          amount: txAmount,
          isExpense: isExp,
          status: txStatus,
        },
      });

      // 2. Update card balance if transaction is successful
      if (targetCardId && txStatus === 'Success' && targetCard) {
        const rawBalance = isExp ? (targetCard.balance - txAmount) : (targetCard.balance + txAmount);
        const newBalance = Math.round(rawBalance * 100) / 100;
        await txPrisma.card.update({
          where: { id: targetCardId },
          data: { balance: newBalance }
        });
      }

      return newTx;
    });

    res.status(201).json(result);
  } catch (error) {
    console.error('Error creating transaction:', error);
    res.status(400).json({ error: 'Failed to create transaction', details: error.message });
  }
});

module.exports = router;
