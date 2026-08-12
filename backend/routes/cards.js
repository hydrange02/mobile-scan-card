const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get all cards (returns empty list [] if user has 0 cards, no auto-creation)
router.get('/', async (req, res) => {
  try {
    const cards = await prisma.card.findMany({
      orderBy: { createdAt: 'desc' },
    });
    res.json(cards);
  } catch (error) {
    console.error("Error fetching cards:", error);
    res.status(500).json({ error: 'Failed to fetch cards' });
  }
});

// Create a new card
router.post('/', async (req, res) => {
  try {
    let { userId, cardName, cardNumber } = req.body;
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

    // Check if this is the first card; if so, make it default
    const existingCount = await prisma.card.count({ where: { userId: parsedUserId } });
    const isFirstCard = existingCount === 0;

    const card = await prisma.card.create({
      data: {
        userId: parsedUserId,
        cardName: cardName || 'Thẻ NFC Mới',
        cardNumber: cardNumber || '4111222233339999',
        isDefault: isFirstCard
      }
    });
    res.status(201).json(card);
  } catch (error) {
    console.error("Error creating card:", error);
    res.status(400).json({ error: 'Failed to create card', details: error.message });
  }
});

// Set card as default
router.put('/:id/default', async (req, res) => {
  try {
    const cardId = parseInt(req.params.id);
    const targetCard = await prisma.card.findUnique({ where: { id: cardId } });
    if (!targetCard) {
      return res.status(404).json({ error: 'Card not found' });
    }

    // Unset current default cards for user
    await prisma.card.updateMany({
      where: { userId: targetCard.userId },
      data: { isDefault: false }
    });

    // Set target card as default
    const updated = await prisma.card.update({
      where: { id: cardId },
      data: { isDefault: true }
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
    const cardId = parseInt(req.params.id);
    const deletedCard = await prisma.card.findUnique({ where: { id: cardId } });

    await prisma.card.delete({ where: { id: cardId } });

    // If deleted card was default, set first remaining card as default (if any remain)
    if (deletedCard && deletedCard.isDefault) {
      const firstCard = await prisma.card.findFirst({ where: { userId: deletedCard.userId } });
      if (firstCard) {
        await prisma.card.update({
          where: { id: firstCard.id },
          data: { isDefault: true }
        });
      }
    }

    res.status(204).send();
  } catch (error) {
    res.status(400).json({ error: 'Failed to delete card' });
  }
});

// Delete all cards endpoint (utility to clear dummy cards)
router.delete('/', async (req, res) => {
  try {
    await prisma.card.deleteMany();
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: 'Failed to clear cards' });
  }
});

module.exports = router;
