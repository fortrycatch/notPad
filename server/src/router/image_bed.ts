import { router, needAuth, needGroupEditor } from '../trpc/trpc.js';
import { z } from 'zod';
import { getInfo, getUploadUrl, test } from '../utils/aliOss.js';
import { TRPCError } from '@trpc/server';
import { imageData, imageTagData, usageStatsData } from '../utils/sqlData.js';

function mimeToExtension(mime: string) {
    const table: Record<string, string> = {
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'image/avif': '.avif',
        'image/svg+xml': '.svg',
        'image/gif': '.gif',
        'image/bmp': '.bmp',
        'image/tiff': '.tiff',
    }
    return table[mime] || '.png'
}

export default router({
    getUploadUrl: needGroupEditor.input(z.object({
        filename: z.string(),
        type: z.string()
    })).query(async ({ input, ctx }) => {
        const type = input.type.split('/')
        if (type[0] !== 'image') {
            throw new TRPCError({ code: 'BAD_REQUEST', message: '类型错误' });
        }
        return await getUploadUrl(ctx.group_id ?? ctx.user_id!, 'image', mimeToExtension(input.type), input.type);
    }),
    addImage: needGroupEditor.input(z.object({
        name: z.string(),
        filename: z.string(),
        remark: z.string()
    })).mutation(async ({ input, ctx }) => {
        const info = await getInfo(input.filename)
        if (!info) {
            throw new TRPCError({ code: 'BAD_REQUEST', message: '图片不存在' });
        }
        const size = Number(info.res.headers['content-length'] || 0);
        const result = await imageData.addImage(input.name, input.filename, size, ctx.user_id!, ctx.group_id, input.remark);
        usageStatsData.increment(ctx.user_id!, ctx.group_id, 'stat_images_count', 1);
        usageStatsData.increment(ctx.user_id!, ctx.group_id, 'stat_images_size', size);
        return result;
    }),
    rename: needGroupEditor.input(z.object({
        id: z.number().int().positive(),
        name: z.string().trim().min(1).max(255)
    })).mutation(async ({ input, ctx }) => {
        const ok = await imageData.renameImage(input.id, input.name, ctx.user_id!, ctx.group_id)
        if (!ok) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '图片不存在' });
        }
        return true
    }),
    test: needAuth.query(async () => {
        return await test();
    }),
    list: needAuth.input(z.object({
        user_id: z.string(),
        offset: z.number(),
        sort: z.enum(['time', 'time_desc', 'name']).optional(),
        search: z.string().optional(),
        tag_id: z.number().int().positive().nullable().optional()
    })).query(async ({ input, ctx }) => {
        return await imageData.getImageList(
            ctx.user_id!,
            ctx.group_id,
            input.offset,
            input.sort || 'time_desc',
            input.search || '',
            input.tag_id ?? null
        )
    }),
    listTags: needAuth.query(async ({ ctx }) => {
        return await imageTagData.list(ctx.user_id!, ctx.group_id)
    }),
    createTag: needGroupEditor.input(z.object({
        name: z.string().trim().min(1).max(64)
    })).mutation(async ({ input, ctx }) => {
        return await imageTagData.create(input.name, ctx.user_id!, ctx.group_id)
    }),
    deleteTag: needGroupEditor.input(z.object({
        id: z.number().int().positive()
    })).mutation(async ({ input, ctx }) => {
        const ok = await imageTagData.remove(input.id, ctx.user_id!, ctx.group_id)
        if (!ok) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '标签不存在' });
        }
        return true
    }),
    getImageTags: needAuth.input(z.object({
        image_id: z.number().int().positive()
    })).query(async ({ input }) => {
        return await imageTagData.getTagsForImage(input.image_id)
    }),
    addTagToImage: needGroupEditor.input(z.object({
        image_id: z.number().int().positive(),
        tag_id: z.number().int().positive()
    })).mutation(async ({ input }) => {
        return await imageTagData.addTagToImage(input.image_id, input.tag_id)
    }),
    removeTagFromImage: needGroupEditor.input(z.object({
        image_id: z.number().int().positive(),
        tag_id: z.number().int().positive()
    })).mutation(async ({ input }) => {
        return await imageTagData.removeTagFromImage(input.image_id, input.tag_id)
    }),
})
