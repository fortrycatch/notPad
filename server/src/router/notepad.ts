import { noteData } from '../utils/sqlData.js';
import { router, publicPro, needAuth } from '../trpc/trpc.js';
import { TRPCError } from '@trpc/server';
import z from 'zod';
export default router({
    // 笔记相关API
    getNotes: needAuth.input(z.number()).query(async ({ input,ctx }) => {
        return await noteData.getNotes('admin',input); // 暂时使用admin作为用户ID
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