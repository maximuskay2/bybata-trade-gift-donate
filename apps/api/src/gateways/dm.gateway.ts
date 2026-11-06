import { WebSocketGateway, SubscribeMessage, OnGatewayConnection, MessageBody, ConnectedSocket, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ namespace: '/dm', cors: { origin: '*' } })
export class DMGateway implements OnGatewayConnection {
  @WebSocketServer() server: Server;

  handleConnection(client: Socket) {}

  @SubscribeMessage('join')
  handleJoin(@MessageBody() data: { conversationId: string }, @ConnectedSocket() client: Socket) {
    const room = `dm:${data.conversationId}`;
    client.join(room);
    client.emit('presence', { joined: true });
  }

  @SubscribeMessage('message:new')
  handleMessage(@MessageBody() data: { conversationId: string; text: string; senderId: string }) {
    const room = `dm:${data.conversationId}`;
    this.server.to(room).emit('message:new', { ...data, at: Date.now() });
  }

  @SubscribeMessage('typing')
  handleTyping(@MessageBody() data: { conversationId: string; senderId: string; typing: boolean }) {
    const room = `dm:${data.conversationId}`;
    this.server.to(room).emit('typing', data);
  }

  @SubscribeMessage('read')
  handleRead(@MessageBody() data: { conversationId: string; messageId: string; readerId: string }) {
    const room = `dm:${data.conversationId}`;
    this.server.to(room).emit('read', data);
  }
}
