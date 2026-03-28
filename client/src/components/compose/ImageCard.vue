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
          <div class="preview-title">{{ displayName }}</div>
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

        <div v-if="imageTags.length > 0" class="preview-tags">
          <v-chip
            v-for="tag in imageTags"
            :key="tag.id"
            size="small"
            closable
            @click:close="removeTag(tag.id)"
          >
            {{ tag.name }}
          </v-chip>
        </div>
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
        <v-btn @click="startRename" prepend-icon="mdi-pencil">
          重命名
        </v-btn>
        <v-menu :close-on-content-click="false">
          <template #activator="{ props: menuProps }">
            <v-btn v-bind="menuProps" prepend-icon="mdi-tag-plus">
              标签
            </v-btn>
          </template>
          <v-list density="compact" min-width="200">
            <v-list-item
              v-for="tag in allTags"
              :key="tag.id"
              @click="toggleTag(tag)"
            >
              <template #prepend>
                <v-icon :color="isTagged(tag.id) ? 'primary' : undefined">
                  {{ isTagged(tag.id) ? 'mdi-checkbox-marked' : 'mdi-checkbox-blank-outline' }}
                </v-icon>
              </template>
              <v-list-item-title>{{ tag.name }}</v-list-item-title>
            </v-list-item>
            <v-list-item v-if="allTags.length === 0" disabled>
              <v-list-item-title class="text-medium-emphasis">暂无标签</v-list-item-title>
            </v-list-item>
          </v-list>
        </v-menu>
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

  <v-dialog v-model="showRenameDialog" max-width="420">
    <v-card>
      <v-card-title>重命名图片</v-card-title>
      <v-card-text>
        <v-text-field
          v-model="renameValue"
          label="新名称"
          variant="outlined"
          hide-details
          autofocus
          @keydown.enter="confirmRename"
        />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="showRenameDialog = false">取消</v-btn>
        <v-btn color="primary" :loading="renaming" @click="confirmRename">确定</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <OssProcessDialog
    v-model="showOssConfig"
    :image-url="imageUrl"
    :image-name="displayName"
  />
</template>

<script lang="ts" setup>
import Viewer from 'viewerjs'
import 'viewerjs/dist/viewer.css'
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import OssProcessDialog from './OssProcessDialog.vue'
import { server } from '../../server'

interface TagItem {
    id: number
    name: string
}

const props = defineProps<{
    image: any
    allTags: TagItem[]
}>()

const emit = defineEmits<{
    (e: 'renamed'): void
    (e: 'tagChanged'): void
}>()

const imageUrl = 'https://monika.jkloli.net/' + props.image.url
const showPreview = ref(false)
const showOssConfig = ref(false)
const downloading = ref(false)
const showRenameDialog = ref(false)
const renameValue = ref('')
const renaming = ref(false)
const imageTags = ref<TagItem[]>([])
const viewerImageRef = ref<HTMLImageElement | null>(null)
let imageViewer: Viewer | null = null

const displayName = computed(() => getImageName(props.image.name))

const getImageName = (fullName: string) => {
    return fullName.split('/').pop() || fullName
}

const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 B'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
}

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

const loadImageTags = async () => {
    if (!props.image.id) return
    imageTags.value = await server.image_bed.getImageTags.query({ image_id: props.image.id }) as TagItem[]
}

const isTagged = (tagId: number) => imageTags.value.some((t) => t.id === tagId)

const toggleTag = async (tag: TagItem) => {
    if (!props.image.id) return
    if (isTagged(tag.id)) {
        await server.image_bed.removeTagFromImage.mutate({ image_id: props.image.id, tag_id: tag.id })
    } else {
        await server.image_bed.addTagToImage.mutate({ image_id: props.image.id, tag_id: tag.id })
    }
    await loadImageTags()
    emit('tagChanged')
}

const removeTag = async (tagId: number) => {
    if (!props.image.id) return
    await server.image_bed.removeTagFromImage.mutate({ image_id: props.image.id, tag_id: tagId })
    await loadImageTags()
    emit('tagChanged')
}

const startRename = () => {
    renameValue.value = displayName.value
    showRenameDialog.value = true
}

const confirmRename = async () => {
    const name = renameValue.value.trim()
    if (!name || !props.image.id) return

    renaming.value = true
    try {
        await server.image_bed.rename.mutate({ id: props.image.id, name })
        props.image.name = name
        showRenameDialog.value = false
        emit('renamed')
    } finally {
        renaming.value = false
    }
}

watch(showPreview, (open) => {
    if (open) {
        void loadImageTags()
    }
})

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
        title: () => displayName.value,
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

    const filename = displayName.value
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
    navigator.clipboard.writeText(`![${displayName.value}](${imageUrl})`)
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

.preview-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 12px;
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