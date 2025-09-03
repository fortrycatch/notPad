import { router, publicProcedure } from './trpc';
import { createHTTPServer } from '@trpc/server/adapters/standalone';
import { PORT } from './config';
import cors from 'cors';
import { z } from 'zod';
import { createContext } from './context';
import { TRPCError } from '@trpc/server';
import { basicData } from './basicData';
import { noteData } from './utils/sqlData';
import { initDatabase, testConnection } from './database';
const needAuth = publicProcedure.use(async ({ ctx, next }) => {
    if (!ctx.authenticated) {
        throw new TRPCError({ code: 'UNAUTHORIZED' });
    }
    return next({ ctx });
})
const appRouter = router({
    hello: publicProcedure.input(z.string()).query(({ input }) => {
        return `Hello, ${input}!`
    }),
    hello2: needAuth.input(z.string()).query(({ input }) => {
        return `Hello, ${input}!`
    }),
    login: publicProcedure.input(z.object({
        username: z.string(),
        password: z.string()
    })).mutation(({ input }) => {
        if(input.username === 'admin' && input.password === '123456') {
            let token = Math.random().toString(36).substring(2, 15);
            basicData.token = token
            return {
                success: true,
                token
            }
        } else {
            return {
                success: false,
                token: null
            }
        }
    }),
    
    // 笔记相关API
    getNotes: needAuth.query(async ({ ctx }) => {
        return await noteData.getNotes('admin'); // 暂时使用admin作为用户ID
    }),
    
    getNoteById: needAuth.input(z.object({
        id: z.string()
    })).query(async ({ input, ctx }) => {
        const note = await noteData.getNoteById(input.id, 'admin');
        if (!note) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '笔记不存在' });
        }
        return note;
    }),
    
    createNote: needAuth.input(z.object({
        title: z.string(),
        content: z.string()
    })).mutation(async ({ input, ctx }) => {
        return await noteData.createNote(input.title, input.content, 'admin');
    }),
    
    updateNote: needAuth.input(z.object({
        id: z.string(),
        title: z.string(),
        content: z.string()
    })).mutation(async ({ input, ctx }) => {
        const note = await noteData.updateNote(input.id, input.title, input.content, 'admin');
        if (!note) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '笔记不存在' });
        }
        return note;
    }),
    
    deleteNote: needAuth.input(z.object({
        id: z.string()
    })).mutation(async ({ input, ctx }) => {
        const success = await noteData.deleteNote(input.id, 'admin');
        if (!success) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '笔记不存在' });
        }
        return { success: true };
    }),
})
export type AppRouter = typeof appRouter;
const server = createHTTPServer({
    router: appRouter,
    createContext,
    middleware: cors()
})
server.listen(PORT, async () => {
    console.log(`Server is running on port ${PORT}`)
    
    // 初始化数据库
    try {
        await testConnection()
        await initDatabase()
        console.log('数据库初始化完成')
    } catch (error) {
        console.error('数据库初始化失败:', error)
    }
})