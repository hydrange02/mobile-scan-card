const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const { PrismaClient } = require('@prisma/client');

dotenv.config();

const app = express();
const prisma = new PrismaClient();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Import Routes
const authRoutes = require('./routes/auth');
const cardRoutes = require('./routes/cards');
const userRoutes = require('./routes/user');
const transactionRoutes = require('./routes/transactions');

// Import Middleware
const { authenticateToken } = require('./middleware/auth');

// Register Routes
app.use('/api/auth', authRoutes);
app.use('/api/cards', authenticateToken, cardRoutes);
app.use('/api/user', authenticateToken, userRoutes);
app.use('/api/transactions', authenticateToken, transactionRoutes);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date() });
});

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = { app, prisma };
