import { router, needAuth, needGroupEditor } from '../trpc/trpc.js';
import { TRPCError } from '@trpc/server';
import { z } from 'zod';
import { pool } from '../database.js';
import { todoListData, todoItemData, noteData, fileData, bookmarkData, ownerWhere } from '../utils/sqlData.js';
import type { TodoRef } from '../utils/sqlData.js';
import type { RowDataPacket } from 'mysql2';

async function verifyListOwner(listId: string, userId: string, groupId: string | null) {
  const list = await todoListData.getById(listId, userId, groupId);
  if (!list) throw new TRPCError({ code: 'NOT_FOUND', message: '列表不存在' });
  return list;
}

async function verifyItemOwner(itemId: string, userId: string, groupId: string | null) {
  const item = await todoItemData.getById(itemId);
  if (!item) throw new TRPCError({ code: 'NOT_FOUND', message: '待办不存在' });
  await verifyListOwner(item.list_id, userId, groupId);
  return item;
}

async function verifyRefTarget(refType: string, refId: string, userId: string, groupId: string | null): Promise<TodoRef> {
  const ow = ownerWhere(userId, groupId);
  if (refType === 'note') {
    const note = await noteData.getNoteById(refId, userId, groupId);
    if (!note) throw new TRPCError({ code: 'BAD_REQUEST', message: '引用的笔记不存在' });
    return { type: 'note' as const, refId, title: note.title || '未命名笔记' };
  }
  if (refType === 'image') {
    const [rows] = await pool.execute<RowDataPacket[]>(
      `SELECT id, name, url FROM images WHERE id = ? AND ${ow.sql}`,
      [Number(refId), ...ow.params]
    );
    if (!rows.length) throw new TRPCError({ code: 'BAD_REQUEST', message: '引用的图片不存在' });
    return {
      type: 'image' as const,
      refId,
      title: String(rows[0].name || '未命名图片'),
      url: String(rows[0].url || ''),
    };
  }
  if (refType === 'file') {
    const file = await fileData.getFileById(Number(refId), userId, groupId);
    if (!file) throw new TRPCError({ code: 'BAD_REQUEST', message: '引用的文件不存在' });
    return {
      type: 'file' as const,
      refId,
      title: file.name || '未命名文件',
      mimeType: file.mime_type || 'application/octet-stream',
    };
  }
  if (refType === 'bookmark') {
    const bookmark = await bookmarkData.getById(Number(refId), userId, groupId);
    if (!bookmark) throw new TRPCError({ code: 'BAD_REQUEST', message: '引用的书签不存在' });
    const bookmarkType: NonNullable<TodoRef['bookmarkType']> =
      bookmark.type === 'image' || bookmark.type === 'note' || bookmark.type === 'file'
        ? bookmark.type
        : 'url';
    return {
      type: 'bookmark' as const,
      refId,
      title: bookmark.title || '未命名书签',
      bookmarkType,
      url: bookmark.url || undefined,
      targetRefId: bookmark.ref_id || undefined,
    };
  }
  throw new TRPCError({ code: 'BAD_REQUEST', message: '不支持的引用类型' });
}

const todoRefInput = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('note'),
    refId: z.string().min(1).max(64),
    title: z.string().min(1).max(255).optional(),
  }),
  z.object({
    type: z.literal('image'),
    refId: z.string().min(1).max(64),
    title: z.string().min(1).max(255).optional(),
    url: z.string().min(1).max(1024).optional(),
  }),
  z.object({
    type: z.literal('file'),
    refId: z.string().min(1).max(64),
    title: z.string().min(1).max(255).optional(),
    mimeType: z.string().max(255).optional(),
  }),
  z.object({
    type: z.literal('bookmark'),
    refId: z.string().min(1).max(64),
    title: z.string().min(1).max(255).optional(),
    bookmarkType: z.enum(['url', 'image', 'note', 'file']).optional(),
    url: z.string().max(1024).optional(),
    targetRefId: z.string().max(255).optional(),
  }),
]);

type TodoRefInput = z.infer<typeof todoRefInput>;

async function normalizeRefs(
  refs: TodoRefInput[],
  userId: string,
  groupId: string | null,
) : Promise<TodoRef[]> {
  const normalized = await Promise.all(refs.map(ref => verifyRefTarget(ref.type, ref.refId, userId, groupId)));
  const unique = new Map<string, TodoRef>();
  for (const ref of normalized) {
    unique.set(`${ref.type}:${ref.refId}`, ref);
  }
  return [...unique.values()];
}

export default router({
  listLists: needAuth.query(async ({ ctx }) => {
    return await todoListData.list(ctx.user_id!, ctx.group_id);
  }),

  getList: needAuth.input(z.string()).query(async ({ ctx, input }) => {
    const list = await verifyListOwner(input, ctx.user_id!, ctx.group_id);
    const items = await todoItemData.listByListId(input);
    return { ...list, items };
  }),

  createList: needGroupEditor.input(z.object({
    name: z.string().min(1).max(255),
    color: z.string().max(32).default('#9e9e9e'),
  })).mutation(async ({ ctx, input }) => {
    return await todoListData.create(input.name, input.color, ctx.user_id!, ctx.group_id);
  }),

  updateList: needGroupEditor.input(z.object({
    id: z.string(),
    name: z.string().min(1).max(255).optional(),
    color: z.string().max(32).optional(),
    sort_order: z.number().int().optional(),
  })).mutation(async ({ ctx, input }) => {
    const { id, ...fields } = input;
    const ok = await todoListData.update(id, fields, ctx.user_id!, ctx.group_id);
    if (!ok) throw new TRPCError({ code: 'NOT_FOUND', message: '列表不存在' });
    return true;
  }),

  deleteList: needGroupEditor.input(z.string()).mutation(async ({ ctx, input }) => {
    const ok = await todoListData.remove(input, ctx.user_id!, ctx.group_id);
    if (!ok) throw new TRPCError({ code: 'NOT_FOUND', message: '列表不存在' });
    return true;
  }),

  createItem: needGroupEditor.input(z.object({
    listId: z.string(),
    title: z.string().min(1).max(512),
    description: z.string().max(4000).default(''),
    color: z.string().max(32).nullable().default(null),
    refs: z.array(todoRefInput).max(32).default([]),
  })).mutation(async ({ ctx, input }) => {
    await verifyListOwner(input.listId, ctx.user_id!, ctx.group_id);
    const refs = await normalizeRefs(input.refs, ctx.user_id!, ctx.group_id);
    return await todoItemData.create(input.listId, input.title, input.description, input.color, refs);
  }),

  updateItem: needGroupEditor.input(z.object({
    id: z.string(),
    title: z.string().min(1).max(512).optional(),
    description: z.string().max(4000).optional(),
    done: z.number().int().min(0).max(1).optional(),
    color: z.string().max(32).nullable().optional(),
    refs: z.array(todoRefInput).max(32).optional(),
    sort_order: z.number().int().optional(),
  })).mutation(async ({ ctx, input }) => {
    const { id, refs, ...rest } = input;
    await verifyItemOwner(id, ctx.user_id!, ctx.group_id);
    const fields: {
      title?: string;
      description?: string;
      done?: number;
      color?: string | null;
      refs?: TodoRef[];
      sort_order?: number;
    } = { ...rest };
    if (refs !== undefined) {
      fields.refs = await normalizeRefs(refs, ctx.user_id!, ctx.group_id);
    }
    const ok = await todoItemData.update(id, fields);
    if (!ok) throw new TRPCError({ code: 'NOT_FOUND', message: '待办不存在' });
    return true;
  }),

  deleteItem: needGroupEditor.input(z.string()).mutation(async ({ ctx, input }) => {
    await verifyItemOwner(input, ctx.user_id!, ctx.group_id);
    const ok = await todoItemData.remove(input);
    if (!ok) throw new TRPCError({ code: 'NOT_FOUND', message: '待办不存在' });
    return true;
  }),
});
