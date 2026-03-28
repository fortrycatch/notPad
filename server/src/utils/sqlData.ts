import { pool } from '../database.js'
import type { RowDataPacket, ResultSetHeader } from 'mysql2'
import crypto from 'node:crypto'
// 笔记接口定义
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

// 笔记相关的数据库操作
export const noteData = {
  // 获取笔记列表
  getNotes: async (userId: string, offset: number): Promise<NoteListItem[]> => {
    try {
      const [rows] = await pool.execute<NoteListItem[]>(
        'SELECT id,title,LEFT(content,100) AS content,created_at,updated_at FROM notes WHERE user_id = ? ORDER BY updated_at DESC limit 30 offset ?',
        [userId,offset*30]
      )
      return rows
    } catch (error) {
      console.error('获取笔记列表失败:', error)
      throw error
    }
  },

  // 获取笔记详情
  getNoteById: async (id: string, userId: string): Promise<Note | null> => {
    try {
      const [rows] = await pool.execute<Note[]>(
        'SELECT * FROM notes WHERE id = ? AND user_id = ?',
        [id, userId]
      )
      return rows.length > 0 ? rows[0] : null
    } catch (error) {
      console.error('获取笔记详情失败:', error)
      throw error
    }
  },

  // 创建笔记
  createNote: async (title: string, content: string, userId: string): Promise<Note | null> => {
    try {
      // 使用时间戳作为ID，如果需要更好的唯一性，可以考虑使用 crypto.randomUUID()
      const id = crypto.hash('sha1',userId+Date.now().toString()+crypto.randomUUID()).slice(0,36)
      await pool.execute<ResultSetHeader>(
        'INSERT INTO notes (id, title, content, user_id) VALUES (?, ?, ?, ?)',
        [id, title, content, userId]
      )
      
      // 返回创建的笔记
      return await noteData.getNoteById(id, userId)
    } catch (error) {
      console.error('创建笔记失败:', error)
      throw error
    }
  },

  // 更新笔记
  updateNote: async (id: string, title: string, content: string, userId: string): Promise<Note | null> => {
    try {
      const [result] = await pool.execute<ResultSetHeader>(
        'UPDATE notes SET title = ?, content = ? WHERE id = ? AND user_id = ?',
        [title, content, id, userId]
      )
      
      // 检查是否更新成功
      if (result.affectedRows === 0) {
        return null
      }
      
      // 返回更新后的笔记
      return await noteData.getNoteById(id, userId)
    } catch (error) {
      console.error('更新笔记失败:', error)
      throw error
    }
  },

  // 删除笔记
  deleteNote: async (id: string, userId: string): Promise<boolean> => {
    try {
      const [result] = await pool.execute<ResultSetHeader>(
        'DELETE FROM notes WHERE id = ? AND user_id = ?',
        [id, userId]
      )
      
      return result.affectedRows > 0
    } catch (error) {
      console.error('删除笔记失败:', error)
      throw error
    }
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
  }
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
  getImageList: async (userId: string, offset: number, sort: 'time' | 'time_desc' | 'name' = 'time_desc', search: string = '', tagId: number | null = null): Promise<Image[]> => {
    const sortMap: Record<string, string> = {
      'time': 'i.created_at',
      'time_desc': 'i.created_at DESC',
      'name': 'i.name'
    }
    const sortSql = sortMap[sort] || 'i.created_at DESC'

    let query: string
    const params: (string | number)[] = [userId]

    if (tagId) {
      query = 'SELECT i.* FROM images i INNER JOIN image_tag_map m ON i.id = m.image_id WHERE i.user_id = ? AND m.tag_id = ?'
      params.push(tagId)
    } else {
      query = 'SELECT i.* FROM images i WHERE i.user_id = ?'
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
  addImage: async (name: string, url: string, size: number, userId: string, remark: string): Promise<ResultSetHeader> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO images (name, url, size, user_id, remark) VALUES (?, ?, ?, ?, ?)',
      [name, url, size, userId, remark]
    )
    return result
  },
  renameImage: async (id: number, name: string, userId: string): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'UPDATE images SET name = ? WHERE id = ? AND user_id = ?',
      [name, id, userId]
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
  list: async (userId: string): Promise<ImageTag[]> => {
    const [rows] = await pool.execute<ImageTag[]>(
      'SELECT * FROM image_tags WHERE user_id = ? ORDER BY name',
      [userId]
    )
    return rows
  },
  create: async (name: string, userId: string): Promise<ImageTag> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO image_tags (name, user_id) VALUES (?, ?)',
      [name, userId]
    )
    const [rows] = await pool.execute<ImageTag[]>(
      'SELECT * FROM image_tags WHERE id = ?',
      [result.insertId]
    )
    return rows[0]
  },
  remove: async (id: number, userId: string): Promise<boolean> => {
    await pool.execute('DELETE FROM image_tag_map WHERE tag_id = ?', [id])
    const [result] = await pool.execute<ResultSetHeader>(
      'DELETE FROM image_tags WHERE id = ? AND user_id = ?',
      [id, userId]
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
  getFolderById: async (id: string, userId: string): Promise<DriveFolder | null> => {
    try {
      const [rows] = await pool.execute<DriveFolder[]>(
        'SELECT * FROM drive_folders WHERE id = ? AND user_id = ?',
        [id, userId]
      )
      return rows.length > 0 ? rows[0] : null
    } catch (error) {
      console.error('获取网盘文件夹失败:', error)
      throw error
    }
  },
  createFolder: async (name: string, parentId: string | null, userId: string): Promise<DriveFolder | null> => {
    try {
      const id = createDriveId()
      await pool.execute<ResultSetHeader>(
        'INSERT INTO drive_folders (id, name, parent_id, user_id) VALUES (?, ?, ?, ?)',
        [id, name, parentId, userId]
      )
      return await fileFolderData.getFolderById(id, userId)
    } catch (error) {
      console.error('创建网盘文件夹失败:', error)
      throw error
    }
  },
  listByParent: async (
    userId: string,
    parentId: string | null,
    sort: 'time' | 'time_desc' | 'name' = 'name',
    search: string = '',
    offset: number = 0
  ): Promise<DriveFolder[]> => {
    try {
      let query = 'SELECT * FROM drive_folders WHERE user_id = ? AND parent_id <=> ?'
      const params: Array<string | number | null> = [userId, parentId]

      if (search.trim() !== '') {
        query += ' AND name LIKE ?'
        params.push(`%${search.trim()}%`)
      }

      query += ` ORDER BY ${getDriveSortSql(sort)} LIMIT ${DRIVE_PAGE_SIZE} OFFSET ?`
      params.push(offset * DRIVE_PAGE_SIZE)

      const [rows] = await pool.execute<DriveFolder[]>(query, params)
      return rows
    } catch (error) {
      console.error('获取网盘文件夹列表失败:', error)
      throw error
    }
  },
  searchFolders: async (
    userId: string,
    search: string,
    sort: 'time' | 'time_desc' | 'name' = 'name',
    offset: number = 0
  ): Promise<DriveFolder[]> => {
    try {
      const [rows] = await pool.execute<DriveFolder[]>(
        `SELECT * FROM drive_folders WHERE user_id = ? AND name LIKE ? ORDER BY ${getDriveSortSql(sort)} LIMIT ${DRIVE_PAGE_SIZE} OFFSET ?`,
        [userId, `%${search.trim()}%`, offset * DRIVE_PAGE_SIZE]
      )
      return rows
    } catch (error) {
      console.error('全局搜索网盘文件夹失败:', error)
      throw error
    }
  },
  renameFolder: async (id: string, name: string, userId: string): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'UPDATE drive_folders SET name = ? WHERE id = ? AND user_id = ?',
      [name, id, userId]
    )
    return result.affectedRows > 0
  },
  getBreadcrumbs: async (folderId: string | null, userId: string): Promise<DriveFolder[]> => {
    try {
      if (!folderId) return []

      const breadcrumbs: DriveFolder[] = []
      let currentId: string | null = folderId

      while (currentId) {
        const folder = await fileFolderData.getFolderById(currentId, userId)
        if (!folder) break
        breadcrumbs.unshift(folder)
        currentId = folder.parent_id
      }

      return breadcrumbs
    } catch (error) {
      console.error('获取网盘面包屑失败:', error)
      throw error
    }
  }
}

export const fileData = {
  getFileById: async (id: number, userId: string): Promise<DriveFile | null> => {
    try {
      const [rows] = await pool.execute<DriveFile[]>(
        'SELECT * FROM drive_files WHERE id = ? AND user_id = ?',
        [id, userId]
      )
      return rows.length > 0 ? rows[0] : null
    } catch (error) {
      console.error('获取网盘文件失败:', error)
      throw error
    }
  },
  addFile: async (
    name: string,
    ossKey: string,
    size: number,
    mimeType: string,
    folderId: string | null,
    userId: string
  ): Promise<DriveFile | null> => {
    try {
      const [result] = await pool.execute<ResultSetHeader>(
        'INSERT INTO drive_files (name, oss_key, size, mime_type, folder_id, user_id) VALUES (?, ?, ?, ?, ?, ?)',
        [name, ossKey, size, mimeType, folderId, userId]
      )
      return await fileData.getFileById(result.insertId, userId)
    } catch (error) {
      console.error('添加网盘文件失败:', error)
      throw error
    }
  },
  renameFile: async (id: number, name: string, userId: string): Promise<boolean> => {
    const [result] = await pool.execute<ResultSetHeader>(
      'UPDATE drive_files SET name = ? WHERE id = ? AND user_id = ?',
      [name, id, userId]
    )
    return result.affectedRows > 0
  },
  listByFolder: async (
    userId: string,
    folderId: string | null,
    sort: 'time' | 'time_desc' | 'name' = 'time_desc',
    search: string = '',
    offset: number = 0
  ): Promise<DriveFile[]> => {
    try {
      let query = 'SELECT * FROM drive_files WHERE user_id = ? AND folder_id <=> ?'
      const params: Array<string | number | null> = [userId, folderId]

      if (search.trim() !== '') {
        query += ' AND name LIKE ?'
        params.push(`%${search.trim()}%`)
      }

      query += ` ORDER BY ${getDriveSortSql(sort)} LIMIT ${DRIVE_PAGE_SIZE} OFFSET ?`
      params.push(offset * DRIVE_PAGE_SIZE)

      const [rows] = await pool.execute<DriveFile[]>(query, params)
      return rows
    } catch (error) {
      console.error('获取网盘文件列表失败:', error)
      throw error
    }
  },
  searchFiles: async (
    userId: string,
    search: string,
    offset: number = 0,
    folderId: string | null = null,
    sort: 'time' | 'time_desc' | 'name' = 'time_desc',
    searchAll: boolean = false
  ): Promise<DriveFile[]> => {
    try {
      if (searchAll) {
        const [rows] = await pool.execute<DriveFile[]>(
          `SELECT * FROM drive_files WHERE user_id = ? AND name LIKE ? ORDER BY ${getDriveSortSql(sort)} LIMIT ${DRIVE_PAGE_SIZE} OFFSET ?`,
          [userId, `%${search.trim()}%`, offset * DRIVE_PAGE_SIZE]
        )
        return rows
      }

      return await fileData.listByFolder(userId, folderId, sort, search, offset)
    } catch (error) {
      console.error('搜索网盘文件失败:', error)
      throw error
    }
  }
}

export interface TimelineItem extends RowDataPacket {
  type: 'note' | 'image' | 'file'
  id: string
  name: string
  summary: string
  url: string | null
  size: number
  created_at: Date
}

const TIMELINE_PAGE_SIZE = 30

export const timelineData = {
  getTimeline: async (userId: string, offset: number): Promise<TimelineItem[]> => {
    const CI = 'COLLATE utf8mb4_unicode_ci'
    const [rows] = await pool.execute<TimelineItem[]>(
      `SELECT 'note' ${CI} AS type, id, title AS name, LEFT(content, 100) AS summary, NULL AS url, 0 AS size, created_at
       FROM notes WHERE user_id = ?
       UNION ALL
       SELECT 'image' ${CI}, CAST(id AS CHAR) ${CI}, name, '' ${CI} AS summary, url, size, created_at
       FROM images WHERE user_id = ?
       UNION ALL
       SELECT 'file' ${CI}, CAST(id AS CHAR) ${CI}, name, mime_type AS summary, oss_key AS url, size, created_at
       FROM drive_files WHERE user_id = ?
       ORDER BY created_at DESC
       LIMIT ${TIMELINE_PAGE_SIZE} OFFSET ?`,
      [userId, userId, userId, offset * TIMELINE_PAGE_SIZE]
    )
    return rows
  }
}