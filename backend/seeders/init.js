const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function seed() {
  try {
    const hashedPassword = await bcrypt.hash('password123', 10);
    const user = await prisma.user.upsert({
      where: { email: 'test@example.com' },
      update: {},
      create: {
        username: 'Test User',
        email: 'test@example.com',
        password: hashedPassword,
      },
    });
    
    // Seed a default card for the test user
    const existingCard = await prisma.card.findFirst({ where: { userId: user.id } });
    if (!existingCard) {
      await prisma.card.create({
        data: {
          userId: user.id,
          cardName: 'Default NFC Card',
          cardNumber: '1234-5678-9012-3456',
          isDefault: true
        }
      });
    }

    console.log('Seeding completed: test@example.com and default card created.');
  } catch (error) {
    console.error('Seeding failed:', error);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  seed();
}

module.exports = { seed };
