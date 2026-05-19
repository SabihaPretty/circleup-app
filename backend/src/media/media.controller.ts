import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { existsSync, mkdirSync } from 'fs';
import { extname, join } from 'path';

const uploadDir = join(process.cwd(), 'uploads');

if (!existsSync(uploadDir)) {
  mkdirSync(uploadDir, { recursive: true });
}

function safeFileName(originalName: string) {
  const clean = String(originalName || 'circleup-file')
    .replace(/[^\w.\-]+/g, '_')
    .slice(0, 80);

  const ext = extname(clean);
  const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;

  return `${unique}${ext || '.bin'}`;
}

@Controller('media')
export class MediaController {
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: uploadDir,
        filename: (req, file, callback) => {
          callback(null, safeFileName(file.originalname));
        },
      }),
      limits: {
        fileSize: 100 * 1024 * 1024,
      },
    }),
  )
  uploadFile(@UploadedFile() file: any) {
    if (!file || !file.filename) {
      throw new BadRequestException('No file uploaded.');
    }

    const mime = String(file.mimetype || '');
    let mediaType = 'file';

    if (mime.startsWith('image/')) mediaType = 'photo';
    if (mime.startsWith('video/')) mediaType = 'video';
    if (mime.startsWith('audio/')) mediaType = 'audio';

    return {
      success: true,
      message: 'File uploaded successfully.',
      data: {
        fileName: file.filename,
        originalName: file.originalname || file.filename,
        mimeType: file.mimetype || 'application/octet-stream',
        size: Number(file.size || 0),
        mediaType,
        url: `/uploads/${file.filename}`,
      },
    };
  }
}
