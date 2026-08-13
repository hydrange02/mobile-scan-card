const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get all transactions (optionally filtered by userId query parameter)
router.get('/', async (req, res) => {
  try {
    const { userId } = req.query;
    const parsedUserId = parseInt(userId);
    const where = (parsedUserId && !isNaN(parsedUserId)) ? { userId: parsedUserId } : {};

    const transactions = await prisma.transaction.findMany({
      where,
      include: { card: true },
      orderBy: { createdAt: 'desc' },
    });

    const formatted = transactions.map(tx => ({
      id: `TX${tx.id}`,
      dbId: tx.id,
      title: tx.title,
      category: tx.category,
      date: tx.createdAt.toISOString().replace('T', ' ').substring(0, 16),
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
    let { userId, cardId, title, category, amount, isExpense, status } = req.body;
    let parsedUserId = parseInt(userId);
    if (!parsedUserId || isNaN(parsedUserId)) {
      let user = await prisma.user.findFirst();
      if (!user) {
        user = await prisma.user.create({
          data: { username: 'defaultuser', email: 'user@example.com', password: 'password123' }
        });
      }
      parsedUserId = user.id;
    }

    let targetCardId = cardId ? parseInt(cardId) : null;
    if (!targetCardId) {
      // Look up default card for user if no cardId was provided
      const defaultCard = await prisma.card.findFirst({
        where: { userId: parsedUserId, isDefault: true }
      });
      if (defaultCard) {
        targetCardId = defaultCard.id;
      }
    }

    const txAmount = parseFloat(amount) || 0.0;
    const isExp = isExpense !== undefined ? Boolean(isExpense) : true;
    const txStatus = status || 'Success';

    // Create transaction record
    const tx = await prisma.transaction.create({
      data: {
        userId: parsedUserId,
        cardId: targetCardId,
        title: title || 'Thanh toán NFC 1-Chạm',
        category: category || 'Giao dịch NFC',
        amount: txAmount,
        isExpense: isExp,
        status: txStatus,
      },
    });

    // Automatically update Card Balance if transaction was Successful and card exists
    if (targetCardId && txStatus === 'Success') {
      const card = await prisma.card.findUnique({ where: { id: targetCardId } });
      if (card) {
        let newBalance = isExp ? (card.balance - txAmount) : (card.balance + txAmount);
        if (newBalance < 0) newBalance = 0.0; // Ensure balance doesn't drop below 0
        await prisma.card.update({
          where: { id: targetCardId },
          data: { balance: newBalance }
        });
      }
    }

    res.status(201).json(tx);
  } catch (error) {
    console.error('Error creating transaction:', error);
    res.status(400).json({ error: 'Failed to create transaction' });
  }
});

module.exports = router;
