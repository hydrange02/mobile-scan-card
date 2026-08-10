const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Card Model Helper
 * Prisma handles the schema definition in schema.prisma.
 * This file provides utility functions for Card operations.
 */
const Card = {
  findAllByUserId: async (userId) => {
    return await prisma.card.findMany({ where: { userId } });
  },
  create: async (data) => {
    return await prisma.card.create({ data });
  },
  delete: async (id) => {
    return await prisma.card.delete({ where: { id } });
  },
  update: async (id, data) => {
    return await prisma.card.update({ where: { id }, data });
  }
};

module.exports = Card;
