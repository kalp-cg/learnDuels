/**
 * Chat Socket Handler
 * Handles real-time general chat events
 */

const { prisma } = require('../config/db');

const GENERAL_ROOM = 'general_chat';
let pinnedMessage = null; // In-memory storage for pinned message

/**
 * Register chat event handlers
 * @param {Object} socket - Socket.IO socket instance
 * @param {Object} io - Socket.IO server instance
 */
function registerEvents(socket, io) {
  // Join general chat
  socket.on('chat:join', async () => {
    socket.join(GENERAL_ROOM);
    
    // Update user count
    const room = io.sockets.adapter.rooms.get(GENERAL_ROOM);
    const count = room ? room.size : 0;
    io.to(GENERAL_ROOM).emit('chat:user_count', { count });

    // Send pinned message
    if (pinnedMessage) {
      socket.emit('chat:pinned_message', pinnedMessage);
    }

    // Fetch recent history
    try {
      // Find or create general conversation
      let generalChat = await prisma.conversation.findFirst({
        where: { type: 'general' }
      });

      if (!generalChat) {
        generalChat = await prisma.conversation.create({
          data: { type: 'general' }
        });
      }

      const messages = await prisma.message.findMany({
        where: { conversationId: generalChat.id },
        take: 50,
        orderBy: { createdAt: 'desc' },
        include: { 
          sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
          replyTo: { include: { sender: { select: { fullName: true, username: true } } } }
        }
      });

      // Send history to user (reversed to show oldest first)
      socket.emit('chat:history', messages.reverse().map(m => ({
        id: m.id.toString(),
        senderId: m.senderId,
        senderName: m.sender.fullName || m.sender.username,
        senderAvatar: m.sender.avatarUrl,
        content: m.content || '',
        timestamp: m.createdAt.toISOString(),
        type: m.type,
        attachmentUrl: m.attachmentUrl,
        metadata: m.metadata,
        replyTo: m.replyTo ? {
          id: m.replyTo.id.toString(),
          senderName: m.replyTo.sender.fullName || m.replyTo.sender.username,
          content: m.replyTo.content || 'Image'
        } : null
      })));
    } catch (err) {
      console.error('Error fetching chat history:', err);
    }
  });

  // Leave general chat
  socket.on('chat:leave', () => {
    socket.leave(GENERAL_ROOM);
    const room = io.sockets.adapter.rooms.get(GENERAL_ROOM);
    const count = room ? room.size : 0;
    io.to(GENERAL_ROOM).emit('chat:user_count', { count });
  });

  // Handle disconnect to update count
  socket.on('disconnect', () => {
    // Socket automatically leaves rooms on disconnect, so we just need to emit the new count
    // We use a small delay or nextTick to ensure the room set is updated, 
    // though 'disconnect' usually happens after room departure.
    // Actually, checking room size of a room the socket just left might be tricky if we don't know if they were in it.
    // But we can just emit to the room. If the room is empty, no one receives it, which is fine.
    const room = io.sockets.adapter.rooms.get(GENERAL_ROOM);
    const count = room ? room.size : 0;
    io.to(GENERAL_ROOM).emit('chat:user_count', { count });
  });

  // Handle sending messages
  socket.on('chat:send', async (data) => {
    try {
      const { message, replyTo, type = 'text', attachmentUrl, metadata } = data;
      
      if ((!message || !message.trim()) && type === 'text') return;

      // Find general chat ID
      let generalChat = await prisma.conversation.findFirst({
        where: { type: 'general' }
      });
      
      if (!generalChat) {
         generalChat = await prisma.conversation.create({ data: { type: 'general' } });
      }

      // Save to DB
      const savedMessage = await prisma.message.create({
        data: {
          conversationId: generalChat.id,
          senderId: socket.userId,
          content: message ? message.trim() : null,
          type: type,
          attachmentUrl: attachmentUrl,
          metadata: metadata, // Save metadata (e.g., challenge details)
          replyToId: replyTo ? parseInt(replyTo.id) : null
        },
        include: {
          sender: { select: { id: true, username: true, fullName: true, avatarUrl: true } },
          replyTo: { include: { sender: { select: { fullName: true, username: true } } } }
        }
      });

      const messageData = {
        id: savedMessage.id.toString(),
        senderId: socket.userId,
        senderName: socket.userName,
        senderAvatar: socket.userAvatar,
        content: savedMessage.content || '',
        timestamp: savedMessage.createdAt.toISOString(),
        type: savedMessage.type,
        attachmentUrl: savedMessage.attachmentUrl,
        metadata: savedMessage.metadata,
        replyTo: savedMessage.replyTo ? {
          id: savedMessage.replyTo.id.toString(),
          senderName: savedMessage.replyTo.sender.fullName || savedMessage.replyTo.sender.username,
          content: savedMessage.replyTo.content || 'Image'
        } : null
      };

      // Broadcast to everyone in the room
      io.to(GENERAL_ROOM).emit('chat:message', messageData);
      
    } catch (error) {
      console.error('Chat send error:', error);
      socket.emit('chat:error', { message: 'Failed to send message' });
    }
  });

  // Handle pinning messages
  socket.on('chat:pin', (messageData) => {
    // Only allow pinning if message exists (client sends full message data)
    pinnedMessage = messageData;
    io.to(GENERAL_ROOM).emit('chat:pinned_message', pinnedMessage);
  });

  // Handle unpinning
  socket.on('chat:unpin', () => {
    pinnedMessage = null;
    io.to(GENERAL_ROOM).emit('chat:pinned_message', null);
  });

  // Handle typing status
  socket.on('chat:typing', (isTyping) => {
    socket.to(GENERAL_ROOM).emit('chat:typing', {
      userId: socket.userId,
      username: socket.userName,
      isTyping
    });
  });

  // Handle deleting messages
  socket.on('chat:delete', async (data) => {
    try {
      const { messageId } = data;
      if (!messageId) return;

      // Verify ownership
      const message = await prisma.message.findUnique({
        where: { id: parseInt(messageId) },
        select: { senderId: true }
      });

      if (!message) {
        socket.emit('chat:error', { message: 'Message not found' });
        return;
      }

      if (message.senderId !== socket.userId) {
        socket.emit('chat:error', { message: 'Not authorized to delete this message' });
        return;
      }

      // Delete from DB
      await prisma.message.delete({
        where: { id: parseInt(messageId) }
      });

      // Broadcast deletion
      io.to(GENERAL_ROOM).emit('chat:message_deleted', { messageId });

    } catch (err) {
      console.error('Error deleting message:', err);
      socket.emit('chat:error', { message: 'Failed to delete message' });
    }
  });
}

module.exports = {
  registerEvents,
};
