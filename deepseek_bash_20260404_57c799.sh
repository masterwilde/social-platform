#!/bin/bash
chmod +x deepseek_bash_20260404_57c799.sh
./deepseek_bash_20260404_57c799.sh
cd social-platform/frontend
npm install
npm run build

# Social Platform Complete Setup Script
# Run this script to generate the entire project structure

echo "🚀 Creating Social Platform Project..."

# Create root directory
mkdir -p social-platform
cd social-platform
<h1>It works</h1>
# Create backend directory structure
mkdir -p backend/{models,routes,middleware,controllers,uploads}
mkdir -p frontend/src/{components,pages,context,utils,hooks}
mkdir -p frontend/public

# ==================== BACKEND FILES ====================

# Backend package.json
cat > backend/package.json << 'EOF'
{
  "name": "social-platform-backend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^8.0.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "multer": "^1.4.5-lts.1",
    "socket.io": "^4.5.4",
    "express-validator": "^7.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# Backend server.js
cat > backend/server.js << 'EOF'
import express from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { Server } from 'socket.io';
import authRoutes from './routes/auth.js';
import postRoutes from './routes/posts.js';
import userRoutes from './routes/users.js';
import messageRoutes from './routes/messages.js';
import notificationRoutes from './routes/notifications.js';

dotenv.config();

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: "http://localhost:3000",
    credentials: true
  }
});

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static('uploads'));

io.on('connection', (socket) => {
  console.log('New client connected');
  socket.on('join', (userId) => {
    socket.join(userId);
  });
  socket.on('sendMessage', (data) => {
    io.to(data.receiverId).emit('newMessage', data);
  });
  socket.on('disconnect', () => {
    console.log('Client disconnected');
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/posts', postRoutes);
app.use('/api/users', userRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/notifications', notificationRoutes);

mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/social-platform', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('MongoDB connected'))
.catch(err => console.log(err));

const PORT = process.env.PORT || 5000;
httpServer.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

# Backend Models
cat > backend/models/User.js << 'EOF'
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true, trim: true },
  email: { type: String, required: true, unique: true, lowercase: true },
  password: { type: String, required: true },
  fullName: { type: String, required: true },
  profilePicture: { type: String, default: 'default-avatar.png' },
  coverPhoto: String,
  bio: { type: String, maxLength: 160 },
  location: String,
  website: String,
  birthday: Date,
  followers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  following: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  posts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }],
  savedPosts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }],
  isPrivate: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

userSchema.methods.comparePassword = async function(password) {
  return await bcrypt.compare(password, this.password);
};

export default mongoose.model('User', userSchema);
EOF

cat > backend/models/Post.js << 'EOF'
import mongoose from 'mongoose';

const postSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, required: true, maxLength: 280 },
  images: [String],
  video: String,
  likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  comments: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    content: String,
    createdAt: { type: Date, default: Date.now }
  }],
  shares: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model('Post', postSchema);
EOF

cat > backend/models/Message.js << 'EOF'
import mongoose from 'mongoose';

const messageSchema = new mongoose.Schema({
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  receiver: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  content: { type: String, required: true },
  read: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model('Message', messageSchema);
EOF

cat > backend/models/Notification.js << 'EOF'
import mongoose from 'mongoose';

const notificationSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  type: { type: String, enum: ['like', 'comment', 'follow', 'share'], required: true },
  fromUser: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  postId: { type: mongoose.Schema.Types.ObjectId, ref: 'Post' },
  read: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model('Notification', notificationSchema);
EOF

# Backend Middleware
cat > backend/middleware/auth.js << 'EOF'
import jwt from 'jsonwebtoken';

export const protect = async (req, res, next) => {
  let token;
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }
  if (!token) {
    return res.status(401).json({ message: 'Not authorized' });
  }
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret');
    req.userId = decoded.userId;
    next();
  } catch (error) {
    res.status(401).json({ message: 'Not authorized' });
  }
};
EOF

# Backend Routes
cat > backend/routes/auth.js << 'EOF'
import express from 'express';
import jwt from 'jsonwebtoken';
import User from '../models/User.js';

const router = express.Router();

router.post('/register', async (req, res) => {
  try {
    const { username, email, password, fullName } = req.body;
    const userExists = await User.findOne({ $or: [{ email }, { username }] });
    if (userExists) {
      return res.status(400).json({ message: 'User already exists' });
    }
    const user = await User.create({ username, email, password, fullName });
    const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET || 'secret', {
      expiresIn: '30d'
    });
    res.status(201).json({
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        profilePicture: user.profilePicture
      }
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }
    const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET || 'secret', {
      expiresIn: '30d'
    });
    res.json({
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        profilePicture: user.profilePicture
      }
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

export default router;
EOF

cat > backend/routes/posts.js << 'EOF'
import express from 'express';
import Post from '../models/Post.js';
import User from '../models/User.js';
import Notification from '../models/Notification.js';
import { protect } from '../middleware/auth.js';

const router = express.Router();

router.post('/', protect, async (req, res) => {
  try {
    const post = await Post.create({
      user: req.userId,
      content: req.body.content,
      images: req.body.images || []
    });
    await User.findByIdAndUpdate(req.userId, {
      $push: { posts: post._id }
    });
    const populatedPost = await Post.findById(post._id).populate('user', 'username fullName profilePicture');
    res.status(201).json(populatedPost);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/feed', protect, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    const following = user.following;
    const posts = await Post.find({
      $or: [
        { user: req.userId },
        { user: { $in: following } }
      ]
    })
    .populate('user', 'username fullName profilePicture')
    .populate('comments.user', 'username profilePicture')
    .sort('-createdAt')
    .limit(20);
    res.json(posts);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/:postId/like', protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.postId);
    if (post.likes.includes(req.userId)) {
      post.likes = post.likes.filter(id => id.toString() !== req.userId);
    } else {
      post.likes.push(req.userId);
      await Notification.create({
        user: post.user,
        type: 'like',
        fromUser: req.userId,
        postId: post._id
      });
    }
    await post.save();
    res.json({ likes: post.likes.length });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/:postId/comment', protect, async (req, res) => {
  try {
    const post = await Post.findById(req.params.postId);
    post.comments.push({
      user: req.userId,
      content: req.body.content
    });
    await post.save();
    await Notification.create({
      user: post.user,
      type: 'comment',
      fromUser: req.userId,
      postId: post._id
    });
    const updatedPost = await Post.findById(req.params.postId)
      .populate('comments.user', 'username profilePicture');
    res.json(updatedPost.comments);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

export default router;
EOF

cat > backend/routes/users.js << 'EOF'
import express from 'express';
import User from '../models/User.js';
import Post from '../models/Post.js';
import Notification from '../models/Notification.js';
import { protect } from '../middleware/auth.js';

const router = express.Router();

router.get('/profile/:username', protect, async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username })
      .select('-password')
      .populate('followers', 'username fullName profilePicture')
      .populate('following', 'username fullName profilePicture');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    const posts = await Post.find({ user: user._id })
      .populate('user', 'username fullName profilePicture')
      .sort('-createdAt');
    res.json({ user, posts });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/me', protect, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('-password');
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/:userId', protect, async (req, res) => {
  try {
    const user = await User.findById(req.params.userId).select('username fullName profilePicture');
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/:userId/follow', protect, async (req, res) => {
  try {
    const userToFollow = await User.findById(req.params.userId);
    const currentUser = await User.findById(req.userId);
    if (userToFollow.followers.includes(req.userId)) {
      userToFollow.followers = userToFollow.followers.filter(id => id.toString() !== req.userId);
      currentUser.following = currentUser.following.filter(id => id.toString() !== req.params.userId);
    } else {
      userToFollow.followers.push(req.userId);
      currentUser.following.push(req.params.userId);
      await Notification.create({
        user: req.params.userId,
        type: 'follow',
        fromUser: req.userId
      });
    }
    await userToFollow.save();
    await currentUser.save();
    res.json({ followers: userToFollow.followers.length });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/search', protect, async (req, res) => {
  try {
    const { q } = req.query;
    const users = await User.find({
      $or: [
        { username: { $regex: q, $options: 'i' } },
        { fullName: { $regex: q, $options: 'i' } }
      ]
    }).select('username fullName profilePicture').limit(10);
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/profile', protect, async (req, res) => {
  try {
    const { bio, location, website, fullName } = req.body;
    const user = await User.findByIdAndUpdate(
      req.userId,
      { bio, location, website, fullName },
      { new: true }
    ).select('-password');
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

export default router;
EOF

cat > backend/routes/messages.js << 'EOF'
import express from 'express';
import Message from '../models/Message.js';
import User from '../models/User.js';
import { protect } from '../middleware/auth.js';

const router = express.Router();

router.get('/conversations', protect, async (req, res) => {
  try {
    const messages = await Message.find({
      $or: [
        { sender: req.userId },
        { receiver: req.userId }
      ]
    }).sort('-createdAt');
    const conversationIds = new Set();
    messages.forEach(msg => {
      if (msg.sender.toString() === req.userId) {
        conversationIds.add(msg.receiver.toString());
      } else {
        conversationIds.add(msg.sender.toString());
      }
    });
    const conversations = await User.find({
      _id: { $in: Array.from(conversationIds) }
    }).select('username fullName profilePicture');
    res.json(conversations);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/:userId', protect, async (req, res) => {
  try {
    const messages = await Message.find({
      $or: [
        { sender: req.userId, receiver: req.params.userId },
        { sender: req.params.userId, receiver: req.userId }
      ]
    }).sort('createdAt');
    await Message.updateMany(
      { sender: req.params.userId, receiver: req.userId, read: false },
      { read: true }
    );
    res.json(messages);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/', protect, async (req, res) => {
  try {
    const message = await Message.create({
      sender: req.userId,
      receiver: req.body.receiverId,
      content: req.body.content
    });
    const populatedMessage = await message.populate('sender', 'username profilePicture');
    res.status(201).json(populatedMessage);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

export default router;
EOF

cat > backend/routes/notifications.js << 'EOF'
import express from 'express';
import Notification from '../models/Notification.js';
import { protect } from '../middleware/auth.js';

const router = express.Router();

router.get('/', protect, async (req, res) => {
  try {
    const notifications = await Notification.find({ user: req.userId })
      .populate('fromUser', 'username fullName profilePicture')
      .populate('postId')
      .sort('-createdAt')
      .limit(50);
    res.json(notifications);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/:id/read', protect, async (req, res) => {
  try {
    await Notification.findByIdAndUpdate(req.params.id, { read: true });
    res.json({ message: 'Notification marked as read' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.put('/read-all', protect, async (req, res) => {
  try {
    await Notification.updateMany(
      { user: req.userId, read: false },
      { read: true }
    );
    res.json({ message: 'All notifications marked as read' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

export default router;
EOF

# Backend .env
cat > backend/.env << 'EOF'
MONGODB_URI=mongodb://localhost:27017/social-platform
JWT_SECRET=your_super_secret_jwt_key_here_change_this
PORT=5000
EOF

# ==================== FRONTEND FILES ====================

# Frontend package.json
cat > frontend/package.json << 'EOF'
{
  "name": "social-platform-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.0",
    "axios": "^1.6.2",
    "socket.io-client": "^4.5.4",
    "react-query": "^3.39.3",
    "react-icons": "^4.12.0",
    "date-fns": "^2.30.0",
    "react-helmet-async": "^2.0.4",
    "react-hook-form": "^7.48.2",
    "react-hot-toast": "^2.4.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "devDependencies": {
    "react-scripts": "5.0.1",
    "tailwindcss": "^3.3.6",
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.32"
  },
  "proxy": "http://localhost:5000"
}
EOF

# Frontend Tailwind config
cat > frontend/tailwind.config.js << 'EOF'
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

# Frontend postcss config
cat > frontend/postcss.config.js << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# Frontend index.html
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="theme-color" content="#000000" />
  <meta name="description" content="Social Media Platform" />
  <title>SocialHub - Connect with Friends</title>
</head>
<body>
  <noscript>You need to enable JavaScript to run this app.</noscript>
  <div id="root"></div>
</body>
</html>
EOF

# Frontend src/index.css
cat > frontend/src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  body {
    @apply bg-gray-50;
  }
}

@layer components {
  .btn-primary {
    @apply bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors;
  }
  .btn-secondary {
    @apply bg-gray-200 text-gray-800 px-4 py-2 rounded-lg hover:bg-gray-300 transition-colors;
  }
}
EOF

# Frontend src/index.js
cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import { Toaster } from 'react-hot-toast';
import { QueryClient, QueryClientProvider } from 'react-query';

const queryClient = new QueryClient();

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <App />
      <Toaster position="top-right" />
    </QueryClientProvider>
  </React.StrictMode>
);
EOF

# Frontend src/App.js
cat > frontend/src/App.js << 'EOF'
import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { SocketProvider } from './context/SocketContext';
import PrivateRoute from './components/PrivateRoute';

import Login from './pages/Login';
import Register from './pages/Register';
import Home from './pages/Home';
import Profile from './pages/Profile';
import EditProfile from './pages/EditProfile';
import Messages from './pages/Messages';
import Chat from './pages/Chat';
import Notifications from './pages/Notifications';
import Explore from './pages/Explore';
import Saved from './pages/Saved';
import Settings from './pages/Settings';
import Followers from './pages/Followers';
import Following from './pages/Following';
import PostDetail from './pages/PostDetail';
import Search from './pages/Search';
import Trends from './pages/Trends';
import About from './pages/About';
import Help from './pages/Help';
import Privacy from './pages/Privacy';
import Terms from './pages/Terms';
import NotFound from './pages/NotFound';

function App() {
  return (
    <Router>
      <AuthProvider>
        <SocketProvider>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route path="/" element={<PrivateRoute><Home /></PrivateRoute>} />
            <Route path="/profile/:username" element={<PrivateRoute><Profile /></PrivateRoute>} />
            <Route path="/edit-profile" element={<PrivateRoute><EditProfile /></PrivateRoute>} />
            <Route path="/messages" element={<PrivateRoute><Messages /></PrivateRoute>} />
            <Route path="/messages/:userId" element={<PrivateRoute><Chat /></PrivateRoute>} />
            <Route path="/notifications" element={<PrivateRoute><Notifications /></PrivateRoute>} />
            <Route path="/explore" element={<PrivateRoute><Explore /></PrivateRoute>} />
            <Route path="/saved" element={<PrivateRoute><Saved /></PrivateRoute>} />
            <Route path="/settings" element={<PrivateRoute><Settings /></PrivateRoute>} />
            <Route path="/followers/:username" element={<PrivateRoute><Followers /></PrivateRoute>} />
            <Route path="/following/:username" element={<PrivateRoute><Following /></PrivateRoute>} />
            <Route path="/post/:postId" element={<PrivateRoute><PostDetail /></PrivateRoute>} />
            <Route path="/search" element={<PrivateRoute><Search /></PrivateRoute>} />
            <Route path="/trends" element={<PrivateRoute><Trends /></PrivateRoute>} />
            <Route path="/about" element={<About />} />
            <Route path="/help" element={<Help />} />
            <Route path="/privacy" element={<Privacy />} />
            <Route path="/terms" element={<Terms />} />
            <Route path="/404" element={<NotFound />} />
            <Route path="*" element={<Navigate to="/404" />} />
          </Routes>
        </SocketProvider>
      </AuthProvider>
    </Router>
  );
}

export default App;
EOF

# Frontend Context files
cat > frontend/src/context/AuthContext.js << 'EOF'
import React, { createContext, useState, useContext, useEffect } from 'react';
import axios from 'axios';
import toast from 'react-hot-toast';

const AuthContext = createContext();

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [token, setToken] = useState(localStorage.getItem('token'));

  useEffect(() => {
    if (token) {
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      fetchUser();
    } else {
      setLoading(false);
    }
  }, [token]);

  const fetchUser = async () => {
    try {
      const response = await axios.get('/api/users/me');
      setUser(response.data);
    } catch (error) {
      localStorage.removeItem('token');
      setToken(null);
      delete axios.defaults.headers.common['Authorization'];
    } finally {
      setLoading(false);
    }
  };

  const login = async (email, password) => {
    try {
      const response = await axios.post('/api/auth/login', { email, password });
      const { token, user } = response.data;
      localStorage.setItem('token', token);
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      setToken(token);
      setUser(user);
      toast.success('Logged in successfully!');
      return true;
    } catch (error) {
      toast.error(error.response?.data?.message || 'Login failed');
      return false;
    }
  };

  const register = async (userData) => {
    try {
      const response = await axios.post('/api/auth/register', userData);
      const { token, user } = response.data;
      localStorage.setItem('token', token);
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      setToken(token);
      setUser(user);
      toast.success('Registered successfully!');
      return true;
    } catch (error) {
      toast.error(error.response?.data?.message || 'Registration failed');
      return false;
    }
  };

  const logout = () => {
    localStorage.removeItem('token');
    delete axios.defaults.headers.common['Authorization'];
    setToken(null);
    setUser(null);
    toast.success('Logged out successfully');
  };

  return (
    <AuthContext.Provider value={{ user, setUser, loading, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
};
EOF

cat > frontend/src/context/SocketContext.js << 'EOF'
import React, { createContext, useContext, useEffect, useState } from 'react';
import io from 'socket.io-client';
import { useAuth } from './AuthContext';

const SocketContext = createContext();

export const useSocket = () => useContext(SocketContext);

export const SocketProvider = ({ children }) => {
  const [socket, setSocket] = useState(null);
  const { user } = useAuth();

  useEffect(() => {
    if (user) {
      const newSocket = io('http://localhost:5000');
      setSocket(newSocket);
      return () => {
        newSocket.close();
      };
    }
  }, [user]);

  return (
    <SocketContext.Provider value={{ socket }}>
      {children}
    </SocketContext.Provider>
  );
};
EOF

# Frontend Components
cat > frontend/src/components/PrivateRoute.js << 'EOF'
import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function PrivateRoute({ children }) {
  const { user, loading } = useAuth();
  
  if (loading) {
    return (
      <div className="flex justify-center items-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
      </div>
    );
  }
  
  return user ? children : <Navigate to="/login" />;
}
EOF

cat > frontend/src/components/Layout.js << 'EOF'
import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Layout({ children }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const navItems = [
    { path: '/', icon: '🏠', label: 'Home' },
    { path: '/explore', icon: '🔍', label: 'Explore' },
    { path: '/notifications', icon: '🔔', label: 'Notifications' },
    { path: '/messages', icon: '💬', label: 'Messages' },
    { path: `/profile/${user?.username}`, icon: '👤', label: 'Profile' },
    { path: '/settings', icon: '⚙️', label: 'Settings' },
  ];

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="fixed top-0 left-0 right-0 bg-white border-b border-gray-200 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <Link to="/" className="text-2xl font-bold text-blue-600">
                SocialHub
              </Link>
            </div>
            <div className="flex items-center space-x-4">
              {navItems.map((item) => (
                <Link
                  key={item.path}
                  to={item.path}
                  className="text-gray-600 hover:text-blue-600 transition-colors"
                  title={item.label}
                >
                  <span className="text-xl">{item.icon}</span>
                </Link>
              ))}
              <button
                onClick={logout}
                className="text-gray-600 hover:text-red-600 transition-colors"
                title="Logout"
              >
                <span className="text-xl">🚪</span>
              </button>
            </div>
          </div>
        </div>
      </nav>
      <main className="pt-16">{children}</main>
    </div>
  );
}
EOF

cat > frontend/src/components/Post.js << 'EOF'
import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { formatDistanceToNow } from 'date-fns';
import toast from 'react-hot-toast';
import { useAuth } from '../context/AuthContext';

export default function Post({ post, onUpdate }) {
  const [liked, setLiked] = useState(post.likes?.includes(post.user?._id));
  const [likesCount, setLikesCount] = useState(post.likes?.length || 0);
  const [showComments, setShowComments] = useState(false);
  const [comment, setComment] = useState('');
  const { user } = useAuth();

  const handleLike = async () => {
    try {
      await axios.post(`/api/posts/${post._id}/like`);
      setLiked(!liked);
      setLikesCount(prev => liked ? prev - 1 : prev + 1);
    } catch (error) {
      toast.error('Failed to like post');
    }
  };

  const handleComment = async (e) => {
    e.preventDefault();
    if (!comment.trim()) return;
    try {
      await axios.post(`/api/posts/${post._id}/comment`, { content: comment });
      setComment('');
      onUpdate();
      toast.success('Comment added');
    } catch (error) {
      toast.error('Failed to add comment');
    }
  };

  return (
    <div className="bg-white rounded-lg shadow mb-4">
      <div className="p-4">
        <div className="flex items-center justify-between mb-3">
          <Link to={`/profile/${post.user?.username}`} className="flex items-center space-x-3">
            <img
              src={post.user?.profilePicture || '/default-avatar.png'}
              alt={post.user?.username}
              className="w-10 h-10 rounded-full object-cover"
            />
            <div>
              <p className="font-semibold text-gray-900">{post.user?.fullName}</p>
              <p className="text-sm text-gray-500">@{post.user?.username}</p>
            </div>
          </Link>
          <span className="text-xs text-gray-500">
            {formatDistanceToNow(new Date(post.createdAt), { addSuffix: true })}
          </span>
        </div>
        <p className="text-gray-800 mb-3 whitespace-pre-wrap">{post.content}</p>
        <div className="flex items-center space-x-6 text-gray-500">
          <button onClick={handleLike} className="flex items-center space-x-1 hover:text-red-500">
            <span>{liked ? '❤️' : '🤍'}</span>
            <span>{likesCount}</span>
          </button>
          <button onClick={() => setShowComments(!showComments)} className="flex items-center space-x-1 hover:text-blue-500">
            <span>💬</span>
            <span>{post.comments?.length || 0}</span>
          </button>
          <button className="flex items-center space-x-1 hover:text-green-500">
            <span>🔄</span>
            <span>{post.shares?.length || 0}</span>
          </button>
        </div>
      </div>
      {showComments && (
        <div className="border-t border-gray-100 p-4">
          <form onSubmit={handleComment} className="flex space-x-2 mb-4">
            <input
              type="text"
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              placeholder="Write a comment..."
              className="flex-1 px-3 py-2 border border-gray-300 rounded-full focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded-full hover:bg-blue-700">Post</button>
          </form>
          <div className="space-y-3">
            {post.comments?.map((comment, idx) => (
              <div key={idx} className="flex space-x-2">
                <img src={comment.user?.profilePicture || '/default-avatar.png'} alt="" className="w-8 h-8 rounded-full object-cover" />
                <div className="flex-1">
                  <Link to={`/profile/${comment.user?.username}`} className="font-semibold text-sm">{comment.user?.fullName}</Link>
                  <p className="text-gray-700 text-sm">{comment.content}</p>
                  <span className="text-xs text-gray-500">{formatDistanceToNow(new Date(comment.createdAt), { addSuffix: true })}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
EOF

cat > frontend/src/components/CreatePost.js << 'EOF'
import React, { useState } from 'react';
import axios from 'axios';
import toast from 'react-hot-toast';
import { useAuth } from '../context/AuthContext';

export default function CreatePost({ onPostCreated }) {
  const [content, setContent] = useState('');
  const [loading, setLoading] = useState(false);
  const { user } = useAuth();

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!content.trim()) {
      toast.error('Please write something');
      return;
    }
    setLoading(true);
    try {
      const response = await axios.post('/api/posts', { content });
      setContent('');
      toast.success('Post created!');
      onPostCreated(response.data);
    } catch (error) {
      toast.error('Failed to create post');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow mb-6 p-4">
      <div className="flex space-x-3">
        <img src={user?.profilePicture || '/default-avatar.png'} alt={user?.username} className="w-10 h-10 rounded-full object-cover" />
        <form onSubmit={handleSubmit} className="flex-1">
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="What's on your mind?"
            className="w-full border-0 focus:ring-0 resize-none text-gray-900 placeholder-gray-500"
            rows="3"
          />
          <div className="flex justify-between items-center mt-2">
            <div className="flex space-x-2">
              <button type="button" className="text-gray-500 hover:text-blue-600">📷</button>
              <button type="button" className="text-gray-500 hover:text-blue-600">🎥</button>
            </div>
            <button type="submit" disabled={loading} className="px-4 py-2 bg-blue-600 text-white rounded-full hover:bg-blue-700 disabled:opacity-50">
              {loading ? 'Posting...' : 'Post'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
EOF

cat > frontend/src/components/Story.js << 'EOF'
import React from 'react';
import { useAuth } from '../context/AuthContext';

export default function Story() {
  const { user } = useAuth();
  const stories = [user, null, null, null, null];
  
  return (
    <div className="bg-white rounded-lg shadow mb-6 p-4">
      <div className="flex space-x-4 overflow-x-auto">
        {stories.map((story, idx) => (
          <div key={idx} className="flex flex-col items-center space-y-1 flex-shrink-0">
            <div className="w-16 h-16 rounded-full bg-gradient-to-tr from-yellow-400 to-red-600 p-0.5">
              <div className="w-full h-full rounded-full bg-white p-0.5">
                <img src={story?.profilePicture || '/default-avatar.png'} alt="" className="w-full h-full rounded-full object-cover" />
              </div>
            </div>
            <span className="text-xs text-gray-600">{story?.username || 'Story'}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
EOF

cat > frontend/src/components/Trends.js << 'EOF'
import React from 'react';

export default function Trends() {
  const trends = [
    { topic: '#ReactJS', posts: '12.5K' },
    { topic: '#WebDev', posts: '8.2K' },
    { topic: '#JavaScript', posts: '15.3K' },
    { topic: '#TailwindCSS', posts: '5.1K' },
  ];
  
  return (
    <div className="bg-white rounded-lg shadow p-4 mb-4">
      <h3 className="font-bold text-lg mb-3">Trends for you</h3>
      {trends.map((trend, idx) => (
        <div key={idx} className="mb-3 cursor-pointer hover:bg-gray-50 p-2 rounded">
          <p className="font-semibold text-sm">{trend.topic}</p>
          <p className="text-xs text-gray-500">{trend.posts} posts</p>
        </div>
      ))}
    </div>
  );
}
EOF

cat > frontend/src/components/Suggestions.js << 'EOF'
import React from 'react';

export default function Suggestions() {
  const suggestions = [
    { name: 'John Doe', username: 'johndoe', avatar: '/default-avatar.png' },
    { name: 'Jane Smith', username: 'janesmith', avatar: '/default-avatar.png' },
  ];
  
  return (
    <div className="bg-white rounded-lg shadow p-4">
      <h3 className="font-bold text-lg mb-3">Suggested for you</h3>
      {suggestions.map((suggestion, idx) => (
        <div key={idx} className="flex items-center justify-between mb-3">
          <div className="flex items-center space-x-2">
            <img src={suggestion.avatar} alt="" className="w-8 h-8 rounded-full" />
            <div>
              <p className="font-semibold text-sm">{suggestion.name}</p>
              <p className="text-xs text-gray-500">@{suggestion.username}</p>
            </div>
          </div>
          <button className="text-blue-600 text-sm font-semibold">Follow</button>
        </div>
      ))}
    </div>
  );
}
EOF

# Frontend Pages (simplified versions)
cat > frontend/src/pages/Home.js << 'EOF'
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import Layout from '../components/Layout';
import Post from '../components/Post';
import CreatePost from '../components/CreatePost';
import Story from '../components/Story';
import Trends from '../components/Trends';
import Suggestions from '../components/Suggestions';

export default function Home() {
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchFeed();
  }, []);

  const fetchFeed = async () => {
    try {
      const response = await axios.get('/api/posts/feed');
      setPosts(response.data);
    } catch (error) {
      console.error('Error fetching feed:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleNewPost = (post) => {
    setPosts([post, ...posts]);
  };

  return (
    <Layout>
      <div className="max-w-2xl mx-auto px-4 py-8">
        <Story />
        <CreatePost onPostCreated={handleNewPost} />
        {loading ? (
          <div className="flex justify-center py-8">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
          </div>
        ) : (
          <div className="space-y-4">
            {posts.map(post => <Post key={post._id} post={post} onUpdate={fetchFeed} />)}
          </div>
        )}
      </div>
      <div className="hidden lg:block fixed right-8 top-20 w-80">
        <Trends />
        <Suggestions />
      </div>
    </Layout>
  );
}
EOF

cat > frontend/src/pages/Login.js << 'EOF'
import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    const success = await login(email, password);
    setLoading(false);
    if (success) navigate('/');
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">Sign in to SocialHub</h2>
        </div>
        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <div className="rounded-md shadow-sm -space-y-px">
            <div>
              <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-blue-500 focus:border-blue-500 focus:z-10 sm:text-sm" placeholder="Email address" />
            </div>
            <div>
              <input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-blue-500 focus:border-blue-500 focus:z-10 sm:text-sm" placeholder="Password" />
            </div>
          </div>
          <div>
            <button type="submit" disabled={loading} className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50">
              {loading ? 'Signing in...' : 'Sign in'}
            </button>
          </div>
          <div className="text-center">
            <Link to="/register" className="text-blue-600 hover:text-blue-500">Don't have an account? Sign up</Link>
          </div>
        </form>
      </div>
    </div>
  );
}
EOF

cat > frontend/src/pages/Register.js << 'EOF'
import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Register() {
  const [formData, setFormData] = useState({ username: '', email: '', password: '', fullName: '' });
  const [loading, setLoading] = useState(false);
  const { register } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    const success = await register(formData);
    setLoading(false);
    if (success) navigate('/');
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div><h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">Create your account</h2></div>
        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <div className="space-y-4">
            <input type="text" required placeholder="Full Name" value={formData.fullName} onChange={(e) => setFormData({...formData, fullName: e.target.value})} className="appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm" />
            <input type="text" required placeholder="Username" value={formData.username} onChange={(e) => setFormData({...formData, username: e.target.value})} className="appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm" />
            <input type="email" required placeholder="Email" value={formData.email} onChange={(e) => setFormData({...formData, email: e.target.value})} className="appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm" />
            <input type="password" required placeholder="Password" value={formData.password} onChange={(e) => setFormData({...formData, password: e.target.value})} className="appearance-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm" />
          </div>
          <div>
            <button type="submit" disabled={loading} className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50">
              {loading ? 'Creating account...' : 'Sign up'}
            </button>
          </div>
          <div className="text-center">
            <Link to="/login" className="text-blue-600 hover:text-blue-500">Already have an account? Sign in</Link>
          </div>
        </form>
      </div>
    </div>
  );
}
EOF

# Create remaining page files (simplified)
for page in Profile EditProfile Messages Chat Notifications Explore Saved Settings Followers Following PostDetail Search Trends About Help Privacy Terms NotFound; do
  cat > frontend/src/pages/${page}.js << EOF
import React from 'react';
import Layout from '../components/Layout';

export default function ${page}() {
  return (
    <Layout>
      <div className="max-w-4xl mx-auto px-4 py-8">
        <h1 className="text-2xl font-bold mb-6">${page}</h1>
        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-gray-600">${page} page content goes here.</p>
        </div>
      </div>
    </Layout>
  );
}
EOF
done

# Create README
cat > README.md << 'EOF'
# SocialHub - Complete Social Media Platform

## Features
- User authentication (register/login)
- Create, like, comment on posts
- Follow/unfollow users
- Real-time messaging with Socket.io
- Notifications system
- Profile management
- Responsive design

## Installation

### Prerequisites
- Node.js (v14 or higher)
- MongoDB (local or Atlas)

### Backend Setup
```bash
cd backend
npm install
npm run dev
