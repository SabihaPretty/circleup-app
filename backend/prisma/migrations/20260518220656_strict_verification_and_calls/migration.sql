-- AlterTable
ALTER TABLE "VerificationCode" ADD COLUMN     "verifiedAt" TIMESTAMP(3),
ADD COLUMN     "verifiedToken" TEXT;

-- CreateIndex
CREATE INDEX "VerificationCode_verifiedToken_idx" ON "VerificationCode"("verifiedToken");
