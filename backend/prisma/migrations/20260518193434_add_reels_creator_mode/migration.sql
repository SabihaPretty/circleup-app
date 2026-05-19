-- AlterTable
ALTER TABLE "User" ADD COLUMN     "accountMode" TEXT NOT NULL DEFAULT 'personal',
ADD COLUMN     "businessCategory" TEXT,
ADD COLUMN     "businessName" TEXT,
ADD COLUMN     "creatorBio" TEXT;

-- CreateTable
CREATE TABLE "Reel" (
    "id" SERIAL NOT NULL,
    "caption" TEXT NOT NULL,
    "mediaType" TEXT NOT NULL DEFAULT 'video',
    "mediaUrl" TEXT,
    "ageGroup" TEXT NOT NULL,
    "category" TEXT NOT NULL DEFAULT 'fun',
    "creatorMode" TEXT NOT NULL DEFAULT 'personal',
    "userId" INTEGER NOT NULL,
    "circleId" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Reel_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "Reel" ADD CONSTRAINT "Reel_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Reel" ADD CONSTRAINT "Reel_circleId_fkey" FOREIGN KEY ("circleId") REFERENCES "Circle"("id") ON DELETE SET NULL ON UPDATE CASCADE;
