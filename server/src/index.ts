import config from './config.js';
import cors from 'cors';
import { createContext } from './trpc/context.js';
import appRouter from './router/index.js';
import express from 'express';
import * as trpcExpress from '@trpc/server/adapters/express';
import { initDatabase, testConnection } from './database.js';

export type AppRouter = typeof appRouter;

const app = express();
app.use(cors());
app.use('/trpc', trpcExpress.createExpressMiddleware({ router: appRouter, createContext }));
app.use(express.static('public'));

app.listen(config.port, async () => {
    console.log(`Server is running on port ${config.port}`);
    
    // 初始化数据库
    try {
        await testConnection();
        await initDatabase();
        console.log('数据库初始化完成');
    } catch (error) {
        console.error('数据库初始化失败:', error);
    }
});
