import {
  ConnectedSocket,
  MessageBody,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { GroupsService } from './groups.service';

type CallUser = {
  userId: number;
  socketId: string;
  user: any;
};

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class GroupsGateway implements OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private callRooms = new Map<string, Map<number, CallUser>>();
  private socketCallMap = new Map<string, string>();

  constructor(private readonly groupsService: GroupsService) {}

  handleDisconnect(client: Socket) {
    const callId = this.socketCallMap.get(client.id);

    if (!callId) return;

    const room = this.callRooms.get(callId);

    if (!room) return;

    let leavingUserId: number | null = null;

    for (const [userId, item] of room.entries()) {
      if (item.socketId === client.id) {
        leavingUserId = userId;
        room.delete(userId);
        break;
      }
    }

    if (leavingUserId) {
      client.to(`group_call_${callId}`).emit('group_call_user_left', {
        callId,
        userId: leavingUserId,
      });
    }

    if (room.size === 0) {
      this.callRooms.delete(callId);
    }

    this.socketCallMap.delete(client.id);
  }

  @SubscribeMessage('join_group')
  handleJoinGroup(@MessageBody() body: any, @ConnectedSocket() client: Socket) {
    const groupId = Number(body.groupId);

    if (!groupId) {
      return { success: false, message: 'Invalid group ID.' };
    }

    client.join(`group_${groupId}`);

    return {
      success: true,
      message: 'Joined group room.',
      groupId,
    };
  }

  @SubscribeMessage('send_group_message')
  async handleSendGroupMessage(@MessageBody() body: any) {
    const message = await this.groupsService.sendMessage(body);

    this.server.to(`group_${message.groupId}`).emit('new_group_message', message);

    return {
      success: true,
      data: message,
    };
  }

  @SubscribeMessage('group_typing')
  handleGroupTyping(@MessageBody() body: any, @ConnectedSocket() client: Socket) {
    const groupId = Number(body.groupId);

    if (!groupId) return { success: false };

    client.to(`group_${groupId}`).emit('group_typing_status', {
      groupId,
      userId: Number(body.userId),
      user: body.user || null,
      isTyping: body.isTyping === true,
    });

    return { success: true };
  }

  @SubscribeMessage('group_call_invite')
  handleGroupCallInvite(@MessageBody() body: any, @ConnectedSocket() client: Socket) {
    const groupId = Number(body.groupId);

    if (!groupId) return { success: false };

    client.to(`group_${groupId}`).emit('incoming_group_call', {
      callId: body.callId,
      groupId,
      callType: body.callType || 'audio',
      callerId: Number(body.callerId),
      caller: body.caller || null,
      group: body.group || null,
      createdAt: new Date().toISOString(),
    });

    return { success: true };
  }

  @SubscribeMessage('join_group_call')
  handleJoinGroupCall(@MessageBody() body: any, @ConnectedSocket() client: Socket) {
    const callId = String(body.callId || '');
    const groupId = Number(body.groupId);
    const userId = Number(body.userId);

    if (!callId || !groupId || !userId) {
      return {
        success: false,
        message: 'Invalid group call data.',
      };
    }

    const roomKey = `group_call_${callId}`;
    const existingRoom = this.callRooms.get(callId) || new Map<number, CallUser>();
    const existingUsers = Array.from(existingRoom.values()).map((item) => ({
      userId: item.userId,
      user: item.user,
    }));

    client.join(roomKey);

    existingRoom.set(userId, {
      userId,
      socketId: client.id,
      user: body.user || null,
    });

    this.callRooms.set(callId, existingRoom);
    this.socketCallMap.set(client.id, callId);

    client.emit('group_existing_users', {
      callId,
      groupId,
      users: existingUsers,
    });

    client.to(roomKey).emit('group_call_user_joined', {
      callId,
      groupId,
      userId,
      user: body.user || null,
    });

    return {
      success: true,
      message: 'Joined group call.',
      existingUsers,
    };
  }

  @SubscribeMessage('leave_group_call')
  handleLeaveGroupCall(@MessageBody() body: any, @ConnectedSocket() client: Socket) {
    const callId = String(body.callId || '');
    const userId = Number(body.userId);

    if (!callId || !userId) {
      return { success: false };
    }

    const room = this.callRooms.get(callId);

    if (room) {
      room.delete(userId);

      if (room.size === 0) {
        this.callRooms.delete(callId);
      }
    }

    this.socketCallMap.delete(client.id);
    client.leave(`group_call_${callId}`);

    client.to(`group_call_${callId}`).emit('group_call_user_left', {
      callId,
      userId,
    });

    return { success: true };
  }

  @SubscribeMessage('group_webrtc_offer')
  handleGroupOffer(@MessageBody() body: any) {
    this.server.to(`group_call_${body.callId}`).emit('group_webrtc_offer', body);
    return { success: true };
  }

  @SubscribeMessage('group_webrtc_answer')
  handleGroupAnswer(@MessageBody() body: any) {
    this.server.to(`group_call_${body.callId}`).emit('group_webrtc_answer', body);
    return { success: true };
  }

  @SubscribeMessage('group_webrtc_ice_candidate')
  handleGroupIce(@MessageBody() body: any) {
    this.server.to(`group_call_${body.callId}`).emit('group_webrtc_ice_candidate', body);
    return { success: true };
  }
}
