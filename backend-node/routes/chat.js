import express from 'express';
import { getUserById, getChatMessages, getChatConversations, addChatMessage } from '../store.js';

const router = express.Router();

router.post('/send', (req, res) => {
  const { userId: targetUserId, content } = req.body;
  const sender = req.user;
  if (!content || typeof content !== 'string' || !content.trim()) {
    return res.status(400).json({ code: 'INVALID_INPUT', message: 'A non-empty message is required' });
  }

  let conversationUserId = sender.userId;
  if (sender.role === 'admin') {
    if (!targetUserId) {
      return res.status(400).json({ code: 'INVALID_INPUT', message: 'Admin must specify a userId to message' });
    }
    const targetUser = getUserById(targetUserId);
    if (!targetUser) {
      return res.status(404).json({ code: 'NOT_FOUND', message: 'Target user not found' });
    }
    conversationUserId = targetUserId;
  }

  const message = addChatMessage({
    userId: conversationUserId,
    senderId: sender.userId,
    senderRole: sender.role,
    content: content.trim(),
  });

  return res.status(201).json(message);
});

router.get('/', (req, res) => {
  const user = req.user;
  const { userId: requestedUserId } = req.query;

  if (user.role === 'admin') {
    if (requestedUserId) {
      const targetUser = getUserById(requestedUserId);
      if (!targetUser) {
        return res.status(404).json({ code: 'NOT_FOUND', message: 'Target user not found' });
      }
      return res.json({ messages: getChatMessages(requestedUserId) });
    }
    return res.json({ conversations: getChatConversations() });
  }

  return res.json({ messages: getChatMessages(user.userId) });
});

router.get('/messages', (req, res) => {
  const user = req.user;
  const { userId: requestedUserId } = req.query;

  if (user.role === 'admin') {
    if (requestedUserId) {
      const targetUser = getUserById(requestedUserId);
      if (!targetUser) {
        return res.status(404).json({ code: 'NOT_FOUND', message: 'Target user not found' });
      }
      return res.json({ messages: getChatMessages(requestedUserId) });
    }
    return res.json({ conversations: getChatConversations() });
  }

  return res.json({ messages: getChatMessages(user.userId) });
});

export default router;
