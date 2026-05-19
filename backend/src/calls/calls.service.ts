import { Injectable } from '@nestjs/common';

@Injectable()
export class CallsService {
  startCall(data: any) {
    return {
      success: true,
      message: `${data.callType ?? 'video'} call started successfully`,
      callType: data.callType ?? 'video',
      callerId: data.callerId,
      receiverId: data.receiverId,
      startedAt: new Date(),
    };
  }
}
