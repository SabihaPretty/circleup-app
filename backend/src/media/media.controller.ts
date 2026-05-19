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

@Controller('media')
export class MediaController {
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: uploadDir,
        filename: (req, file, callback) => {
          const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
          const ext = extname(file.originalname || '');
          callback(null, `${unique}${ext}`);
        },
      }),
      limits: {
        fileSize: 50 * 1024 * 1024,
      },
    }),
  )
  uploadFile(@UploadedFile() file: any) {
    if (!file) {
      throw new BadRequestException('No file uploaded.');
    }

    const mime = file.mimetype || '';
    let mediaType = 'file';

    if (mime.startsWith('image/')) mediaType = 'photo';
    if (mime.startsWith('video/')) mediaType = 'video';
    if (mime.startsWith('audio/')) mediaType = 'audio';

    return {
      success: true,
      message: 'File uploaded successfully.',
      data: {
        fileName: file.filename,
        originalName: file.originalname,
        mimeType: file.mimetype,
        size: file.size,
        mediaType,
        url: `/uploads/${file.filename}`,
      },
    };
  }
}
