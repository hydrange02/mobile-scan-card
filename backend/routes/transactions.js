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
      createdAt: tx.createdAt.toISOString(),
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

    const txAmount = parseFloat(amount);
    if (isNaN(txAmount) || txAmount <= 0) {
      return res.status(400).json({ error: 'Số tiền giao dịch phải lớn hơn 0' });
    }
    const isExp = isExpense !== undefined ? Boolean(isExpense) : true;
    const txStatus = status || 'Success';

function isCardExpired(expiryDate) {
  if (!expiryDate) return false;
  const parts = String(expiryDate).trim().split('/');
  if (parts.length !== 2) return false;
  const expMonth = parseInt(parts[0], 10);
  const expYearTwoDigits = parseInt(parts[1], 10);
  if (isNaN(expMonth) || isNaN(expYearTwoDigits)) return false;

  const fullExpYear = 2000 + expYearTwoDigits;
  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth() + 1;

  if (fullExpYear < currentYear) return true;
  if (fullExpYear === currentYear && expMonth < currentMonth) return true;
  return false;
}

    // Atomic DB transaction for data integrity and race condition prevention
    const result = await prisma.$transaction(async (txPrisma) => {
      let targetCard = null;
      if (targetCardId) {
        targetCard = await txPrisma.card.findFirst({ where: { id: targetCardId, userId } });
        if (!targetCard) {
          throw new Error('Thẻ thanh toán không tồn tại hoặc không hợp lệ');
        }

        if (isCardExpired(targetCard.expiryDate)) {
          throw new Error('Thẻ này đã hết hạn sử dụng. Vui lòng gia hạn hoặc chọn thẻ khác!');
        }

        // Check balance for expenses inside transaction with 2-decimal precision
        const roundedBalance = Math.round(targetCard.balance * 100);
        const roundedAmount = Math.round(txAmount * 100);
        if (isExp && txStatus === 'Success' && roundedBalance < roundedAmount) {
          throw new Error('Số dư thẻ không đủ để thực hiện giao dịch');
        }
      } else if (isExp) {
        throw new Error('Vui lòng thêm hoặc chọn thẻ thanh toán trước khi thực hiện giao dịch');
      }

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
    res.status(400).json({ error: error.message || 'Failed to create transaction' });
  }
});

// Clear all transactions for authenticated user
router.delete('/', async (req, res) => {
  try {
    const userId = req.user.userId;
    await prisma.transaction.deleteMany({
      where: { userId }
    });
    res.json({ message: 'Successfully cleared all transaction history' });
  } catch (error) {
    console.error('Error clearing transactions:', error);
    res.status(500).json({ error: 'Failed to clear transaction history' });
  }
});

module.exports = router;
