import { router, needAuth, needGroupEditor } from '../trpc/trpc.js';
import { z } from 'zod';
import { TRPCError } from '@trpc/server';
import { bookmarkData, bookmarkTagData, usageStatsData } from '../utils/sqlData.js';
import config from '../config.js';

export default router({
    list: needAuth.input(z.object({
        offset: z.number().int().min(0),
        sort: z.enum(['time', 'time_desc', 'name']).optional(),
        search: z.string().optional(),
        tag_id: z.number().int().positive().nullable().optional(),
        type: z.enum(['url', 'image', 'note', 'file']).nullable().optional()
    })).query(async ({ input, ctx }) => {
        return await bookmarkData.list(
            ctx.user_id!,
            ctx.group_id,
            input.offset,
            input.sort || 'time_desc',
            input.search || '',
            input.tag_id ?? null,
            input.type ?? null
        )
    }),

    add: needGroupEditor.input(z.object({
        type: z.enum(['url', 'image', 'note', 'file']),
        title: z.string().trim().min(1).max(255),
        description: z.string().max(10000).optional(),
        content: z.string().optional(),
        url: z.string().max(1024).optional(),
        ref_id: z.string().max(255).nullable().optional(),
        tag_ids: z.array(z.number().int().positive()).optional()
    })).mutation(async ({ input, ctx }) => {
        if (input.ref_id) {
            const existing = await bookmarkData.findByRef(ctx.user_id!, ctx.group_id, input.type, input.ref_id)
            if (existing) {
                throw new TRPCError({ code: 'CONFLICT', message: '该资源已收藏' })
            }
        } else if (input.type === 'url' && input.url) {
            const existing = await bookmarkData.findByUrl(ctx.user_id!, ctx.group_id, input.url)
            if (existing) {
                throw new TRPCError({ code: 'CONFLICT', message: '该链接已收藏' })
            }
        }

        const bookmark = await bookmarkData.add(
            input.type,
            input.title,
            input.description || '',
            input.url || '',
            input.ref_id ?? null,
            ctx.user_id!,
            ctx.group_id,
            input.content ?? null
        )

        if (input.tag_ids && input.tag_ids.length > 0) {
            await Promise.all(
                input.tag_ids.map(tagId => bookmarkTagData.addTagToBookmark(bookmark.id, tagId))
            )
        }

        usageStatsData.increment(ctx.user_id!, ctx.group_id, 'stat_bookmarks_count', 1);
        return bookmark
    }),

    remove: needGroupEditor.input(z.object({
        id: z.number().int().positive()
    })).mutation(async ({ input, ctx }) => {
        const ok = await bookmarkData.remove(input.id, ctx.user_id!, ctx.group_id)
        if (!ok) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '书签不存在' })
        }
        usageStatsData.increment(ctx.user_id!, ctx.group_id, 'stat_bookmarks_count', -1);
        return true
    }),

    isBookmarked: needAuth.input(z.object({
        type: z.enum(['url', 'image', 'note', 'file']),
        ref_id: z.string().max(255)
    })).query(async ({ input, ctx }) => {
        const bookmark = await bookmarkData.findByRef(ctx.user_id!, ctx.group_id, input.type, input.ref_id)
        return bookmark ? { bookmarked: true, id: bookmark.id } : { bookmarked: false, id: null }
    }),

    fetchUrl: needAuth.input(z.object({
        url: z.string().url().max(2048)
    })).query(async ({ input }) => {
        const apiKey = config.jina.apiKey
        if (!apiKey) {
            throw new TRPCError({ code: 'PRECONDITION_FAILED', message: '未配置 Jina API Key（config.jina.apiKey）' })
        }

        const resp = await fetch(`https://r.jina.ai/${input.url}`, {
            headers: {
                'Accept': 'application/json',
                'Authorization': `Bearer ${apiKey}`
            }
        })

        if (!resp.ok) {
            throw new TRPCError({ code: 'BAD_REQUEST', message: `获取页面摘要失败: ${resp.status}` })
        }

        const json = await resp.json() as {
            data?: { title?: string; description?: string; content?: string; url?: string }
        }

        const data = json.data
        if (!data) {
            throw new TRPCError({ code: 'BAD_REQUEST', message: '无法解析页面内容' })
        }

        const content = data.content || ''
        return {
            title: data.title || '',
            description: data.description || content.slice(0, 500),
            content,
            url: data.url || input.url
        }
    }),

    getById: needAuth.input(z.object({
        id: z.number().int().positive()
    })).query(async ({ input, ctx }) => {
        const bookmark = await bookmarkData.getById(input.id, ctx.user_id!, ctx.group_id)
        if (!bookmark) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '书签不存在' })
        }
        return bookmark
    }),

    listTags: needAuth.query(async ({ ctx }) => {
        return await bookmarkTagData.list(ctx.user_id!, ctx.group_id)
    }),

    createTag: needGroupEditor.input(z.object({
        name: z.string().trim().min(1).max(64)
    })).mutation(async ({ input, ctx }) => {
        return await bookmarkTagData.create(input.name, ctx.user_id!, ctx.group_id)
    }),

    deleteTag: needGroupEditor.input(z.object({
        id: z.number().int().positive()
    })).mutation(async ({ input, ctx }) => {
        const ok = await bookmarkTagData.remove(input.id, ctx.user_id!, ctx.group_id)
        if (!ok) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '标签不存在' })
        }
        return true
    }),

    getBookmarkTags: needAuth.input(z.object({
        bookmark_id: z.number().int().positive()
    })).query(async ({ input }) => {
        return await bookmarkTagData.getTagsForBookmark(input.bookmark_id)
    }),

    addTagToBookmark: needGroupEditor.input(z.object({
        bookmark_id: z.number().int().positive(),
        tag_id: z.number().int().positive()
    })).mutation(async ({ input }) => {
        return await bookmarkTagData.addTagToBookmark(input.bookmark_id, input.tag_id)
    }),

    removeTagFromBookmark: needGroupEditor.input(z.object({
        bookmark_id: z.number().int().positive(),
        tag_id: z.number().int().positive()
    })).mutation(async ({ input }) => {
        return await bookmarkTagData.removeTagFromBookmark(input.bookmark_id, input.tag_id)
    }),
})
