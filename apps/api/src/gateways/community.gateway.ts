import { WebSocketGateway, SubscribeMessage, OnGatewayConnection, MessageBody, ConnectedSocket, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { CommunitiesService } from '../communities/communities.service';
import { Inject } from '@nestjs/common';

@WebSocketGateway({ namespace: '/community', cors: { origin: '*' } })
export class CommunityGateway implements OnGatewayConnection {
  @WebSocketServer() server: Server;
  
  constructor(@Inject(CommunitiesService) private readonly communitiesService: CommunitiesService) {}

  handleConnection(client: Socket) {
    // connection established
  }

  @SubscribeMessage('join')
  async handleJoin(@MessageBody() data: { communityId: string }, @ConnectedSocket() client: Socket) {
    try {
      // Extract user from socket handshake
      const userId = client.handshake.auth?.userId || client.handshake.query?.userId;
      if (!userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }
      
      // Check if user is a member of the community
      await this.communitiesService.checkCommunityAccessWithRadius(data.communityId, userId);
      
      const room = `community:${data.communityId}`;
      client.join(room);
      client.emit('presence', { joined: true });
    } catch (error) {
      client.emit('error', { message: error.message || 'Access denied' });
    }
  }

  @SubscribeMessage('message:new')
  async handleMessage(@MessageBody() data: { communityId: string; text: string; senderId: string }, @ConnectedSocket() client: Socket) {
    try {
      // Extract user from socket handshake
      const userId = client.handshake.auth?.userId || client.handshake.query?.userId;
      if (!userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }
      
      // Check if user is a member of the community
      await this.communitiesService.checkCommunityAccessWithRadius(data.communityId, userId);
      
      const room = `community:${data.communityId}`;
      this.server.to(room).emit('message:new', { ...data, at: Date.now() });
    } catch (error) {
      client.emit('error', { message: error.message || 'Access denied' });
    }
  }

  @SubscribeMessage('typing')
  async handleTyping(@MessageBody() data: { communityId: string; senderId: string; typing: boolean }, @ConnectedSocket() client: Socket) {
    try {
      // Extract user from socket handshake
      const userId = client.handshake.auth?.userId || client.handshake.query?.userId;
      if (!userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }
      
      // Check if user is a member of the community
      await this.communitiesService.checkCommunityAccessWithRadius(data.communityId, userId);
      
      const room = `community:${data.communityId}`;
      this.server.to(room).emit('typing', data);
    } catch (error) {
      client.emit('error', { message: error.message || 'Access denied' });
    }
  }

  @SubscribeMessage('read')
  async handleRead(@MessageBody() data: { communityId: string; messageId: string; readerId: string }, @ConnectedSocket() client: Socket) {
    try {
      // Extract user from socket handshake
      const userId = client.handshake.auth?.userId || client.handshake.query?.userId;
      if (!userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }
      
      // Check if user is a member of the community
      await this.communitiesService.checkCommunityAccessWithRadius(data.communityId, userId);
      
      const room = `community:${data.communityId}`;
      this.server.to(room).emit('read', data);
    } catch (error) {
      client.emit('error', { message: error.message || 'Access denied' });
    }
  }
}