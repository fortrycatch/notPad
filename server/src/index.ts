import config from './config.js';
import cors from 'cors';
import { createContext } from './trpc/context.js';
import appRouter from './router/index.js';
import express from 'express';
import * as trpcExpress from '@trpc/server/adapters/express';
import { initDatabase, testConnection } from './database.js';
import { userData } from './utils/sqlData.js';

export type AppRouter = typeof appRouter;

const app = express();
app.use(cors());
app.use('/trpc', trpcExpress.createExpressMiddleware({ router: appRouter, createContext }));
app.use(express.static('public'));
// 处理所有未匹配的路由，返回 index.html 用于客户端路由
app.use((req, res, next) => {
    // 跳过 API 路由和静态文件
    if (req.path.startsWith('/trpc')) {
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
