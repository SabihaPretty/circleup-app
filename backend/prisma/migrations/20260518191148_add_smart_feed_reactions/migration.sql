-- AlterTable
ALTER TABLE "Comment" ADD COLUMN     "mediaType" TEXT DEFAULT 'text',
ADD COLUMN     "mediaUrl" TEXT;

-- AlterTable
ALTER TABLE "Like" ADD COLUMN     "reactionType" TEXT NOT NULL DEFAULT 'boost';
