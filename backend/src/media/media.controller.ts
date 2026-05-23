import {
  BadRequestException,
  Controller,
  InternalServerErrorException,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { v2 as cloudinary } from 'cloudinary';
import * as streamifier from 'streamifier';

function getMediaType(mime: string) {
  if (mime.startsWith('image/')) return 'photo';
  if (mime.startsWith('video/')) return 'video';
  if (mime.startsWith('audio/')) return 'audio';
  return 'file';
}

function getCloudinaryResourceType(mime: string) {
  if (mime.startsWith('image/')) return 'image';
  if (mime.startsWith('video/')) return 'video';
  return 'raw';
}

function safeName(name: string) {
  return String(name || 'circleup-file')
    .replace(/[^\w.\-]+/g, '_')
    .slice(0, 90);
}

@Controller('media')
export class MediaController {
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: {
        fileSize: 100 * 1024 * 1024,
      },
    }),
  )
  async uploadFile(@UploadedFile() file: any) {
    if (!file || !file.buffer) {
      throw new BadRequestException('No file uploaded.');
    }

    const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
    const apiKey = process.env.CLOUDINARY_API_KEY;
    const apiSecret = process.env.CLOUDINARY_API_SECRET;

    if (!cloudName || !apiKey || !apiSecret) {
      throw new InternalServerErrorException(
        'Cloudinary environment variables are missing.',
      );
    }

    cloudinary.config({
      cloud_name: cloudName,
      api_key: apiKey,
      api_secret: apiSecret,
      secure: true,
    });

    const mime = String(file.mimetype || 'application/octet-stream');
    const mediaType = getMediaType(mime);
    const resourceType = getCloudinaryResourceType(mime);
    const originalName = safeName(file.originalname || file.filename || 'circleup-file');

    const uploaded: any = await new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder: 'circleup',
          resource_type: resourceType as any,
          use_filename: true,
          unique_filename: true,
          filename_override: originalName,
        },
        (error, result) => {
          if (error) return reject(error);
          return resolve(result);
        },
      );

      streamifier.createReadStream(file.buffer).pipe(uploadStream);
    });

    if (!uploaded || !uploaded.secure_url) {
      throw new InternalServerErrorException('Cloudinary upload failed.');
    }

    return {
      success: true,
      message: 'File uploaded successfully.',
      data: {
        fileName: uploaded.public_id,
        originalName,
        mimeType: mime,
        size: Number(file.size || 0),
        mediaType,
        resourceType,
        url: uploaded.secure_url,
        publicId: uploaded.public_id,
      },
    };
  }
}
