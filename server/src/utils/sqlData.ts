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
}
export const tokenData = {
  //用户操作凭据
  createToken: async (user_id: string): Promise<string> => {
    try {
      //生成随机加盐的token
      const token = crypto.randomBytes(32).toString('base64')
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex')
      await pool.execute<ResultSetHeader>(
        'INSERT INTO tokens (user_id, token) VALUES (?, ?)',
        [user_id, tokenHash]
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
  }
}
export const imageData = {
  getImageList: async (userId: string, offset: number, sort: 'time' | 'time_desc' | 'name' = 'time_desc', search: string = ''): Promise<Image[]> => {
    try {
      // 安全的排序字段映射，防止SQL注入
      const sortMap: Record<string, string> = {
        'time': 'created_at',
        'time_desc': 'created_at DESC',
        'name': 'name'
      }
      const sort_sql = sortMap[sort] || 'created_at DESC'
      
      // 使用参数化查询防止SQL注入
      let query = 'SELECT * FROM images WHERE user_id = ?'
      const params: (string | number)[] = [userId]
      
      if(search && search.trim() !== ''){
        query += ' AND name LIKE ?'
        params.push(`%${search.trim()}%`)
      }
      
      query += ` ORDER BY ${sort_sql} LIMIT 30 OFFSET ?`
      params.push(offset * 30)
      
      const [rows] = await pool.execute<Image[]>(query, params)
      return rows
    } catch (error) {
      console.error('获取图片列表失败:', error)
      throw error
    }
  },
  addImage: async (name: string, url: string, size: number, userId: string, remark: string): Promise<ResultSetHeader> => {
    try {
      const [result] = await pool.execute<ResultSetHeader>(
        'INSERT INTO images (name, url, size, user_id, remark) VALUES (?, ?, ?, ?, ?)',
        [name, url, size, userId, remark]
      )
      return result
    } catch (error) {
      console.error('添加图片失败:', error)
      throw error
    }
  }
}