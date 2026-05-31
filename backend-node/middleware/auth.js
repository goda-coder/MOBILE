import jwt from 'jsonwebtoken';
import { getUserById } from '../store.js';

const secret = process.env.JWT_SECRET || 'secret';

export const authenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ code: 'UNAUTHORIZED', message: 'Missing Authorization header' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const payload = jwt.verify(token, secret);
    const user = getUserById(payload.sub);
    if (!user) return res.status(401).json({ code: 'INVALID_TOKEN', message: 'Token is invalid or expired' });
    req.user = user;
    next();
  } catch (error) {
    return res.status(401).json({ code: 'INVALID_TOKEN', message: 'Token is invalid or expired' });
  }
};
