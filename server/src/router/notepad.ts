import { noteData, noteTagData, usageStatsData } from '../utils/sqlData.js';
import { router, publicPro, needAuth } from '../trpc/trpc.js';
import { TRPCError } from '@trpc/server';
import z from 'zod';
export default router({
    getNotes: needAuth.input(z.object({
        page: z.number(),
        tag_id: z.number().int().positive().nullable().optional()
    })).query(async ({ input, ctx }) => {
        return await noteData.getNotes(ctx.user_id, input.page, input.tag_id ?? null);
    }),

    getNoteById: needAuth.input(z.object({
        id: z.string()
    })).query(async ({ input, ctx }) => {
        const note = await noteData.getNoteById(input.id, ctx.user_id);
        if (!note) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '笔记不存在' });
        }
        return note;
    }),

    createNote: needAuth.input(z.object({
        title: z.string(),
        content: z.string()
    })).mutation(async ({ input, ctx }) => {
        const note = await noteData.createNote(input.title, input.content, ctx.user_id);
        usageStatsData.increment(ctx.user_id, 'stat_notes_count', 1);
        return note;
    }),

    updateNote: needAuth.input(z.object({
        id: z.string(),
        title: z.string(),
        content: z.string()
    })).mutation(async ({ input, ctx }) => {
        const note = await noteData.updateNote(input.id, input.title, input.content, ctx.user_id);
        if (!note) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '笔记不存在' });
        }
        return note;
    }),

    deleteNote: needAuth.input(z.object({
        id: z.string()
    })).mutation(async ({ input, ctx }) => {
        const success = await noteData.deleteNote(input.id, ctx.user_id);
        if (!success) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '笔记不存在' });
        }
        usageStatsData.increment(ctx.user_id, 'stat_notes_count', -1);
        return { success: true };
    }),

    listTags: needAuth.query(async ({ ctx }) => {
        return await noteTagData.list(ctx.user_id);
    }),

    createTag: needAuth.input(z.object({
        name: z.string().trim().min(1).max(64)
    })).mutation(async ({ input, ctx }) => {
        return await noteTagData.create(input.name, ctx.user_id);
    }),

    deleteTag: needAuth.input(z.object({
        id: z.number().int().positive()
    })).mutation(async ({ input, ctx }) => {
        const ok = await noteTagData.remove(input.id, ctx.user_id);
        if (!ok) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '标签不存在' });
        }
        return true;
    }),

    getNoteTags: needAuth.input(z.object({
        note_id: z.string()
    })).query(async ({ input }) => {
        return await noteTagData.getTagsForNote(input.note_id);
    }),

    addTagToNote: needAuth.input(z.object({
        note_id: z.string(),
        tag_id: z.number().int().positive()
    })).mutation(async ({ input }) => {
        return await noteTagData.addTagToNote(input.note_id, input.tag_id);
    }),

    removeTagFromNote: needAuth.input(z.object({
        note_id: z.string(),
        tag_id: z.number().int().positive()
    })).mutation(async ({ input }) => {
        return await noteTagData.removeTagFromNote(input.note_id, input.tag_id);
    }),
})