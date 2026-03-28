/**
 * PUT 上传（如 OSS 预签名 URL），通过 XHR 获取上传进度。
 * contentType 须与申请预签名时传入的 type 一致。
 */
export function putWithUploadProgress(
  url: string,
  body: Blob,
  contentType: string,
  onProgress?: (loaded: number, total: number) => void
): Promise<void> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open('PUT', url)
    xhr.setRequestHeader('Content-Type', contentType || 'application/octet-stream')

    const totalHint = body.size

    xhr.upload.onprogress = (event) => {
      if (!onProgress) return
      const total = event.lengthComputable ? event.total : totalHint
      onProgress(event.loaded, total > 0 ? total : totalHint)
    }

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve()
      } else {
        reject(new Error(`上传失败: HTTP ${xhr.status}`))
      }
    }

    xhr.onerror = () => reject(new Error('上传失败: 网络错误'))
    xhr.onabort = () => reject(new Error('上传已取消'))

    xhr.send(body)
  })
}
