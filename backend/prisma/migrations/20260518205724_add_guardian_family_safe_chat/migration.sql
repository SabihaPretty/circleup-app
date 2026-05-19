-- CreateTable
CREATE TABLE "GuardianInvite" (
    "id" SERIAL NOT NULL,
    "code" TEXT NOT NULL,
    "guardianId" INTEGER NOT NULL,
    "relationType" TEXT NOT NULL DEFAULT 'parent',
    "status" TEXT NOT NULL DEFAULT 'active',
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GuardianInvite_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GuardianLink" (
    "id" SERIAL NOT NULL,
    "childId" INTEGER NOT NULL,
    "guardianId" INTEGER NOT NULL,
    "relationType" TEXT NOT NULL DEFAULT 'parent',
    "status" TEXT NOT NULL DEFAULT 'accepted',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GuardianLink_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "GuardianInvite_code_key" ON "GuardianInvite"("code");

-- CreateIndex
CREATE UNIQUE INDEX "GuardianLink_childId_guardianId_key" ON "GuardianLink"("childId", "guardianId");

-- AddForeignKey
ALTER TABLE "GuardianInvite" ADD CONSTRAINT "GuardianInvite_guardianId_fkey" FOREIGN KEY ("guardianId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GuardianLink" ADD CONSTRAINT "GuardianLink_childId_fkey" FOREIGN KEY ("childId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GuardianLink" ADD CONSTRAINT "GuardianLink_guardianId_fkey" FOREIGN KEY ("guardianId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
