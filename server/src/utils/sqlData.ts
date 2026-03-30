import { pool } from '../database.js'
import type { RowDataPacket, ResultSetHeader } from 'mysql2'
import crypto from 'node:crypto'

function parseMeta(raw: unknown): Record<string, unknown> {
  if (!raw) return {}
  if (typeof raw === 'string') return JSON.parse(raw)
  if (typeof raw === 'object') return raw as Record<string, unknown>
  return {}
}

export function ownerWhere(userId: string, groupId: string | null): { sql: string; params: string[] } {
  if (groupId) return { sql: 'group_id = ?', params: [groupId] }
  return { sql: 'user_id = ? AND group_id IS NULL', params: [userId] }
}

export interface Note extends RowDataPacket {
  id: string
  title: string
  content: string
  user_id: string
  created_at: Date
  updated_at: Date
}

// 笔记列表项接口（简化版，只包含部分字段）
export interface NoteListItem extends RowDataPacket {
  id: string
  title: string
  content: string // LEFT(content,100) 的结果
  created_at: Date
  updated_at: Date
}

// 图片接口定义
export interface Image extends RowDataPacket {
  id: number
  name: string
  url: string
  size: number
  user_id: string
  created_at: Date
  remark: string
}

export const noteData = {
  getNotes: async (userId: string, groupId: string | null, offset: number, tagId: number | null = null): Promise<NoteListItem[]> => {
    const ow = ownerWhere(userId, groupId)
    const params: (string | number)[] = [...ow.params]
    let query: string

    if (tagId) {
      query = `SELECT n.id, n.title, LEFT(n.content,100) AS content, n.created_at, n.updated_at FROM notes n INNER JOIN note_tag_map m ON n.id = m.note_id WHERE n.${ow.sql} AND m.tag_id = ?`
      params.push(tagId)
    } else {
      query = `SELECT id, title, LEFT(content,100) AS content, created_at, updated_at FROM notes WHERE ${ow.sql}`
    }

    query += ' ORDER BY updated_at DESC LIMIT 30 OFFSET ?'
    params.push(offset * 30)

    const [rows] = await pool.execute<NoteListItem[]>(query, params)
    return rows
  },

  getNoteById: async (id: string, userId: string, groupId: string | null = null): Promise<Note | null> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<Note[]>(
      `SELECT * FROM notes WHERE id = ? AND ${ow.sql}`,
      [id, ...ow.params]
    )
    return rows[0] ?? null
  },

  createNote: async (title: string, content: string, userId: string, groupId: string | null = null): Promise<Note | null> => {
    const id = crypto.hash('sha1', userId + Date.now().toString() + crypto.randomUUID()).slice(0, 36)
    await pool.execute<ResultSetHeader>(
      'INSERT INTO notes (id, title, content, user_id, group_id) VALUES (?, ?, ?, ?, ?)',
      [id, title, content, userId, groupId]
    )
    return await noteData.getNoteById(id, userId, groupId)
  },

  updateNote: async (id: string, title: string, content: string, userId: string, groupId: string | null = null): Promise<Note | null> => {
    const ow = ownerWhere(userId, groupId)
    const [result] = await pool.execute<ResultSetHeader>(
      `UPDATE notes SET title = ?, content = ? WHERE id = ? AND ${ow.sql}`,
      [title, content, id, ...ow.params]
    )
    if (result.affectedRows === 0) return null
    return await noteData.getNoteById(id, userId, groupId)
  },

  deleteNote: async (id: string, userId: string, groupId: string | null = null): Promise<boolean> => {
    const ow = ownerWhere(userId, groupId)
    const [result] = await pool.execute<ResultSetHeader>(
      `DELETE FROM notes WHERE id = ? AND ${ow.sql}`,
      [id, ...ow.params]
    )
    return result.affectedRows > 0
  }
}
export interface User extends RowDataPacket {
  id: string
  name: string
  email: string
  password: string
  created_at: Date
  updated_at: Date
}
export const userData = {
  getUserById: async (id: string): Promise<User | null> => {
    try {
      const [rows] = await pool.execute<User[]>(
        'SELECT * FROM users WHERE id = ?',
        [id]
      )
      return rows.length > 0 ? rows[0] : null
    } catch (error) {
      console.error('获取用户失败:', error)
      throw error
    }
  },
  getUserByEmail: async (email: string): Promise<User | null> => {
    try {
      const [rows] = await pool.execute<User[]>(
        'SELECT * FROM users WHERE email = ?',
        [email]
      )
      return rows.length > 0 ? rows[0] : null
    } catch (error) {
      console.error('根据邮箱获取用户失败:', error)
      throw error
    }
  },
  getUserByName: async (name: string): Promise<User | null> => {
    try {
      const [rows] = await pool.execute<User[]>(
        'SELECT * FROM users WHERE name = ?',
        [name]
      )
      return rows.length > 0 ? rows[0] : null
    } catch (error) {
      console.error('根据用户名获取用户失败:', error)
      throw error
    }
  },
  getUserByUserId: async (id:string): Promise<User | null> => {
    try {
      const [rows] = await pool.execute<User[]>(
        'SELECT * FROM users WHERE id = ?',
        [id]
      )
      return rows.length > 0 ? rows[0] : null
    }
    catch (error) {
      console.error('根据用户ID获取用户失败:', error)
      throw error
    }
  },
  createUser: async (id:string, name: string, email: string, password: string): Promise<User | null> => {
    try {
      const hashedPassword = crypto.createHash('sha256').update(password).update("yuanshen").digest('hex')
      const user = await userData.getUserById(id)
      if(user){
        throw new Error('用户已存在')
      }
      await pool.execute<ResultSetHeader>(
        'INSERT INTO users (id, name, email, password) VALUES (?, ?, ?, ?)',
        [id, name, email, hashedPassword]
      )
      return await userData.getUserById(id)
    } catch (error) {
      console.error('创建用户失败:', error)
      throw error
    }
  },
  /** 首次部署：若 users 表无任何用户，则创建默认账号（可用环境变量 DEFAULT_USER_ID / DEFAULT_USER_NAME / DEFAULT_USER_EMAIL / DEFAULT_USER_PASSWORD 覆盖） */
  ensureDefaultUserIfEmpty: async (): Promise<void> => {
    try {
      const [rows] = await pool.execute<RowDataPacket[]>(
        'SELECT COUNT(*) AS cnt FROM users'
      )
      const cnt = Number((rows[0] as RowDataPacket & { cnt: number }).cnt)
      if (cnt > 0) return

      const id = process.env.DEFAULT_USER_ID || 'admin'
      const name = process.env.DEFAULT_USER_NAME || '管理员'
      const email = process.env.DEFAULT_USER_EMAIL || 'admin@localhost'
      const password = process.env.DEFAULT_USER_PASSWORD || 'admin123'

      await userData.createUser(id, name, email, password)
      console.warn(
        '[seed] 数据库中尚无用户，已创建默认账号：用户ID=%s，邮箱=%s。请尽快登录并在设置中修改密码；生产环境请设置 DEFAULT_USER_PASSWORD。',
        id,
        email
      )
    } catch (error) {
      console.error('创建默认用户失败:', error)
      throw error
    }
  },
  updateUser: async (id:string, name: string, email: string, password: string): Promise<User | null> => {
    try {
      const user = await userData.getUserById(id)
      if(!user){
        throw new Error('用户不存在')
      }
      await pool.execute<ResultSetHeader>(
        'UPDATE users SET name = ?, email = ?, password = ? WHERE id = ?',
        [name, email, password, id]
      )
      return await userData.getUserById(id)
    } catch (error) {
      console.error('更新用户失败:', error)
      throw error
    }
  },
  getMeta: async (id: string): Promise<Record<string, unknown>> => {
    const [rows] = await pool.execute<RowDataPacket[]>(
      'SELECT meta FROM users WHERE id = ?', [id]
    )
    return parseMeta(rows[0]?.meta)
  },
  updateMeta: async (id: string, meta: Record<string, unknown>): Promise<void> => {
    await pool.execute('UPDATE users SET meta = ? WHERE id = ?', [JSON.stringify(meta), id])
  },
}
export interface Token extends RowDataPacket {
  user_id: string
  token: string
  created_at: Date
  used_at: Date | null
  user_agent: string | null
  alias: string | null
}
export const tokenData = {
  //用户操作凭据
  createToken: async (
    user_id: string,
    user_agent: string | null = null,
    alias: string | null = null
  ): Promise<string> => {
    try {
      //生成随机加盐的token
      const token = crypto.randomBytes(32).toString('base64')
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex')
      await pool.execute<ResultSetHeader>(
        'INSERT INTO tokens (user_id, token, user_agent, alias) VALUES (?, ?, ?, ?)',
        [user_id, tokenHash, user_agent, alias]
      )
      return token
    } catch (error) {
      console.error('创建token失败:', error)
      throw error
    }
  },
  verifyToken: async (token: string): Promise<{user_id:string,ok:boolean}> => {
    try {
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex')
      const [rows] = await pool.execute<Token[]>(
        'SELECT * FROM tokens WHERE token = ?',
        [tokenHash]
      )
      return rows.length > 0 ? {user_id: rows[0].user_id, ok: true} : {user_id: '', ok: false}
    } catch (error) {
      console.error('验证token失败:', error)
      return {user_id: '', ok: false}
    }
  },
  deleteToken: async (token: string): Promise<boolean> => {
    try {
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex')
      const [result] = await pool.execute<ResultSetHeader>(
        'DELETE FROM tokens WHERE token = ?',
        [tokenHash]
      )
      return result.affectedRows > 0
    } catch (error) {
      console.error('删除token失败:', error)
      throw error
    }
  },
  deleteTokenByHash: async (tokenHash: string): Promise<boolean> => {
    try {
      const [result] = await pool.execute<ResultSetHeader>(
        'DELETE FROM tokens WHERE token = ?',
        [tokenHash]
      )
      return result.affectedRows > 0
    } catch (error) {
      console.error('删除token失败:', error)
      throw error
    }
  },
  getTokenByUserId: async (user_id: string): Promise<Token[] | null> => {
    try {
      const [rows] = await pool.execute<Token[]>(
        'SELECT * FROM tokens WHERE user_id = ?',
        [user_id]
      )
      return rows.length > 0 ? rows : null
    } catch (error) {
      console.error('获取用户token失败:', error)
      throw error
    }
  },
  updateTokenAlias: async (
    user_id: string,
    tokenHash: string,
    alias: string | null
  ): Promise<boolean> => {
    try {
      const [result] = await pool.execute<ResultSetHeader>(
        'UPDATE tokens SET alias = ? WHERE token = ? AND user_id = ?',
        [alias, tokenHash, user_id]
      )
      return result.affectedRows > 0
    } catch (error) {
      console.error('更新 token 别名失败:', error)
      throw error
    }
  }
}
export const imageData = {
  getImageList: async (userId: string, groupId: string | null, offset: number, sort: 'time' | 'time_desc' | 'name' = 'time_desc', search: string = '', tagId: number | null = null): Promise<Image[]> => {
    const sortMap: Record<string, string> = {
      'time': 'i.created_at',
      'time_desc': 'i.created_at DESC',
      'name': 'i.name'
    }
    const sortSql = sortMap[sort] || 'i.created_at DESC'
    const ow = ownerWhere(userId, groupId)

    let query: string
    const params: (string | number)[] = [...ow.params]

    if (tagId) {
      query = `SELECT i.* FROM images i INNER JOIN image_tag_map m ON i.id = m.image_id WHERE i.${ow.sql} AND m.tag_id = ?`
      params.push(tagId)
    } else {
      query = `SELECT i.* FROM images i WHERE i.${ow.sql}`
    }

    if (search && search.trim() !== '') {
      query += ' AND i.name LIKE ?'
      params.push(`%${search.trim()}%`)
    }

    query += ` ORDER BY ${sortSql} LIMIT 30 OFFSET ?`
    params.push(offset * 30)

    const [rows] = await pool.execute<Image[]>(query, params)
    return rows
  },
  addImage: async (name: string, url: string, size: number, userId: string, groupId: string | null, remark: string): Promise<ResultSetHeader> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO images (name, url, size, user_id, group_id, remark) VALUES (?, ?, ?, ?, ?, ?)',
      [name, url, size, userId, groupId, remark]
    )
    return result
  },
  renameImage: async (id: number, name: string, userId: string, groupId: string | null = null): Promise<boolean> => {
    const ow = ownerWhere(userId, groupId)
    const [result] = await pool.execute<ResultSetHeader>(
      `UPDATE images SET name = ? WHERE id = ? AND ${ow.sql}`,
      [name, id, ...ow.params]
    )
    return result.affectedRows > 0
  }
}

export interface ImageTag extends RowDataPacket {
  id: number
  name: string
  user_id: string
  created_at: Date
}

export const imageTagData = {
  list: async (userId: string, groupId: string | null = null): Promise<ImageTag[]> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<ImageTag[]>(
      `SELECT * FROM image_tags WHERE ${ow.sql} ORDER BY name`,
      ow.params
    )
    return rows
  },
  create: async (name: string, userId: string, groupId: string | null = null): Promise<ImageTag> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO image_tags (name, user_id, group_id) VALUES (?, ?, ?)',
      [name, userId, groupId]
    )
    const [rows] = await pool.execute<ImageTag[]>(
      'SELECT * FROM image_tags WHERE id = ?',
      [result.insertId]
    )
    return rows[0]
  },
  remove: async (id: number, userId: string, groupId: string | null = null): Promise<boolean> => {
    await pool.execute('DELETE FROM image_tag_map WHERE tag_id = ?', [id])
    const ow = ownerWhere(userId, groupId)
    const [result] = await pool.execute<ResultSetHeader>(
      `DELETE FROM image_tags WHERE id = ? AND ${ow.sql}`,
      [id, ...ow.params]
    )
    return result.affectedRows > 0
  },
  getTagsForImage: async (imageId: number): Promise<ImageTag[]> => {
    const [rows] = await pool.execute<ImageTag[]>(
      'SELECT t.* FROM image_tags t INNER JOIN image_tag_map m ON t.id = m.tag_id WHERE m.image_id = ? ORDER BY t.name',
      [imageId]
    )
    return rows
  },
  addTagToImage: async (imageId: number, tagId: number): Promise<boolean> => {
    try {
      await pool.execute(
        'INSERT INTO image_tag_map (image_id, tag_id) VALUES (?, ?)',
        [imageId, tagId]
      )
      return true
    } catch (e: unknown) {
      const err = e as { code?: string }
      if (err.code === 'ER_DUP_ENTRY') return false
      throw e
    }
  },
  removeTagFromImage: async (imageId: number, tagId: number): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'DELETE FROM image_tag_map WHERE image_id = ? AND tag_id = ?',
      [imageId, tagId]
    )
    return result.affectedRows > 0
  }
}

export interface NoteTag extends RowDataPacket {
  id: number
  name: string
  user_id: string
  created_at: Date
}

export const noteTagData = {
  list: async (userId: string, groupId: string | null = null): Promise<NoteTag[]> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<NoteTag[]>(
      `SELECT * FROM note_tags WHERE ${ow.sql} ORDER BY name`,
      ow.params
    )
    return rows
  },
  create: async (name: string, userId: string, groupId: string | null = null): Promise<NoteTag> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO note_tags (name, user_id, group_id) VALUES (?, ?, ?)',
      [name, userId, groupId]
    )
    const [rows] = await pool.execute<NoteTag[]>(
      'SELECT * FROM note_tags WHERE id = ?',
      [result.insertId]
    )
    return rows[0]
  },
  remove: async (id: number, userId: string, groupId: string | null = null): Promise<boolean> => {
    await pool.execute('DELETE FROM note_tag_map WHERE tag_id = ?', [id])
    const ow = ownerWhere(userId, groupId)
    const [result] = await pool.execute<ResultSetHeader>(
      `DELETE FROM note_tags WHERE id = ? AND ${ow.sql}`,
      [id, ...ow.params]
    )
    return result.affectedRows > 0
  },
  getTagsForNote: async (noteId: string): Promise<NoteTag[]> => {
    const [rows] = await pool.execute<NoteTag[]>(
      'SELECT t.* FROM note_tags t INNER JOIN note_tag_map m ON t.id = m.tag_id WHERE m.note_id = ? ORDER BY t.name',
      [noteId]
    )
    return rows
  },
  addTagToNote: async (noteId: string, tagId: number): Promise<boolean> => {
    try {
      await pool.execute(
        'INSERT INTO note_tag_map (note_id, tag_id) VALUES (?, ?)',
        [noteId, tagId]
      )
      return true
    } catch (e: unknown) {
      const err = e as { code?: string }
      if (err.code === 'ER_DUP_ENTRY') return false
      throw e
    }
  },
  removeTagFromNote: async (noteId: string, tagId: number): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'DELETE FROM note_tag_map WHERE note_id = ? AND tag_id = ?',
      [noteId, tagId]
    )
    return result.affectedRows > 0
  }
}

export interface DriveFolder extends RowDataPacket {
  id: string
  name: string
  parent_id: string | null
  user_id: string
  created_at: Date
}

export interface DriveFile extends RowDataPacket {
  id: number
  name: string
  oss_key: string
  size: number
  mime_type: string
  folder_id: string | null
  user_id: string
  created_at: Date
}

/** 网盘列表单次查询条数（文件夹、文件各自 LIMIT） */
export const DRIVE_PAGE_SIZE = 30

const createDriveId = () => crypto.randomUUID()

const getDriveSortSql = (sort: 'time' | 'time_desc' | 'name' = 'time_desc') => {
  const sortMap: Record<string, string> = {
    time: 'created_at',
    time_desc: 'created_at DESC',
    name: 'name'
  }

  return sortMap[sort] || 'created_at DESC'
}

export const fileFolderData = {
  getFolderById: async (id: string, userId: string, groupId: string | null = null): Promise<DriveFolder | null> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<DriveFolder[]>(
      `SELECT * FROM drive_folders WHERE id = ? AND ${ow.sql}`,
      [id, ...ow.params]
    )
    return rows[0] ?? null
  },
  createFolder: async (name: string, parentId: string | null, userId: string, groupId: string | null = null): Promise<DriveFolder | null> => {
    const id = createDriveId()
    await pool.execute<ResultSetHeader>(
      'INSERT INTO drive_folders (id, name, parent_id, user_id, group_id) VALUES (?, ?, ?, ?, ?)',
      [id, name, parentId, userId, groupId]
    )
    return await fileFolderData.getFolderById(id, userId, groupId)
  },
  listByParent: async (
    userId: string,
    groupId: string | null,
    parentId: string | null,
    sort: 'time' | 'time_desc' | 'name' = 'name',
    search: string = '',
    offset: number = 0
  ): Promise<DriveFolder[]> => {
    const ow = ownerWhere(userId, groupId)
    let query = `SELECT * FROM drive_folders WHERE ${ow.sql} AND parent_id <=> ?`
    const params: Array<string | number | null> = [...ow.params, parentId]

    if (search.trim() !== '') {
      query += ' AND name LIKE ?'
      params.push(`%${search.trim()}%`)
    }

    query += ` ORDER BY ${getDriveSortSql(sort)} LIMIT ${DRIVE_PAGE_SIZE} OFFSET ?`
    params.push(offset * DRIVE_PAGE_SIZE)

    const [rows] = await pool.execute<DriveFolder[]>(query, params)
    return rows
  },
  searchFolders: async (
    userId: string,
    groupId: string | null,
    search: string,
    sort: 'time' | 'time_desc' | 'name' = 'name',
    offset: number = 0
  ): Promise<DriveFolder[]> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<DriveFolder[]>(
      `SELECT * FROM drive_folders WHERE ${ow.sql} AND name LIKE ? ORDER BY ${getDriveSortSql(sort)} LIMIT ${DRIVE_PAGE_SIZE} OFFSET ?`,
      [...ow.params, `%${search.trim()}%`, offset * DRIVE_PAGE_SIZE]
    )
    return rows
  },
  renameFolder: async (id: string, name: string, userId: string, groupId: string | null = null): Promise<boolean> => {
    const ow = ownerWhere(userId, groupId)
    const [result] = await pool.execute<ResultSetHeader>(
      `UPDATE drive_folders SET name = ? WHERE id = ? AND ${ow.sql}`,
      [name, id, ...ow.params]
    )
    return result.affectedRows > 0
  },
  getBreadcrumbs: async (folderId: string | null, userId: string, groupId: string | null = null): Promise<DriveFolder[]> => {
    if (!folderId) return []
    const breadcrumbs: DriveFolder[] = []
    let currentId: string | null = folderId
    while (currentId) {
      const folder = await fileFolderData.getFolderById(currentId, userId, groupId)
      if (!folder) break
      breadcrumbs.unshift(folder)
      currentId = folder.parent_id
    }
    return breadcrumbs
  }
}

export const fileData = {
  getFileById: async (id: number, userId: string, groupId: string | null = null): Promise<DriveFile | null> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<DriveFile[]>(
      `SELECT * FROM drive_files WHERE id = ? AND ${ow.sql}`,
      [id, ...ow.params]
    )
    return rows[0] ?? null
  },
  addFile: async (
    name: string,
    ossKey: string,
    size: number,
    mimeType: string,
    folderId: string | null,
    userId: string,
    groupId: string | null = null
  ): Promise<DriveFile | null> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO drive_files (name, oss_key, size, mime_type, folder_id, user_id, group_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [name, ossKey, size, mimeType, folderId, userId, groupId]
    )
    return await fileData.getFileById(result.insertId, userId, groupId)
  },
  renameFile: async (id: number, name: string, userId: string, groupId: string | null = null): Promise<boolean> => {
    const ow = ownerWhere(userId, groupId)
    const [result] = await pool.execute<ResultSetHeader>(
      `UPDATE drive_files SET name = ? WHERE id = ? AND ${ow.sql}`,
      [name, id, ...ow.params]
    )
    return result.affectedRows > 0
  },
  listByFolder: async (
    userId: string,
    groupId: string | null,
    folderId: string | null,
    sort: 'time' | 'time_desc' | 'name' = 'time_desc',
    search: string = '',
    offset: number = 0
  ): Promise<DriveFile[]> => {
    const ow = ownerWhere(userId, groupId)
    let query = `SELECT * FROM drive_files WHERE ${ow.sql} AND folder_id <=> ?`
    const params: Array<string | number | null> = [...ow.params, folderId]

    if (search.trim() !== '') {
      query += ' AND name LIKE ?'
      params.push(`%${search.trim()}%`)
    }

    query += ` ORDER BY ${getDriveSortSql(sort)} LIMIT ${DRIVE_PAGE_SIZE} OFFSET ?`
    params.push(offset * DRIVE_PAGE_SIZE)

    const [rows] = await pool.execute<DriveFile[]>(query, params)
    return rows
  },
  searchFiles: async (
    userId: string,
    groupId: string | null,
    search: string,
    offset: number = 0,
    folderId: string | null = null,
    sort: 'time' | 'time_desc' | 'name' = 'time_desc',
    searchAll: boolean = false
  ): Promise<DriveFile[]> => {
    if (searchAll) {
      const ow = ownerWhere(userId, groupId)
      const [rows] = await pool.execute<DriveFile[]>(
        `SELECT * FROM drive_files WHERE ${ow.sql} AND name LIKE ? ORDER BY ${getDriveSortSql(sort)} LIMIT ${DRIVE_PAGE_SIZE} OFFSET ?`,
        [...ow.params, `%${search.trim()}%`, offset * DRIVE_PAGE_SIZE]
      )
      return rows
    }
    return await fileData.listByFolder(userId, groupId, folderId, sort, search, offset)
  }
}

export interface Bookmark extends RowDataPacket {
  id: number
  type: string
  title: string
  description: string
  content: string | null
  url: string
  ref_id: string | null
  user_id: string
  created_at: Date
}

const BOOKMARK_PAGE_SIZE = 30

export const bookmarkData = {
  list: async (
    userId: string,
    groupId: string | null,
    offset: number,
    sort: 'time' | 'time_desc' | 'name' = 'time_desc',
    search: string = '',
    tagId: number | null = null,
    type: string | null = null
  ): Promise<Bookmark[]> => {
    const sortMap: Record<string, string> = {
      time: 'b.created_at',
      time_desc: 'b.created_at DESC',
      name: 'b.title'
    }
    const sortSql = sortMap[sort] || 'b.created_at DESC'
    const ow = ownerWhere(userId, groupId)
    const params: (string | number)[] = [...ow.params]
    let query: string

    if (tagId) {
      query = `SELECT b.* FROM bookmarks b INNER JOIN bookmark_tag_map m ON b.id = m.bookmark_id WHERE b.${ow.sql} AND m.tag_id = ?`
      params.push(tagId)
    } else {
      query = `SELECT b.* FROM bookmarks b WHERE b.${ow.sql}`
    }

    if (type) {
      query += ' AND b.type = ?'
      params.push(type)
    }

    if (search.trim()) {
      query += ' AND (b.title LIKE ? OR b.description LIKE ?)'
      const kw = `%${search.trim()}%`
      params.push(kw, kw)
    }

    query += ` ORDER BY ${sortSql} LIMIT ${BOOKMARK_PAGE_SIZE} OFFSET ?`
    params.push(offset * BOOKMARK_PAGE_SIZE)

    const [rows] = await pool.execute<Bookmark[]>(query, params)
    return rows
  },
  add: async (
    type: string,
    title: string,
    description: string,
    url: string,
    refId: string | null,
    userId: string,
    groupId: string | null = null,
    content: string | null = null
  ): Promise<Bookmark> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO bookmarks (type, title, description, content, url, ref_id, user_id, group_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [type, title, description, content, url, refId, userId, groupId]
    )
    const [rows] = await pool.execute<Bookmark[]>(
      'SELECT * FROM bookmarks WHERE id = ?',
      [result.insertId]
    )
    return rows[0]
  },
  getById: async (id: number, userId: string, groupId: string | null = null): Promise<Bookmark | null> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<Bookmark[]>(
      `SELECT * FROM bookmarks WHERE id = ? AND ${ow.sql}`,
      [id, ...ow.params]
    )
    return rows[0] ?? null
  },
  remove: async (id: number, userId: string, groupId: string | null = null): Promise<boolean> => {
    await pool.execute('DELETE FROM bookmark_tag_map WHERE bookmark_id = ?', [id])
    const ow = ownerWhere(userId, groupId)
    const [result] = await pool.execute<ResultSetHeader>(
      `DELETE FROM bookmarks WHERE id = ? AND ${ow.sql}`,
      [id, ...ow.params]
    )
    return result.affectedRows > 0
  },
  findByRef: async (userId: string, groupId: string | null, type: string, refId: string): Promise<Bookmark | null> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<Bookmark[]>(
      `SELECT * FROM bookmarks WHERE ${ow.sql} AND type = ? AND ref_id = ?`,
      [...ow.params, type, refId]
    )
    return rows[0] ?? null
  },
  findByUrl: async (userId: string, groupId: string | null, url: string): Promise<Bookmark | null> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<Bookmark[]>(
      `SELECT * FROM bookmarks WHERE ${ow.sql} AND type = ? AND url = ?`,
      [...ow.params, 'url', url]
    )
    return rows[0] ?? null
  }
}

export interface BookmarkTag extends RowDataPacket {
  id: number
  name: string
  user_id: string
  created_at: Date
}

export const bookmarkTagData = {
  list: async (userId: string, groupId: string | null = null): Promise<BookmarkTag[]> => {
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<BookmarkTag[]>(
      `SELECT * FROM bookmark_tags WHERE ${ow.sql} ORDER BY name`,
      ow.params
    )
    return rows
  },
  create: async (name: string, userId: string, groupId: string | null = null): Promise<BookmarkTag> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO bookmark_tags (name, user_id, group_id) VALUES (?, ?, ?)',
      [name, userId, groupId]
    )
    const [rows] = await pool.execute<BookmarkTag[]>(
      'SELECT * FROM bookmark_tags WHERE id = ?',
      [result.insertId]
    )
    return rows[0]
  },
  remove: async (id: number, userId: string, groupId: string | null = null): Promise<boolean> => {
    await pool.execute('DELETE FROM bookmark_tag_map WHERE tag_id = ?', [id])
    const ow = ownerWhere(userId, groupId)
    const [result] = await pool.execute<ResultSetHeader>(
      `DELETE FROM bookmark_tags WHERE id = ? AND ${ow.sql}`,
      [id, ...ow.params]
    )
    return result.affectedRows > 0
  },
  getTagsForBookmark: async (bookmarkId: number): Promise<BookmarkTag[]> => {
    const [rows] = await pool.execute<BookmarkTag[]>(
      'SELECT t.* FROM bookmark_tags t INNER JOIN bookmark_tag_map m ON t.id = m.tag_id WHERE m.bookmark_id = ? ORDER BY t.name',
      [bookmarkId]
    )
    return rows
  },
  addTagToBookmark: async (bookmarkId: number, tagId: number): Promise<boolean> => {
    try {
      await pool.execute(
        'INSERT INTO bookmark_tag_map (bookmark_id, tag_id) VALUES (?, ?)',
        [bookmarkId, tagId]
      )
      return true
    } catch (e: unknown) {
      const err = e as { code?: string }
      if (err.code === 'ER_DUP_ENTRY') return false
      throw e
    }
  },
  removeTagFromBookmark: async (bookmarkId: number, tagId: number): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'DELETE FROM bookmark_tag_map WHERE bookmark_id = ? AND tag_id = ?',
      [bookmarkId, tagId]
    )
    return result.affectedRows > 0
  }
}

export interface UserSetting extends RowDataPacket {
  user_id: string
  k: string
  v: string
}

export const settingData = {
  getAll: async (userId: string): Promise<Record<string, string>> => {
    const [rows] = await pool.execute<UserSetting[]>(
      'SELECT k, v FROM user_settings WHERE user_id = ?',
      [userId]
    )
    const result: Record<string, string> = {}
    for (const row of rows) {
      result[row.k] = row.v
    }
    return result
  },
  set: async (userId: string, key: string, value: string): Promise<void> => {
    await pool.execute(
      'INSERT INTO user_settings (user_id, k, v) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)',
      [userId, key, value]
    )
  },
  remove: async (userId: string, key: string): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'DELETE FROM user_settings WHERE user_id = ? AND k = ?',
      [userId, key]
    )
    return result.affectedRows > 0
  }
}

export interface UsageStats {
  notes_count: number
  bookmarks_count: number
  images_count: number
  images_size: number
  files_count: number
  files_size: number
}

const STAT_KEYS = [
  'stat_notes_count',
  'stat_bookmarks_count',
  'stat_images_count',
  'stat_images_size',
  'stat_files_count',
  'stat_files_size',
] as const

export const usageStatsData = {
  recalculate: async (userId: string, groupId: string | null = null): Promise<UsageStats> => {
    const ow = ownerWhere(userId, groupId)
    const [[notes], [bookmarks], [images], [files]] = await Promise.all([
      pool.execute<RowDataPacket[]>(`SELECT COUNT(*) AS cnt FROM notes WHERE ${ow.sql}`, ow.params),
      pool.execute<RowDataPacket[]>(`SELECT COUNT(*) AS cnt FROM bookmarks WHERE ${ow.sql}`, ow.params),
      pool.execute<RowDataPacket[]>(`SELECT COUNT(*) AS cnt, COALESCE(SUM(size), 0) AS total_size FROM images WHERE ${ow.sql}`, ow.params),
      pool.execute<RowDataPacket[]>(`SELECT COUNT(*) AS cnt, COALESCE(SUM(size), 0) AS total_size FROM drive_files WHERE ${ow.sql}`, ow.params),
    ])

    const stats: UsageStats = {
      notes_count: Number(notes[0].cnt),
      bookmarks_count: Number(bookmarks[0].cnt),
      images_count: Number(images[0].cnt),
      images_size: Number(images[0].total_size),
      files_count: Number(files[0].cnt),
      files_size: Number(files[0].total_size),
    }

    const settingsOwner = groupId ?? userId
    await Promise.all(STAT_KEYS.map(k =>
      settingData.set(settingsOwner, k, String(stats[k.replace('stat_', '') as keyof UsageStats]))
    ))

    return stats
  },

  get: async (userId: string, groupId: string | null = null): Promise<UsageStats> => {
    const settingsOwner = groupId ?? userId
    const [rows] = await pool.execute<UserSetting[]>(
      `SELECT k, v FROM user_settings WHERE user_id = ? AND k IN (${STAT_KEYS.map(() => '?').join(',')})`,
      [settingsOwner, ...STAT_KEYS]
    )

    if (rows.length === 0) {
      return await usageStatsData.recalculate(userId, groupId)
    }

    const map: Record<string, string> = {}
    for (const row of rows) map[row.k] = row.v

    return {
      notes_count: Number(map.stat_notes_count || 0),
      bookmarks_count: Number(map.stat_bookmarks_count || 0),
      images_count: Number(map.stat_images_count || 0),
      images_size: Number(map.stat_images_size || 0),
      files_count: Number(map.stat_files_count || 0),
      files_size: Number(map.stat_files_size || 0),
    }
  },

  increment: async (userId: string, groupId: string | null, key: typeof STAT_KEYS[number], delta: number): Promise<void> => {
    const settingsOwner = groupId ?? userId
    await pool.execute(
      'INSERT INTO user_settings (user_id, k, v) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE v = CAST(CAST(v AS SIGNED) + ? AS CHAR)',
      [settingsOwner, key, String(delta), delta]
    )
  },
}

export interface TimelineItem extends RowDataPacket {
  type: 'note' | 'image' | 'file' | 'bookmark'
  id: string
  name: string
  summary: string
  url: string | null
  size: number
  created_at: Date
  bookmark_subtype: 'url' | 'image' | 'note' | 'file' | null
  ref_id: string | null
}

const TIMELINE_PAGE_SIZE = 30

export const timelineData = {
  getTimeline: async (userId: string, groupId: string | null, offset: number): Promise<TimelineItem[]> => {
    const C = 'COLLATE utf8mb4_unicode_ci'
    const cap = offset * TIMELINE_PAGE_SIZE + TIMELINE_PAGE_SIZE
    const ow = ownerWhere(userId, groupId)
    const [rows] = await pool.execute<TimelineItem[]>(
      `(SELECT 'note' ${C} AS type, id ${C} AS id, title ${C} AS name, LEFT(content, 100) ${C} AS summary, NULL AS url, 0 AS size, created_at, NULL AS bookmark_subtype, NULL AS ref_id
        FROM notes WHERE ${ow.sql} ORDER BY created_at DESC LIMIT ${cap})
       UNION ALL
       (SELECT 'image' ${C} AS type, CAST(id AS CHAR) ${C} AS id, name ${C} AS name, '' ${C} AS summary, url ${C} AS url, size, created_at, NULL AS bookmark_subtype, NULL AS ref_id
        FROM images WHERE ${ow.sql} ORDER BY created_at DESC LIMIT ${cap})
       UNION ALL
       (SELECT 'file' ${C} AS type, CAST(id AS CHAR) ${C} AS id, name ${C} AS name, mime_type ${C} AS summary, oss_key ${C} AS url, size, created_at, NULL AS bookmark_subtype, NULL AS ref_id
        FROM drive_files WHERE ${ow.sql} ORDER BY created_at DESC LIMIT ${cap})
       UNION ALL
       (SELECT 'bookmark' ${C} AS type, CAST(b.id AS CHAR) ${C} AS id, b.title ${C} AS name, LEFT(COALESCE(b.description, ''), 100) ${C} AS summary, b.url ${C} AS url, 0 AS size, b.created_at, b.type ${C} AS bookmark_subtype, b.ref_id ${C} AS ref_id
        FROM bookmarks b WHERE b.${ow.sql} ORDER BY created_at DESC LIMIT ${cap})
       ORDER BY created_at DESC
       LIMIT ${TIMELINE_PAGE_SIZE} OFFSET ${offset * TIMELINE_PAGE_SIZE}`,
      [...ow.params, ...ow.params, ...ow.params, ...ow.params]
    )
    return rows
  }
}

// ─── Group helpers ───

export interface Group extends RowDataPacket {
  id: string
  name: string
  description: string
  created_by: string
  created_at: Date
  updated_at: Date
}

export interface GroupMember extends RowDataPacket {
  group_id: string
  user_id: string
  role: 'owner' | 'admin' | 'editor' | 'viewer'
  joined_at: Date
  user_name?: string
  user_email?: string
}

export interface GroupInvite extends RowDataPacket {
  id: string
  group_id: string
  invite_code: string | null
  invited_user_id: string | null
  role: 'admin' | 'editor' | 'viewer'
  created_by: string
  created_at: Date
  expires_at: Date | null
  used_at: Date | null
}

export const groupData = {
  create: async (id: string, name: string, description: string, createdBy: string): Promise<Group> => {
    await pool.execute<ResultSetHeader>(
      'INSERT INTO `groups` (id, name, description, created_by) VALUES (?, ?, ?, ?)',
      [id, name, description, createdBy]
    )
    const [rows] = await pool.execute<Group[]>('SELECT * FROM `groups` WHERE id = ?', [id])
    return rows[0]
  },
  getById: async (id: string): Promise<Group | null> => {
    const [rows] = await pool.execute<Group[]>('SELECT * FROM `groups` WHERE id = ?', [id])
    return rows[0] ?? null
  },
  listByUser: async (userId: string): Promise<(Group & { role: string; meta: Record<string, unknown> })[]> => {
    const [rows] = await pool.execute<(Group & { role: string } & RowDataPacket)[]>(
      'SELECT g.*, gm.role FROM `groups` g INNER JOIN group_members gm ON g.id = gm.group_id WHERE gm.user_id = ? ORDER BY g.updated_at DESC',
      [userId]
    )
    return rows.map(r => ({ ...r, meta: parseMeta(r.meta) }))
  },
  update: async (id: string, name: string, description: string): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'UPDATE `groups` SET name = ?, description = ? WHERE id = ?',
      [name, description, id]
    )
    return result.affectedRows > 0
  },
  remove: async (id: string): Promise<boolean> => {
    await pool.execute('DELETE FROM group_chat_messages WHERE group_id = ?', [id])
    await pool.execute('DELETE FROM group_members WHERE group_id = ?', [id])
    await pool.execute('DELETE FROM group_invites WHERE group_id = ?', [id])
    const [result] = await pool.execute<ResultSetHeader>('DELETE FROM `groups` WHERE id = ?', [id])
    return result.affectedRows > 0
  },
  getMeta: async (id: string): Promise<Record<string, unknown>> => {
    const [rows] = await pool.execute<RowDataPacket[]>(
      'SELECT meta FROM `groups` WHERE id = ?', [id]
    )
    return parseMeta(rows[0]?.meta)
  },
  updateMeta: async (id: string, meta: Record<string, unknown>): Promise<void> => {
    await pool.execute('UPDATE `groups` SET meta = ? WHERE id = ?', [JSON.stringify(meta), id])
  },
}

export const groupMemberData = {
  add: async (groupId: string, userId: string, role: string): Promise<void> => {
    await pool.execute(
      'INSERT INTO group_members (group_id, user_id, role) VALUES (?, ?, ?)',
      [groupId, userId, role]
    )
  },
  remove: async (groupId: string, userId: string): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'DELETE FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId]
    )
    return result.affectedRows > 0
  },
  getMembership: async (groupId: string, userId: string): Promise<GroupMember | null> => {
    const [rows] = await pool.execute<GroupMember[]>(
      'SELECT * FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId]
    )
    return rows[0] ?? null
  },
  listMembers: async (groupId: string): Promise<GroupMember[]> => {
    const [rows] = await pool.execute<GroupMember[]>(
      `SELECT gm.*, u.name AS user_name, u.email AS user_email, u.meta AS user_meta
       FROM group_members gm INNER JOIN users u ON gm.user_id = u.id
       WHERE gm.group_id = ? ORDER BY FIELD(gm.role,'owner','admin','editor','viewer'), gm.joined_at`,
      [groupId]
    )
    return rows.map(r => ({ ...r, user_meta: parseMeta((r as any).user_meta) }))
  },
  updateRole: async (groupId: string, userId: string, role: string): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'UPDATE group_members SET role = ? WHERE group_id = ? AND user_id = ?',
      [role, groupId, userId]
    )
    return result.affectedRows > 0
  },
}

export interface GroupChatMessageRow extends RowDataPacket {
  id: string
  group_id: string
  user_id: string
  content: string
  created_at: Date
  user_name?: string
  user_meta?: unknown
}

export type GroupChatMessageWithAvatar = {
  id: string
  group_id: string
  user_id: string
  content: string
  created_at: Date
  user_name?: string
  user_avatar: string
}

function chatRowWithAvatar(raw: GroupChatMessageRow): GroupChatMessageWithAvatar {
  const meta = parseMeta(raw.user_meta)
  const av = meta.avatar
  const user_avatar = typeof av === 'string' ? av : ''
  return {
    id: raw.id,
    group_id: raw.group_id,
    user_id: raw.user_id,
    content: raw.content,
    created_at: raw.created_at,
    user_name: raw.user_name,
    user_avatar,
  }
}

export const groupChatData = {
  insert: async (id: string, groupId: string, userId: string, content: string): Promise<GroupChatMessageWithAvatar> => {
    await pool.execute<ResultSetHeader>(
      'INSERT INTO group_chat_messages (id, group_id, user_id, content) VALUES (?, ?, ?, ?)',
      [id, groupId, userId, content]
    )
    const [rows] = await pool.execute<GroupChatMessageRow[]>(
      `SELECT m.*, u.name AS user_name, u.meta AS user_meta FROM group_chat_messages m
       INNER JOIN users u ON m.user_id = u.id WHERE m.id = ?`,
      [id]
    )
    return chatRowWithAvatar(rows[0])
  },
  list: async (groupId: string, opts: { beforeId: string | null; limit: number }): Promise<GroupChatMessageWithAvatar[]> => {
    const limit = Math.min(Math.max(opts.limit, 1), 100)
    if (opts.beforeId) {
      const [rows] = await pool.execute<GroupChatMessageRow[]>(
        `SELECT m.*, u.name AS user_name, u.meta AS user_meta FROM group_chat_messages m
         INNER JOIN users u ON m.user_id = u.id
         WHERE m.group_id = ? AND m.created_at < (SELECT created_at FROM group_chat_messages WHERE id = ? AND group_id = ?)
         ORDER BY m.created_at DESC LIMIT ?`,
        [groupId, opts.beforeId, groupId, limit]
      )
      return rows.reverse().map(chatRowWithAvatar)
    }
    const [rows] = await pool.execute<GroupChatMessageRow[]>(
      `SELECT m.*, u.name AS user_name, u.meta AS user_meta FROM group_chat_messages m
       INNER JOIN users u ON m.user_id = u.id
       WHERE m.group_id = ?
       ORDER BY m.created_at DESC LIMIT ?`,
      [groupId, limit]
    )
    return rows.reverse().map(chatRowWithAvatar)
  },
}

export const groupInviteData = {
  createLinkInvite: async (
    id: string, groupId: string, inviteCode: string, role: string, createdBy: string, expiresAt: Date | null
  ): Promise<GroupInvite> => {
    await pool.execute<ResultSetHeader>(
      'INSERT INTO group_invites (id, group_id, invite_code, role, created_by, expires_at) VALUES (?, ?, ?, ?, ?, ?)',
      [id, groupId, inviteCode, role, createdBy, expiresAt]
    )
    const [rows] = await pool.execute<GroupInvite[]>('SELECT * FROM group_invites WHERE id = ?', [id])
    return rows[0]
  },
  createDirectInvite: async (
    id: string, groupId: string, invitedUserId: string, role: string, createdBy: string
  ): Promise<GroupInvite> => {
    await pool.execute<ResultSetHeader>(
      'INSERT INTO group_invites (id, group_id, invited_user_id, role, created_by) VALUES (?, ?, ?, ?, ?)',
      [id, groupId, invitedUserId, role, createdBy]
    )
    const [rows] = await pool.execute<GroupInvite[]>('SELECT * FROM group_invites WHERE id = ?', [id])
    return rows[0]
  },
  getByCode: async (code: string): Promise<GroupInvite | null> => {
    const [rows] = await pool.execute<GroupInvite[]>(
      'SELECT * FROM group_invites WHERE invite_code = ? AND used_at IS NULL',
      [code]
    )
    return rows[0] ?? null
  },
  getDirectInvite: async (groupId: string, userId: string): Promise<GroupInvite | null> => {
    const [rows] = await pool.execute<GroupInvite[]>(
      'SELECT * FROM group_invites WHERE group_id = ? AND invited_user_id = ? AND used_at IS NULL',
      [groupId, userId]
    )
    return rows[0] ?? null
  },
  markUsed: async (id: string): Promise<void> => {
    await pool.execute('UPDATE group_invites SET used_at = NOW() WHERE id = ?', [id])
  },
  listPending: async (groupId: string): Promise<GroupInvite[]> => {
    const [rows] = await pool.execute<GroupInvite[]>(
      'SELECT * FROM group_invites WHERE group_id = ? AND used_at IS NULL ORDER BY created_at DESC',
      [groupId]
    )
    return rows
  },
  listForUser: async (userId: string): Promise<(GroupInvite & { group_name: string })[]> => {
    const [rows] = await pool.execute<(GroupInvite & { group_name: string } & RowDataPacket)[]>(
      `SELECT gi.*, g.name AS group_name FROM group_invites gi
       INNER JOIN \`groups\` g ON gi.group_id = g.id
       WHERE gi.invited_user_id = ? AND gi.used_at IS NULL ORDER BY gi.created_at DESC`,
      [userId]
    )
    return rows
  },
  listLinkInvites: async (groupId: string): Promise<GroupInvite[]> => {
    const [rows] = await pool.execute<GroupInvite[]>(
      'SELECT * FROM group_invites WHERE group_id = ? AND invite_code IS NOT NULL ORDER BY created_at DESC',
      [groupId]
    )
    return rows
  },
  getById: async (id: string): Promise<GroupInvite | null> => {
    const [rows] = await pool.execute<GroupInvite[]>('SELECT * FROM group_invites WHERE id = ?', [id])
    return rows[0] ?? null
  },
  remove: async (id: string): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>('DELETE FROM group_invites WHERE id = ?', [id])
    return result.affectedRows > 0
  },
}