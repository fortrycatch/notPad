<template>
  <v-card class="image-card" elevation="2" hover @click="previewImage">
    <v-img
      :src="imageUrl + '?x-oss-process=image/resize,w_640'"
      :alt="image.name"
      cover
      class="image-preview"
    >
      <template #placeholder>
        <div class="d-flex align-center justify-center fill-height">
          <v-progress-circular color="grey-lighten-5" indeterminate />
        </div>
      </template>
    </v-img>

    <v-card-text class="image-body">
      <div class="image-title text-truncate">
        {{ getImageName(image.name) }}
      </div>
      <div class="image-info">
        <span>{{ formatFileSize(image.size) }}</span>
        <span>{{ formatDate(image.created_at) }}</span>
      </div>
    </v-card-text>
  </v-card>

  <v-dialog v-model="showPreview" max-width="min(1100px, 96vw)">
    <v-card class="preview-dialog">
      <v-card-title class="preview-header">
        <div class="preview-header__meta">
          <div class="preview-title">{{ getImageName(image.name) }}</div>
          <div class="preview-subtitle">
            {{ formatFileSize(image.size) }} · {{ formatDate(image.created_at) }}
          </div>
        </div>
        <v-btn icon="mdi-close" variant="text" @click="showPreview = false" />
      </v-card-title>

      <v-card-text class="preview-content">
        <v-img
          :src="imageUrl"
          :alt="image.name"
          max-height="72vh"
          contain
          class="preview-image"
          @click="openViewer"
        />
      </v-card-text>

      <v-card-actions class="preview-actions">
        <v-btn @click="downloadImage" prepend-icon="mdi-download" :loading="downloading">
          下载
        </v-btn>
        <v-btn @click="copyImageUrl" prepend-icon="mdi-link-variant">
          图片链接
        </v-btn>
        <v-btn @click="copyImageMarkDown" prepend-icon="mdi-language-markdown">
          Markdown
        </v-btn>
        <v-btn @click="showOssConfig = true" prepend-icon="mdi-tune">
          图片处理
        </v-btn>
        <v-spacer />
        <v-btn variant="text" @click="showPreview = false">关闭</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <img
    ref="viewerImageRef"
    :src="imageUrl"
    :alt="getImageName(image.name)"
    class="viewer-source"
  />

  <OssProcessDialog
    v-model="showOssConfig"
    :image-url="imageUrl"
    :image-name="getImageName(image.name)"
  />
</template>

<script lang="ts" setup>
import Viewer from 'viewerjs'
import 'viewerjs/dist/viewer.css'
import { onBeforeUnmount, ref } from 'vue'
import OssProcessDialog from './OssProcessDialog.vue'

const props = defineProps<{
    image: any
}>()
const imageUrl = 'https://monika.jkloli.net/' + props.image.url
const showPreview = ref(false)
const showOssConfig = ref(false)
const downloading = ref(false)
const viewerImageRef = ref<HTMLImageElement | null>(null)
let imageViewer: Viewer | null = null

// 获取图片名称（去掉路径前缀）
const getImageName = (fullName: string) => {
    return fullName.split('/').pop() || fullName
}

// 格式化文件大小
const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 B'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
}

// 格式化日期
const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    })
}

const destroyImageViewer = () => {
    imageViewer?.destroy()
    imageViewer = null
}

const previewImage = () => {
    showPreview.value = true
}

const openViewer = () => {
    if (!viewerImageRef.value) return

    destroyImageViewer()

    imageViewer = new Viewer(viewerImageRef.value, {
        backdrop: true,
        button: true,
        keyboard: true,
        loop: false,
        movable: true,
        navbar: false,
        rotatable: false,
        scalable: false,
        title: () => getImageName(props.image.name),
        toolbar: true,
        transition: true,
        zIndex: 2400,
        zoomable: true,
        hidden: () => {
            destroyImageViewer()
        }
    })

    imageViewer.show()
}

const triggerDownload = (url: string, filename: string) => {
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
}

const downloadImage = async () => {
    if (downloading.value) return

    const filename = getImageName(props.image.name)
    try {
        downloading.value = true
        const response = await fetch(imageUrl)
        if (!response.ok) {
            throw new Error(`download failed: ${response.status}`)
        }

        const blob = await response.blob()
        const blobUrl = URL.createObjectURL(blob)
        triggerDownload(blobUrl, filename)
        window.setTimeout(() => {
            URL.revokeObjectURL(blobUrl)
        }, 1000)
    } catch (error) {
        console.error('下载图片失败，回退为直接打开原图:', error)
        window.open(imageUrl, '_blank', 'noopener,noreferrer')
    } finally {
        downloading.value = false
    }
}

const copyImageUrl = () => {
    navigator.clipboard.writeText(imageUrl)
}

const copyImageMarkDown = () => {
    navigator.clipboard.writeText(`![${getImageName(props.image.name)}](${imageUrl})`)
}

onBeforeUnmount(() => {
    destroyImageViewer()
})
</script>

<style scoped>
.image-card {
    height: 100%;
    display: flex;
    flex-direction: column;
    cursor: pointer;
    border-radius: 20px;
    overflow: hidden;
}

.image-preview {
    aspect-ratio: 16 / 10;
}

.image-body {
    display: grid;
    gap: 10px;
    padding: 16px 18px 10px;
}

.image-title {
    font-size: 17px;
    font-weight: 600;
    color: rgb(var(--v-theme-on-surface));
}

.image-info {
    display: flex;
    flex-wrap: wrap;
    gap: 6px 10px;
    font-size: 13px;
    color: rgb(var(--v-theme-on-surface-variant));
}

.viewer-source {
    position: fixed;
    width: 1px;
    height: 1px;
    opacity: 0;
    pointer-events: none;
    left: -9999px;
    top: -9999px;
}

.preview-dialog {
    overflow: hidden;
}

.preview-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    padding-bottom: 0;
}

.preview-header__meta {
    min-width: 0;
}

.preview-title {
    font-size: 18px;
    font-weight: 700;
    line-height: 1.4;
    word-break: break-word;
}

.preview-subtitle {
    margin-top: 4px;
    font-size: 13px;
    color: rgb(var(--v-theme-on-surface-variant));
}

.preview-content {
    padding-top: 16px;
}

.preview-image {
    cursor: zoom-in;
    background: rgba(var(--v-theme-on-surface), 0.04);
}

.preview-actions {
    flex-wrap: wrap;
    gap: 8px;
    padding: 0 24px 24px;
}

@media (max-width: 760px) {
    .image-body {
        padding-bottom: 16px;
    }

    .preview-actions {
        padding: 0 16px 16px;
    }
}
</style>