import mysql from 'mysql2/promise'
import dotenv from 'dotenv'
import config from './config.js'
console.log(process.env.NODE_ENV)
// 加载环境变量
dotenv.config()
// 数据库配置
const dbConfig = {
  host: config.db.host,
  port: config.db.port,
  user: config.db.user,
  password: config.db.password,
  database: config.db.database,
  charset: 'utf8mb4',
  timezone: '+08:00'
}

// 创建数据库连接池
export const pool = mysql.createPool({
  ...dbConfig,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
})

function isMysqlError(error: unknown, codes: string[], errnos: number[] = []) {
  const err = error as { code?: string; errno?: number }
  return codes.includes(err.code || '') || errnos.includes(err.errno || -1)
}

async function executeIgnoring(
  connection: mysql.PoolConnection,
  sql: string,
  codes: string[],
  errnos: number[] = []
) {
  try {
    await connection.execute(sql)
  } catch (error) {
    if (!isMysqlError(error, codes, errnos)) throw error
  }
}

async function applyLegacySchemaPatches(connection: mysql.PoolConnection) {
  for (const sql of [
    'ALTER TABLE tokens ADD COLUMN user_agent VARCHAR(512) NULL DEFAULT NULL',
    'ALTER TABLE tokens ADD COLUMN alias VARCHAR(128) NULL DEFAULT NULL',
    'ALTER TABLE bookmarks ADD COLUMN content MEDIUMTEXT NULL DEFAULT NULL',
    'ALTER TABLE notes ADD COLUMN group_id VARCHAR(36) NULL',
    'ALTER TABLE notes ADD INDEX idx_group_id (group_id)',
    'ALTER TABLE images ADD COLUMN group_id VARCHAR(36) NULL',
    'ALTER TABLE images ADD INDEX idx_group_id (group_id)',
    'ALTER TABLE drive_folders ADD COLUMN group_id VARCHAR(36) NULL',
    'ALTER TABLE drive_folders ADD INDEX idx_group_id (group_id)',
    'ALTER TABLE drive_files ADD COLUMN group_id VARCHAR(36) NULL',
    'ALTER TABLE drive_files ADD INDEX idx_group_id (group_id)',
    'ALTER TABLE bookmarks ADD COLUMN group_id VARCHAR(36) NULL',
    'ALTER TABLE bookmarks ADD INDEX idx_group_id (group_id)',
    'ALTER TABLE note_tags ADD COLUMN group_id VARCHAR(36) NULL',
    'ALTER TABLE note_tags ADD INDEX idx_group_id (group_id)',
    'ALTER TABLE image_tags ADD COLUMN group_id VARCHAR(36) NULL',
    'ALTER TABLE image_tags ADD INDEX idx_group_id (group_id)',
    'ALTER TABLE bookmark_tags ADD COLUMN group_id VARCHAR(36) NULL',
    'ALTER TABLE bookmark_tags ADD INDEX idx_group_id (group_id)',
    "ALTER TABLE note_tags ADD COLUMN scope_key VARCHAR(80) NOT NULL DEFAULT ''",
    "ALTER TABLE image_tags ADD COLUMN scope_key VARCHAR(80) NOT NULL DEFAULT ''",
    "ALTER TABLE bookmark_tags ADD COLUMN scope_key VARCHAR(80) NOT NULL DEFAULT ''",
    "ALTER TABLE users ADD COLUMN meta TEXT NULL",
    "ALTER TABLE `groups` ADD COLUMN meta TEXT NULL",
  ]) {
    try {
      await connection.execute(sql)
    } catch (e: unknown) {
      const err = e as { code?: string; errno?: number }
      if (err.code !== 'ER_DUP_FIELDNAME' && err.errno !== 1060
        && err.code !== 'ER_DUP_KEYNAME' && err.errno !== 1061) throw e
    }
  }
}

async function migrateLegacyTagScopes(connection: mysql.PoolConnection) {
  for (const table of ['note_tags', 'image_tags', 'bookmark_tags']) {
    await connection.execute(
      `UPDATE ${table} SET scope_key = CASE WHEN group_id IS NULL THEN CONCAT('user:', user_id) ELSE CONCAT('group:', group_id) END WHERE scope_key = ''`
    )

    await executeIgnoring(connection, `ALTER TABLE ${table} DROP INDEX uk_user_name`, ['ER_CANT_DROP_FIELD_OR_KEY'], [1091])

    try {
      await connection.execute(`ALTER TABLE ${table} ADD UNIQUE KEY uk_scope_name (scope_key, name)`)
    } catch (error) {
      if (isMysqlError(error, ['ER_DUP_KEYNAME'], [1061])) continue
      if (isMysqlError(error, ['ER_DUP_ENTRY'], [1062])) {
        console.warn(`${table} 存在同作用域重名数据，跳过 uk_scope_name 唯一索引创建`)
        continue
      }
      throw error
    }
  }
}

// 初始化数据库表
export async function initDatabase() {
  try {
    const connection = await pool.getConnection()
    
    // 创建数据库（如果不存在）
    await connection.execute(`CREATE DATABASE IF NOT EXISTS ${dbConfig.database} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`)
    
    // 使用数据库
    await connection.query(`USE ${dbConfig.database}`)
    
    // 创建笔记表
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS notes (
        id VARCHAR(36) PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        content TEXT NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id),
        INDEX idx_created_at (created_at),
        INDEX idx_updated_at (updated_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    
    // 再创建images表
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS images (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(255) NOT NULL,
        url VARCHAR(255) NOT NULL,
        size INT NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        remark TEXT NOT NULL,
        INDEX idx_user_id (user_id),
        INDEX idx_created_at (created_at),
        INDEX idx_name (name)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS drive_folders (
        id VARCHAR(36) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        parent_id VARCHAR(36) NULL,
        user_id VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id),
        INDEX idx_parent_id (parent_id),
        INDEX idx_name (name),
        INDEX idx_created_at (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS drive_files (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(255) NOT NULL,
        oss_key VARCHAR(255) NOT NULL,
        size BIGINT NOT NULL,
        mime_type VARCHAR(255) NOT NULL,
        folder_id VARCHAR(36) NULL,
        user_id VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id),
        INDEX idx_folder_id (folder_id),
        INDEX idx_name (name),
        INDEX idx_created_at (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS image_tags (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(64) NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        group_id VARCHAR(36) NULL,
        scope_key VARCHAR(80) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uk_scope_name (scope_key, name),
        INDEX idx_user_id (user_id),
        INDEX idx_group_id (group_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS image_tag_map (
        image_id INT NOT NULL,
        tag_id INT NOT NULL,
        PRIMARY KEY (image_id, tag_id),
        INDEX idx_tag_id (tag_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS note_tags (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(64) NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        group_id VARCHAR(36) NULL,
        scope_key VARCHAR(80) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uk_scope_name (scope_key, name),
        INDEX idx_user_id (user_id),
        INDEX idx_group_id (group_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS note_tag_map (
        note_id VARCHAR(36) NOT NULL,
        tag_id INT NOT NULL,
        PRIMARY KEY (note_id, tag_id),
        INDEX idx_tag_id (tag_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(36) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL,
        password VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `)

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tokens (
        token VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        used_at TIMESTAMP NULL DEFAULT NULL,
        user_agent VARCHAR(512) NULL DEFAULT NULL,
        alias VARCHAR(128) NULL DEFAULT NULL,
        INDEX idx_user_id (user_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `)

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INT PRIMARY KEY AUTO_INCREMENT,
        type VARCHAR(16) NOT NULL,
        title VARCHAR(255) NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        url VARCHAR(1024) NOT NULL DEFAULT '',
        ref_id VARCHAR(128) NULL,
        user_id VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uk_user_ref (user_id, type, ref_id),
        INDEX idx_user_id (user_id),
        INDEX idx_type (type),
        INDEX idx_created_at (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS bookmark_tags (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(64) NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        group_id VARCHAR(36) NULL,
        scope_key VARCHAR(80) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uk_scope_name (scope_key, name),
        INDEX idx_user_id (user_id),
        INDEX idx_group_id (group_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS bookmark_tag_map (
        bookmark_id INT NOT NULL,
        tag_id INT NOT NULL,
        PRIMARY KEY (bookmark_id, tag_id),
        INDEX idx_tag_id (tag_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS user_settings (
        user_id VARCHAR(36) NOT NULL,
        k VARCHAR(128) NOT NULL,
        v TEXT NOT NULL,
        PRIMARY KEY (user_id, k)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS \`groups\` (
        id VARCHAR(36) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_by VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_created_by (created_by)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS group_members (
        group_id VARCHAR(36) NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        role ENUM('owner','admin','editor','viewer') NOT NULL DEFAULT 'editor',
        joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (group_id, user_id),
        INDEX idx_user_id (user_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS group_invites (
        id VARCHAR(36) PRIMARY KEY,
        group_id VARCHAR(36) NOT NULL,
        invite_code VARCHAR(64) NULL UNIQUE,
        invited_user_id VARCHAR(36) NULL,
        role ENUM('admin','editor','viewer') NOT NULL DEFAULT 'editor',
        created_by VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP NULL,
        used_at TIMESTAMP NULL,
        INDEX idx_group_id (group_id),
        INDEX idx_invited_user_id (invited_user_id),
        INDEX idx_invite_code (invite_code)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS group_chat_messages (
        id VARCHAR(36) PRIMARY KEY,
        group_id VARCHAR(36) NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_group_created (group_id, created_at),
        INDEX idx_group_id (group_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS todo_lists (
        id VARCHAR(36) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        color VARCHAR(32) NOT NULL DEFAULT '#9e9e9e',
        user_id VARCHAR(36) NOT NULL,
        group_id VARCHAR(36) NULL,
        sort_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id),
        INDEX idx_group_id (group_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await connection.execute(`
      CREATE TABLE IF NOT EXISTS todo_items (
        id VARCHAR(36) PRIMARY KEY,
        list_id VARCHAR(36) NOT NULL,
        title VARCHAR(512) NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        done TINYINT NOT NULL DEFAULT 0,
        color VARCHAR(32) NULL,
        refs TEXT NOT NULL,
        sort_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_list_id (list_id),
        CONSTRAINT fk_todo_items_list FOREIGN KEY (list_id) REFERENCES todo_lists(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    await applyLegacySchemaPatches(connection)
    await migrateLegacyTagScopes(connection)
    
    connection.release()
    console.log('数据库初始化完成')
  } catch (error) {
    console.error('数据库初始化失败:', error)
    throw error
  }
}

// 测试数据库连接
export async function testConnection() {
  try {
    const connection = await pool.getConnection()
    await connection.ping()
    connection.release()
    console.log('数据库连接成功')
    return true
  } catch (error) {
    console.error('数据库连接失败:', error)
    return false
  }
}
