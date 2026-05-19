-- AlterTable
ALTER TABLE "User" ADD COLUMN     "preferredVerifyMode" TEXT NOT NULL DEFAULT 'email',
ADD COLUMN     "twoStepEnabled" BOOLEAN NOT NULL DEFAULT false;
