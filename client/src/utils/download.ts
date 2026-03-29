export function triggerDownload(url: string, filename: string) {
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
}

export function downloadUrl(url: string) {
  window.open(url, '_blank', 'noopener,noreferrer')
}
