import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { BadRequestException } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { MessagesService } from './messages.service';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class MessagesGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private onlineUsers = new Map<number, string>();
  private socketUsers = new Map<string, number>();

  constructor(private readonly messagesService: MessagesService) {}

  handleConnection(client: Socket) {
    const userId = Number(client.handshake.auth?.userId);

    if (userId && !Number.isNaN(userId)) {
      this.registerUser(client, userId);
    }
  }

  handleDisconnect(client: Socket) {
    const userId = this.socketUsers.get(client.id);

    if (userId) {
      this.onlineUsers.delete(userId);
      this.socketUsers.delete(client.id);
      this.broadcastOnlineUsers();
    }
  }

  private registerUser(client: Socket, userId: number) {
    this.onlineUsers.set(userId, client.id);
    this.socketUsers.set(client.id, userId);
    client.join(`user_${userId}`);
    this.broadcastOnlineUsers();
  }

  private broadcastOnlineUsers() {
    this.server.emit('online_users', Array.from(this.onlineUsers.keys()));
  }

  @SubscribeMessage('join_user')
  handleJoinUser(
    @MessageBody() body: any,
    @ConnectedSocket() client: Socket,
  ) {
    const userId = Number(body.userId);

    if (!userId || Number.isNaN(userId)) {
      return { success: false, message: 'Invalid userId' };
    }

    this.registerUser(client, userId);

    return {
      success: true,
      message: 'User joined realtime chat',
      userId,
    };
  }

  @SubscribeMessage('join_conversation')
  handleJoinConversation(
    @MessageBody() body: any,
    @ConnectedSocket() client: Socket,
  ) {
    const conversation = body.conversation;

    if (!conversation) {
      return { success: false, message: 'Conversation is required' };
    }

    client.join(conversation);

    return {
      success: true,
      conversation,
    };
  }

  @SubscribeMessage('send_message')
  async handleSendMessage(@MessageBody() body: any) {
    try {
      const savedMessage = await this.messagesService.sendMessage(body);
      const conversation = savedMessage.conversation;

      this.server.to(conversation).emit('new_message', savedMessage);
      this.server.to(`user_${savedMessage.receiverId}`).emit('new_message', savedMessage);
      this.server.to(`user_${savedMessage.senderId}`).emit('new_message', savedMessage);

      return savedMessage;
    } catch (error) {
      const message =
        error instanceof BadRequestException
          ? error.message
          : 'Message failed';

      this.server.to(`user_${body.senderId}`).emit('message_error', {
        message,
      });

      return {
        success: false,
        message,
      };
    }
  }

  @SubscribeMessage('typing')
  handleTyping(@MessageBody() body: any) {
    const conversation = body.conversation;
    const receiverId = Number(body.receiverId);

    const payload = {
      conversation,
      senderId: Number(body.senderId),
      receiverId,
      isTyping: Boolean(body.isTyping),
    };

    if (conversation) {
      this.server.to(conversation).emit('typing_status', payload);
    }

    if (receiverId) {
      this.server.to(`user_${receiverId}`).emit('typing_status', payload);
    }

    return {
      success: true,
    };
  }
}
