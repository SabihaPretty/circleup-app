-- CreateTable
CREATE TABLE "Story" (
    "id" SERIAL NOT NULL,
    "caption" TEXT,
    "mediaType" TEXT NOT NULL DEFAULT 'text',
    "mediaUrl" TEXT,
    "ageGroup" TEXT NOT NULL,
    "userId" INTEGER NOT NULL,
    "circleId" INTEGER,
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Story_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "Story" ADD CONSTRAINT "Story_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Story" ADD CONSTRAINT "Story_circleId_fkey" FOREIGN KEY ("circleId") REFERENCES "Circle"("id") ON DELETE SET NULL ON UPDATE CASCADE;
