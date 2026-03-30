import config from './config.js';
import cors from 'cors';
import { createContext } from './trpc/context.js';
import appRouter from './router/index.js';
import express from 'express';
import * as trpcExpress from '@trpc/server/adapters/express';
import { initDatabase, testConnection } from './database.js';
import { userData, tokenData, groupMemberData } from './utils/sqlData.js';
import { subscribeGroupChat } from './groupChatBus.js';

export type AppRouter = typeof appRouter;

const app = express();
app.use(cors());
app.use('/trpc', trpcExpress.createExpressMiddleware({ router: appRouter, createContext }));

app.get('/api/group-chat/stream', async (req, res) => {
    const token = typeof req.query.token === 'string' ? req.query.token : '';
    const groupId = typeof req.query.groupId === 'string' ? req.query.groupId : '';
    if (!token || !groupId) {
        res.status(400).end();
        return;
    }
    const auth = await tokenData.verifyToken(token);
    if (!auth.ok || !auth.user_id) {
        res.status(401).end();
        return;
    }
    const membership = await groupMemberData.getMembership(groupId, auth.user_id);
    if (!membership) {
        res.status(403).end();
        return;
    }
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    ;(res as { flushHeaders?: () => void }).flushHeaders?.();

    const unsub = subscribeGroupChat(groupId, (message) => {
        res.write(`data: ${JSON.stringify({ type: 'message', message })}\n\n`);
    });
    const ping = setInterval(() => { res.write(': ping\n\n'); }, 25000);
    req.on('close', () => {
        clearInterval(ping);
        unsub();
    });
});

app.use(express.static('public'));
// 处理所有未匹配的路由，返回 index.html 用于客户端路由
app.use((req, res, next) => {
    if (req.path.startsWith('/trpc') || req.path.startsWith('/api')) {
        return next();
    }
    res.sendFile('public/index.html', { root: '.' });
});
app.listen(config.port, async () => {
    console.log(`Server is running on port ${config.port}`);
    
    // 初始化数据库
    try {
        await testConnection();
        await initDatabase();
        await userData.ensureDefaultUserIfEmpty();
        console.log('数据库初始化完成');
    } catch (error) {
        console.error('数据库初始化失败:', error);
    }
});
