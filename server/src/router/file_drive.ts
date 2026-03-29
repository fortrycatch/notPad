import path from 'node:path';
import { TRPCError } from '@trpc/server';
import { z } from 'zod';
import { router, needAuth } from '../trpc/trpc.js';
import { getInfo, getPublicUrl, getUploadUrl } from '../utils/aliOss.js';
import { DRIVE_PAGE_SIZE, fileData, fileFolderData, usageStatsData } from '../utils/sqlData.js';

const driveSortSchema = z.enum(['time', 'time_desc', 'name']);
const driveSearchScopeSchema = z.enum(['current', 'all']);

const nullableFolderId = z.string().nullable().optional().transform((value) => value ?? null);

const toPublicFile = <T extends { oss_key: string }>(file: T) => ({
    ...file,
    public_url: getPublicUrl(file.oss_key)
});

const ensureFolderAccessible = async (folderId: string | null, userId: string) => {
    if (!folderId) {
        return null;
    }

    const folder = await fileFolderData.getFolderById(folderId, userId);
    if (!folder) {
        throw new TRPCError({ code: 'NOT_FOUND', message: '文件夹不存在' });
    }

    return folder;
};

const getUploadSuffix = (filename: string, type: string) => {
    const ext = path.extname(filename);
    if (ext) {
        return ext;
    }

    if (type === 'text/plain') {
        return '.txt';
    }

    if (type === 'application/pdf') {
        return '.pdf';
    }

    return '.bin';
};

export default router({
    getUploadUrl: needAuth.input(z.object({
        filename: z.string(),
        type: z.string().default('application/octet-stream'),
        folder_id: nullableFolderId
    })).query(async ({ input, ctx }) => {
        await ensureFolderAccessible(input.folder_id, ctx.user_id);
        return await getUploadUrl(
            ctx.user_id,
            'file',
            getUploadSuffix(input.filename, input.type),
            input.type || 'application/octet-stream'
        );
    }),
    addFile: needAuth.input(z.object({
        name: z.string(),
        filename: z.string(),
        folder_id: nullableFolderId,
        mime_type: z.string().default('application/octet-stream')
    })).mutation(async ({ input, ctx }) => {
        await ensureFolderAccessible(input.folder_id, ctx.user_id);

        const info = await getInfo(input.filename);
        if (!info) {
            throw new TRPCError({ code: 'BAD_REQUEST', message: '文件不存在' });
        }

        const size = Number(info.res.headers['content-length'] || 0);
        const file = await fileData.addFile(
            input.name,
            input.filename,
            size,
            input.mime_type || 'application/octet-stream',
            input.folder_id,
            ctx.user_id
        );

        if (!file) {
            throw new TRPCError({ code: 'INTERNAL_SERVER_ERROR', message: '文件登记失败' });
        }

        usageStatsData.increment(ctx.user_id, 'stat_files_count', 1);
        usageStatsData.increment(ctx.user_id, 'stat_files_size', size);
        return toPublicFile(file);
    }),
    createFolder: needAuth.input(z.object({
        name: z.string().trim().min(1).max(255),
        parent_id: nullableFolderId
    })).mutation(async ({ input, ctx }) => {
        await ensureFolderAccessible(input.parent_id, ctx.user_id);

        const siblings = await fileFolderData.listByParent(ctx.user_id, input.parent_id, 'name', input.name, 0);
        if (siblings.some((folder) => folder.name === input.name)) {
            throw new TRPCError({ code: 'CONFLICT', message: '同级目录下已存在同名文件夹' });
        }

        const folder = await fileFolderData.createFolder(input.name, input.parent_id, ctx.user_id);
        if (!folder) {
            throw new TRPCError({ code: 'INTERNAL_SERVER_ERROR', message: '创建文件夹失败' });
        }

        return folder;
    }),
    list: needAuth.input(z.object({
        folder_id: nullableFolderId,
        offset: z.number().int().min(0).default(0),
        sort: driveSortSchema.optional(),
        search: z.string().optional(),
        search_scope: driveSearchScopeSchema.optional()
    })).query(async ({ input, ctx }) => {
        const currentFolder = await ensureFolderAccessible(input.folder_id, ctx.user_id);
        const search = input.search?.trim() || '';
        const sort = input.sort || 'time_desc';
        const searchScope = input.search_scope || 'current';
        const searchAll = search !== '' && searchScope === 'all';
        const [folders, files, breadcrumbs] = await Promise.all([
            searchAll
                ? fileFolderData.searchFolders(ctx.user_id, search, sort, input.offset)
                : fileFolderData.listByParent(ctx.user_id, input.folder_id, sort, search, input.offset),
            search
                ? fileData.searchFiles(ctx.user_id, search, input.offset, input.folder_id, sort, searchAll)
                : fileData.listByFolder(ctx.user_id, input.folder_id, sort, search, input.offset),
            fileFolderData.getBreadcrumbs(input.folder_id, ctx.user_id)
        ]);

        return {
            currentFolder,
            breadcrumbs,
            folders,
            files: files.map((file) => toPublicFile(file)),
            // 两路各自 LIMIT DRIVE_PAGE_SIZE：仅当某一类本页「满页」时可能还有下一页（两路条数之和无法表达任一流是否截断）
            hasMore: folders.length >= DRIVE_PAGE_SIZE || files.length >= DRIVE_PAGE_SIZE
        };
    }),
    renameFile: needAuth.input(z.object({
        id: z.number().int().positive(),
        name: z.string().trim().min(1).max(255)
    })).mutation(async ({ input, ctx }) => {
        const ok = await fileData.renameFile(input.id, input.name, ctx.user_id);
        if (!ok) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '文件不存在' });
        }
        return true;
    }),
    renameFolder: needAuth.input(z.object({
        id: z.string().trim().min(1),
        name: z.string().trim().min(1).max(255)
    })).mutation(async ({ input, ctx }) => {
        const ok = await fileFolderData.renameFolder(input.id, input.name, ctx.user_id);
        if (!ok) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '文件夹不存在' });
        }
        return true;
    }),
    getDownloadUrl: needAuth.input(z.object({
        file_id: z.number().int().positive()
    })).query(async ({ input, ctx }) => {
        const file = await fileData.getFileById(input.file_id, ctx.user_id);
        if (!file) {
            throw new TRPCError({ code: 'NOT_FOUND', message: '文件不存在' });
        }

        return {
            name: file.name,
            url: getPublicUrl(file.oss_key)
        };
    })
});
