-- CreateEnum
CREATE TYPE "BankAccountType" AS ENUM ('checking', 'savings', 'payment', 'investment');

-- CreateEnum
CREATE TYPE "TransactionType" AS ENUM ('income', 'expense');

-- CreateEnum
CREATE TYPE "TransactionStatus" AS ENUM ('pending', 'completed', 'cancelled');

-- CreateEnum
CREATE TYPE "TransactionCategory" AS ENUM ('salary', 'freelance', 'investment', 'food', 'housing', 'transportation', 'health', 'education', 'entertainment', 'shopping', 'bills', 'taxes', 'other');

-- CreateEnum
CREATE TYPE "BillCategory" AS ENUM ('housing', 'utilities', 'food', 'transport', 'health', 'education', 'subscriptions', 'taxes', 'other');

-- CreateEnum
CREATE TYPE "BillStatus" AS ENUM ('pending', 'paid', 'cancelled');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BankAccount" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "bankName" TEXT NOT NULL,
    "nickname" TEXT NOT NULL,
    "type" "BankAccountType" NOT NULL,
    "initialBalance" DECIMAL(15,2) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BankAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FinancialTransaction" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "amount" DECIMAL(15,2) NOT NULL,
    "type" "TransactionType" NOT NULL,
    "category" "TransactionCategory" NOT NULL,
    "accountId" TEXT NOT NULL,
    "transactionDate" TIMESTAMP(3) NOT NULL,
    "dueDate" TIMESTAMP(3) NOT NULL,
    "status" "TransactionStatus" NOT NULL DEFAULT 'pending',
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FinancialTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PayableBill" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "amount" DECIMAL(15,2) NOT NULL,
    "category" "BillCategory" NOT NULL,
    "dueDate" TIMESTAMP(3) NOT NULL,
    "discountDeadline" TIMESTAMP(3),
    "discountAmount" DECIMAL(15,2),
    "status" "BillStatus" NOT NULL DEFAULT 'pending',
    "paidAt" TIMESTAMP(3),
    "accountId" TEXT,
    "linkedPendingTransactionId" TEXT,
    "linkedTransactionId" TEXT,
    "notes" TEXT NOT NULL DEFAULT '',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PayableBill_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "BankAccount_userId_idx" ON "BankAccount"("userId");

-- CreateIndex
CREATE INDEX "FinancialTransaction_userId_idx" ON "FinancialTransaction"("userId");

-- CreateIndex
CREATE INDEX "FinancialTransaction_accountId_idx" ON "FinancialTransaction"("accountId");

-- CreateIndex
CREATE INDEX "FinancialTransaction_userId_transactionDate_idx" ON "FinancialTransaction"("userId", "transactionDate");

-- CreateIndex
CREATE INDEX "FinancialTransaction_userId_status_idx" ON "FinancialTransaction"("userId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "PayableBill_linkedPendingTransactionId_key" ON "PayableBill"("linkedPendingTransactionId");

-- CreateIndex
CREATE UNIQUE INDEX "PayableBill_linkedTransactionId_key" ON "PayableBill"("linkedTransactionId");

-- CreateIndex
CREATE INDEX "PayableBill_userId_idx" ON "PayableBill"("userId");

-- CreateIndex
CREATE INDEX "PayableBill_userId_dueDate_idx" ON "PayableBill"("userId", "dueDate");

-- CreateIndex
CREATE INDEX "PayableBill_userId_status_idx" ON "PayableBill"("userId", "status");

-- CreateIndex
CREATE INDEX "PayableBill_accountId_idx" ON "PayableBill"("accountId");

-- AddForeignKey
ALTER TABLE "BankAccount" ADD CONSTRAINT "BankAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialTransaction" ADD CONSTRAINT "FinancialTransaction_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialTransaction" ADD CONSTRAINT "FinancialTransaction_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "BankAccount"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PayableBill" ADD CONSTRAINT "PayableBill_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PayableBill" ADD CONSTRAINT "PayableBill_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "BankAccount"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PayableBill" ADD CONSTRAINT "PayableBill_linkedPendingTransactionId_fkey" FOREIGN KEY ("linkedPendingTransactionId") REFERENCES "FinancialTransaction"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PayableBill" ADD CONSTRAINT "PayableBill_linkedTransactionId_fkey" FOREIGN KEY ("linkedTransactionId") REFERENCES "FinancialTransaction"("id") ON DELETE SET NULL ON UPDATE CASCADE;
