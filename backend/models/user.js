const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * User Model Helper
 * Prisma handles the schema definition in schema.prisma.
 * This file provides utility functions for User operations.
 */
const User = {
  findByEmail: async (email) => {
    return await prisma.user.findUnique({ where: { email } });
  },
  create: async (data) => {
    return await prisma.user.create({ data });
  },
  findById: async (id) => {
    return await prisma.user.findUnique({ where: { id } });
  }
};

module.exports = User;
