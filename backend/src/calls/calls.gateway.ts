import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class CallsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private userSockets = new Map<number, Set<string>>();
  private socketUsers = new Map<string, number>();

  handleConnection(client: Socket) {
    const userId = Number(client.handshake.auth?.userId);

    if (userId && !Number.isNaN(userId)) {
      this.registerUser(client, userId);
    }
  }

  handleDisconnect(client: Socket) {
    const userId = this.socketUsers.get(client.id);

    if (userId) {
      const sockets = this.userSockets.get(userId);

      if (sockets) {
        sockets.delete(client.id);

        if (sockets.size === 0) {
          this.userSockets.delete(userId);
        }
      }

      this.socketUsers.delete(client.id);
    }
  }

  private registerUser(client: Socket, userId: number) {
    const sockets = this.userSockets.get(userId) || new Set<string>();
    sockets.add(client.id);

    this.userSockets.set(userId, sockets);
    this.socketUsers.set(client.id, userId);
    client.join(`user_${userId}`);
  }

  private emitToUser(userId: number, event: string, payload: any) {
    this.server.to(`user_${userId}`).emit(event, payload);
  }

  @SubscribeMessage('join_user')
  handleJoinUser(@MessageBody() body: any, @ConnectedSocket() client: Socket) {
    const userId = Number(body.userId);

    if (!userId || Number.isNaN(userId)) {
      return {
        success: false,
        message: 'Invalid userId',
      };
    }

    this.registerUser(client, userId);

    return {
      success: true,
      message: 'User joined call signaling',
      userId,
    };
  }

  @SubscribeMessage('call_user')
  handleCallUser(@MessageBody() body: any) {
    const callerId = Number(body.callerId);
    const receiverId = Number(body.receiverId);
    const callId = body.callId;
    const callType = body.callType || 'audio';

    this.emitToUser(receiverId, 'incoming_call', {
      callId,
      callerId,
      receiverId,
      callType,
      caller: body.caller || null,
      createdAt: new Date().toISOString(),
    });

    return {
      success: true,
      message: 'Call invitation sent',
      callId,
    };
  }

  @SubscribeMessage('accept_call')
  handleAcceptCall(@MessageBody() body: any) {
    const callerId = Number(body.callerId);
    const receiverId = Number(body.receiverId);

    const payload = {
      callId: body.callId,
      callerId,
      receiverId,
      callType: body.callType || 'audio',
    };

    this.emitToUser(callerId, 'call_accepted', payload);
    this.emitToUser(receiverId, 'call_accepted', payload);

    return {
      success: true,
      message: 'Call accepted',
    };
  }

  @SubscribeMessage('call_ready')
  handleCallReady(@MessageBody() body: any) {
    const callerId = Number(body.callerId);

    this.emitToUser(callerId, 'receiver_ready', {
      callId: body.callId,
      callerId,
      receiverId: Number(body.receiverId),
    });

    return {
      success: true,
      message: 'Receiver ready',
    };
  }

  @SubscribeMessage('reject_call')
  handleRejectCall(@MessageBody() body: any) {
    const callerId = Number(body.callerId);

    this.emitToUser(callerId, 'call_rejected', {
      callId: body.callId,
      reason: body.reason || 'Call rejected',
    });

    return {
      success: true,
    };
  }

  @SubscribeMessage('end_call')
  handleEndCall(@MessageBody() body: any) {
    const targetId = Number(body.targetId);
    const fromId = Number(body.fromId);

    this.emitToUser(targetId, 'call_ended', {
      callId: body.callId,
      fromId,
      targetId,
    });

    this.emitToUser(fromId, 'call_ended', {
      callId: body.callId,
      fromId,
      targetId,
    });

    return {
      success: true,
    };
  }

  @SubscribeMessage('webrtc_offer')
  handleOffer(@MessageBody() body: any) {
    this.emitToUser(Number(body.targetId), 'webrtc_offer', body);
    return { success: true };
  }

  @SubscribeMessage('webrtc_answer')
  handleAnswer(@MessageBody() body: any) {
    this.emitToUser(Number(body.targetId), 'webrtc_answer', body);
    return { success: true };
  }

  @SubscribeMessage('webrtc_ice_candidate')
  handleIceCandidate(@MessageBody() body: any) {
    this.emitToUser(Number(body.targetId), 'webrtc_ice_candidate', body);
    return { success: true };
  }
}
