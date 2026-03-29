export function formatFileSize(bytes: number): string {
  if (!bytes) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB']
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  return `${(bytes / 1024 ** i).toFixed(i === 0 ? 0 : 1)} ${units[i]}`
}

export function formatDate(value: string | Date, showYear = false): string {
  const date = typeof value === 'string' ? new Date(value) : value
  const options: Intl.DateTimeFormatOptions = {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }
  if (showYear) options.year = 'numeric'
  return date.toLocaleString('zh-CN', options)
}

export function getFileIcon(mimeType: string): string {
  if (!mimeType) return 'mdi-file-outline'
  if (mimeType.startsWith('image/')) return 'mdi-file-image-outline'
  if (mimeType.startsWith('video/')) return 'mdi-file-video-outline'
  if (mimeType.includes('pdf')) return 'mdi-file-pdf-box'
  if (mimeType.includes('zip') || mimeType.includes('compressed')) return 'mdi-folder-zip-outline'
  if (mimeType.startsWith('text/')) return 'mdi-file-document-outline'
  return 'mdi-file-outline'
}
