import { pool } from '../database.js'

// 笔记相关的数据库操作
export const noteData = {
  // 获取笔记列表
  getNotes: async (userId: string, offset: number) => {
    try {
      const [rows] = await pool.execute(
        'SELECT id,title,LEFT(content,100) AS content,created_at,updated_at FROM notes WHERE user_id = ? ORDER BY updated_at DESC limit 30 offset ?',
        [userId,offset*30]
      )
      return rows as any[]
    } catch (error) {
      console.error('获取笔记列表失败:', error)
      throw error
    }
  },

  // 获取笔记详情
  getNoteById: async (id: string, userId: string) => {
    try {
      const [rows] = await pool.execute(
        'SELECT * FROM notes WHERE id = ? AND user_id = ?',
        [id, userId]
      )
      const notes = rows as any[]
      return notes.length > 0 ? notes[0] : null
    } catch (error) {
      console.error('获取笔记详情失败:', error)
      throw error
    }
  },

  // 创建笔记
  createNote: async (title: string, content: string, userId: string) => {
    try {
      const id = Date.now().toString()
      const [result] = await pool.execute(
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
  updateNote: async (id: string, title: string, content: string, userId: string) => {
    try {
      const [result] = await pool.execute(
        'UPDATE notes SET title = ?, content = ? WHERE id = ? AND user_id = ?',
        [title, content, id, userId]
      )
      
      // 检查是否更新成功
      const affectedRows = (result as any).affectedRows
      if (affectedRows === 0) {
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
  deleteNote: async (id: string, userId: string) => {
    try {
      const [result] = await pool.execute(
        'DELETE FROM notes WHERE id = ? AND user_id = ?',
        [id, userId]
      )
      
      const affectedRows = (result as any).affectedRows
      return affectedRows > 0
    } catch (error) {
      console.error('删除笔记失败:', error)
      throw error
    }
  }
}

export const imageData = {
  getImageList: async (userId: string, offset: number, sort: 'time' | 'time_desc' | 'name' = 'time_desc', search: string = '') => {
    let sort_sql = ''
    switch(sort){
      case 'time':
        sort_sql = 'created_at'
        break
      case 'time_desc':
        sort_sql = 'created_at DESC'
        break
      case 'name':
        sort_sql = 'name'
        break
    }
    let search_sql = ''
    if(search && search != ''){
      search_sql = `AND name LIKE '%${search}%'`
    }
    const [rows] = await pool.execute(
      `SELECT * FROM images WHERE user_id = ? ${search_sql} ORDER BY ${sort_sql} limit 30 offset ?`,
      [userId, offset*30]
    )
    return rows as any[]
  },
  addImage: async (name: string, url: string,size:number, userId: string, remark: string) => {
    const [result] = await pool.execute(
      'INSERT INTO images (name, url, size, user_id, remark) VALUES (?, ?, ?, ?, ?)',
      [name, url, size, userId, remark]
    )
    return result as any
  }
}