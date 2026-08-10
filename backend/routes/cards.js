const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get all cards
router.get('/', async (req, res) => {
  try {
    let cards = await prisma.card.findMany();
    if (cards.length === 0) {
      let user = await prisma.user.findFirst();
      if (!user) {
        user = await prisma.user.create({
          data: { username: 'defaultuser', email: 'user@example.com', password: 'password123' }
        });
      }
      const defaultCard = await prisma.card.create({
        data: {
          userId: user.id,
          cardName: 'Visa Debit Default',
          cardNumber: '4111222233339999',
          isDefault: true
        }
      });
      cards = [defaultCard];
    }
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
    const card = await prisma.card.create({
      data: {
        userId: parsedUserId,
        cardName: cardName || 'NFC Scanned Card',
        cardNumber: cardNumber || '4111222233339999',
        isDefault: false
      }
    });
    res.status(201).json(card);
  } catch (error) {
    console.error("Error creating card:", error);
    res.status(400).json({ error: 'Failed to create card', details: error.message });
  }
});

// Delete card by ID
router.delete('/:id', async (req, res) => {
  try {
    await prisma.card.delete({ where: { id: parseInt(req.params.id) } });
    res.status(204).send();
  } catch (error) {
    res.status(400).json({ error: 'Failed to delete card' });
  }
});

module.exports = router;
