<template>
  <v-dialog
    :model-value="modelValue"
    max-width="960"
    scrollable
    @update:model-value="emit('update:modelValue', $event)"
  >
    <v-card class="resource-picker">
      <v-card-title class="resource-picker__header">
        <div>
          <div class="text-h6">选择资源</div>
          <div class="resource-picker__subtitle">可选择图片或笔记，后续可继续扩展更多类型。</div>
        </div>
        <v-btn
          icon="mdi-close"
          variant="text"
          @click="emit('update:modelValue', false)"
        />
      </v-card-title>

      <v-card-text class="resource-picker__body">
        <v-tabs v-model="activeTab" color="primary" grow>
          <v-tab value="image">图片</v-tab>
          <v-tab value="note">笔记</v-tab>
        </v-tabs>

        <div v-if="feedbackMessage" class="resource-picker__feedback">
          <v-alert
            :type="feedbackType"
            variant="tonal"
            density="comfortable"
            closable
            @click:close="feedbackMessage = ''"
          >
            {{ feedbackMessage }}
          </v-alert>
        </div>

        <div v-if="activeTab === 'image'" class="resource-panel">
          <div class="resource-toolbar">
            <v-text-field
              v-model="imageSearch"
              label="搜索图片"
              placeholder="按名称搜索"
              prepend-inner-icon="mdi-magnify"
              variant="filled"
              density="comfortable"
              hide-details
            />
            <v-select
              v-model="imageSort"
              :items="imageSortOptions"
              label="排序"
              variant="filled"
              density="comfortable"
              hide-details
            />
            <v-btn
              variant="tonal"
              prepend-icon="mdi-refresh"
              :loading="imageLoading"
              @click="loadImages"
            >
              刷新
            </v-btn>
          </div>

          <div class="upload-box">
            <v-file-input
              v-model="uploadFile"
              label="选择图片文件"
              accept="image/*"
              prepend-icon="mdi-image-plus"
              variant="outlined"
              hide-details
            />
            <v-btn
              color="primary"
              prepend-icon="mdi-upload"
              :loading="uploadingImage"
              @click="uploadImage"
            >
              上传并插入
            </v-btn>
          </div>

          <div v-if="imageLoading" class="resource-empty">
            <v-progress-circular indeterminate color="primary" />
            <span>正在加载图片...</span>
          </div>
          <div v-else-if="imageList.length === 0" class="resource-empty">
            <v-icon size="40" color="primary">mdi-image-off-outline</v-icon>
            <span>暂无图片</span>
          </div>
          <div v-else class="image-grid">
            <v-card
              v-for="image in imageList"
              :key="image.url"
              class="image-item"
              hover
              @click="selectImage(image)"
            >
              <v-img
                :src="getImageUrl(image.url)"
                :alt="image.name"
                class="image-item__preview"
                cover
              />
              <div class="image-item__meta">
                <div class="image-item__title">{{ getImageName(image.name) }}</div>
                <div class="image-item__sub">
                  <span>{{ formatFileSize(image.size) }}</span>
                  <span>{{ formatDate(image.created_at) }}</span>
                </div>
              </div>
            </v-card>
          </div>
        </div>

        <div v-else class="resource-panel">
          <div class="resource-toolbar">
            <v-text-field
              v-model="noteSearch"
              label="搜索笔记"
              placeholder="标题或内容关键字"
              prepend-inner-icon="mdi-magnify"
              variant="filled"
              density="comfortable"
              hide-details
            />
            <v-btn
              variant="tonal"
              prepend-icon="mdi-refresh"
              :loading="noteLoading"
              @click="loadNotes(true)"
            >
              刷新
            </v-btn>
          </div>

          <div v-if="noteLoading" class="resource-empty">
            <v-progress-circular indeterminate color="primary" />
            <span>正在加载笔记...</span>
          </div>
          <div v-else-if="filteredNotes.length === 0" class="resource-empty">
            <v-icon size="40" color="primary">mdi-note-search-outline</v-icon>
            <span>{{ noteSearch.trim() ? '没有匹配的笔记' : '暂无笔记' }}</span>
          </div>
          <v-list v-else lines="three" class="note-list">
            <v-list-item
              v-for="note in filteredNotes"
              :key="note.id"
              class="note-item"
              @click="selectNote(note)"
            >
              <template #prepend>
                <v-avatar size="36" color="primary" variant="tonal">
                  <v-icon size="18">mdi-note-text-outline</v-icon>
                </v-avatar>
              </template>
              <v-list-item-title class="note-item__title">
                {{ note.title || '未命名笔记' }}
              </v-list-item-title>
              <v-list-item-subtitle class="note-item__content">
                {{ note.content || '暂无摘要' }}
              </v-list-item-subtitle>
              <template #append>
                <div class="note-item__time">{{ formatDate(note.updated_at) }}</div>
              </template>
            </v-list-item>
          </v-list>
        </div>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { trpc } from '../../trpc'

type ResourceTab = 'image' | 'note'
type ImageSort = 'time_desc' | 'time' | 'name'

interface ImageItem {
  id?: number
  name: string
  url: string
  size: number
  created_at: string | Date
  remark?: string
}

interface NoteItem {
  id: string
  title: string
  content: string
  created_at: string | Date
  updated_at: string | Date
}

const props = withDefaults(defineProps<{
  modelValue: boolean
  defaultTab?: ResourceTab
}>(), {
  defaultTab: 'image'
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'select', payload: { type: 'image'; item: ImageItem } | { type: 'note'; item: NoteItem }): void
}>()

const IMAGE_HOST = 'https://monika.jkloli.net/'
const NOTE_PAGE_SIZE = 30

const activeTab = ref<ResourceTab>(props.defaultTab)
const imageSearch = ref('')
const imageSort = ref<ImageSort>('time_desc')
const imageLoading = ref(false)
const imageList = ref<ImageItem[]>([])
const uploadFile = ref<File | File[] | null>(null)
const uploadingImage = ref(false)
const noteSearch = ref('')
const noteLoading = ref(false)
const notesLoaded = ref(false)
const notes = ref<NoteItem[]>([])
const feedbackMessage = ref('')
const feedbackType = ref<'success' | 'warning' | 'error'>('success')
const suspendImageReload = ref(false)

const imageSortOptions = [
  { title: '最新优先', value: 'time_desc' },
  { title: '最早优先', value: 'time' },
  { title: '按名称', value: 'name' }
]

const filteredNotes = computed(() => {
  const keyword = noteSearch.value.trim().toLowerCase()
  if (!keyword) return notes.value

  return notes.value.filter((note) => {
    return `${note.title} ${note.content}`.toLowerCase().includes(keyword)
  })
})

const setFeedback = (message: string, type: 'success' | 'warning' | 'error' = 'success') => {
  feedbackMessage.value = message
  feedbackType.value = type
}

const clearTransientState = () => {
  suspendImageReload.value = true
  imageSearch.value = ''
  imageSort.value = 'time_desc'
  noteSearch.value = ''
  uploadFile.value = null
  feedbackMessage.value = ''
  window.setTimeout(() => {
    suspendImageReload.value = false
  }, 0)
}

const getSelectedFile = () => {
  if (Array.isArray(uploadFile.value)) {
    return uploadFile.value[0] ?? null
  }
  return uploadFile.value
}

const getImageUrl = (url: string) => {
  return `${IMAGE_HOST}${url}`
}

const getImageName = (fullName: string) => {
  return fullName.split('/').pop() || fullName
}

const formatDate = (value: string | Date) => {
  const date = typeof value === 'string' ? new Date(value) : value
  return date.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const formatFileSize = (bytes: number) => {
  if (!bytes) return '0 B'

  const units = ['B', 'KB', 'MB', 'GB']
  const unitIndex = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  const value = bytes / 1024 ** unitIndex
  return `${value.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`
}

const loadImages = async () => {
  try {
    imageLoading.value = true
    imageList.value = await trpc.image_bed.list.query({
      user_id: 'admin',
      offset: 0,
      sort: imageSort.value,
      search: imageSearch.value.trim()
    }) as ImageItem[]
  } catch (error) {
    console.error('加载图片失败:', error)
    setFeedback('加载图片失败，请稍后重试', 'error')
  } finally {
    imageLoading.value = false
  }
}

const loadNotes = async (force = false) => {
  if (noteLoading.value) return
  if (notesLoaded.value && !force) return

  try {
    noteLoading.value = true
    let page = 0
    const allNotes: NoteItem[] = []

    while (true) {
      const result = await trpc.notepad.getNotes.query(page) as NoteItem[]
      allNotes.push(...result)

      if (result.length < NOTE_PAGE_SIZE) {
        break
      }

      page += 1
    }

    notes.value = allNotes
    notesLoaded.value = true
  } catch (error) {
    console.error('加载笔记失败:', error)
    setFeedback('加载笔记失败，请稍后重试', 'error')
  } finally {
    noteLoading.value = false
  }
}

const ensureActiveTabData = async () => {
  if (!props.modelValue) return

  if (activeTab.value === 'image') {
    await loadImages()
    return
  }

  await loadNotes()
}

const selectImage = (image: ImageItem) => {
  emit('select', { type: 'image', item: image })
  emit('update:modelValue', false)
}

const selectNote = (note: NoteItem) => {
  emit('select', { type: 'note', item: note })
  emit('update:modelValue', false)
}

const uploadImage = async () => {
  const file = getSelectedFile()
  if (!file) {
    setFeedback('请先选择图片文件', 'warning')
    return
  }

  try {
    uploadingImage.value = true
    const uploadUrl = await trpc.image_bed.getUploadUrl.query({
      filename: file.name,
      type: file.type
    })

    const uploadResult = await fetch(uploadUrl.url, {
      method: 'PUT',
      body: file
    })

    if (!uploadResult.ok) {
      throw new Error('上传文件失败')
    }

    const created = await trpc.image_bed.addImage.mutate({
      name: file.name,
      filename: uploadUrl.filename,
      remark: ''
    }) as Partial<ImageItem>

    const selectedImage: ImageItem = {
      name: file.name,
      url: uploadUrl.filename,
      size: file.size,
      created_at: new Date().toISOString(),
      ...created
    }

    await loadImages()
    setFeedback('图片上传成功，已插入当前内容', 'success')
    selectImage(selectedImage)
  } catch (error) {
    console.error('上传图片失败:', error)
    setFeedback('上传图片失败，请稍后重试', 'error')
  } finally {
    uploadingImage.value = false
    uploadFile.value = null
  }
}

let imageSearchTimer: number | null = null

watch(
  () => props.modelValue,
  async (open) => {
    if (open) {
      clearTransientState()
      activeTab.value = props.defaultTab
      await ensureActiveTabData()
      return
    }

    feedbackMessage.value = ''
    uploadFile.value = null
  }
)

watch(
  () => props.defaultTab,
  (value) => {
    if (props.modelValue) {
      activeTab.value = value
    }
  }
)

watch(activeTab, async () => {
  await ensureActiveTabData()
})

watch(imageSort, async () => {
  if (suspendImageReload.value) return
  if (props.modelValue && activeTab.value === 'image') {
    await loadImages()
  }
})

watch(imageSearch, () => {
  if (suspendImageReload.value) return
  if (imageSearchTimer) {
    window.clearTimeout(imageSearchTimer)
  }

  imageSearchTimer = window.setTimeout(() => {
    if (props.modelValue && activeTab.value === 'image') {
      void loadImages()
    }
  }, 300)
})

onBeforeUnmount(() => {
  if (imageSearchTimer) {
    window.clearTimeout(imageSearchTimer)
  }
})
</script>

<style scoped>
.resource-picker__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.resource-picker__subtitle {
  margin-top: 4px;
  font-size: 13px;
  color: rgba(var(--v-theme-on-surface), 0.68);
}

.resource-picker__body {
  display: grid;
  gap: 16px;
}

.resource-picker__feedback {
  margin-top: 4px;
}

.resource-panel {
  display: grid;
  gap: 16px;
  padding-top: 8px;
}

.resource-toolbar {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 180px auto;
  gap: 12px;
  align-items: center;
}

.upload-box {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 12px;
  align-items: center;
}

.resource-empty {
  min-height: 220px;
  display: grid;
  place-content: center;
  gap: 12px;
  text-align: center;
  color: rgba(var(--v-theme-on-surface), 0.68);
}

.image-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 14px;
}

.image-item {
  overflow: hidden;
  cursor: pointer;
}

.image-item__preview {
  aspect-ratio: 16 / 10;
}

.image-item__meta {
  display: grid;
  gap: 8px;
  padding: 12px;
}

.image-item__title {
  font-weight: 600;
  word-break: break-word;
}

.image-item__sub {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 12px;
  font-size: 12px;
  color: rgba(var(--v-theme-on-surface), 0.68);
}

.note-list {
  padding: 0;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 16px;
}

.note-item {
  cursor: pointer;
}

.note-item + .note-item {
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}

.note-item__title {
  font-weight: 600;
}

.note-item__content {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  white-space: normal;
}

.note-item__time {
  min-width: 92px;
  text-align: right;
  font-size: 12px;
  color: rgba(var(--v-theme-on-surface), 0.62);
}

@media (max-width: 760px) {
  .resource-toolbar,
  .upload-box {
    grid-template-columns: 1fr;
  }

  .note-item__time {
    min-width: auto;
    text-align: left;
  }
}
</style>
