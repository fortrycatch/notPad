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
          <div class="resource-picker__subtitle">可选择图片、网盘文件、笔记或书签。</div>
        </div>
        <v-btn
          icon="mdi-close"
          variant="text"
          @click="emit('update:modelValue', false)"
        />
      </v-card-title>

      <v-card-text class="resource-picker__body" @scroll.passive="onPickerScroll">
        <v-tabs v-model="activeTab" color="primary" grow>
          <v-tab value="image">图片</v-tab>
          <v-tab value="file">文件</v-tab>
          <v-tab value="note">笔记</v-tab>
          <v-tab value="bookmark">书签</v-tab>
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
              :items="sortOptions"
              label="排序"
              variant="filled"
              density="comfortable"
              hide-details
            />
            <v-btn
              variant="tonal"
              prepend-icon="mdi-refresh"
              :loading="imageLoading"
              @click="loadImages(true)"
            >
              刷新
            </v-btn>
          </div>

          <div v-if="imageTagList.length > 0" class="resource-tag-row">
            <v-chip
              :color="imageActiveTagId === null ? 'primary' : undefined"
              :variant="imageActiveTagId === null ? 'elevated' : 'outlined'"
              size="small"
              @click="imageActiveTagId = null"
            >
              全部
            </v-chip>
            <v-chip
              v-for="tag in imageTagList"
              :key="tag.id"
              size="small"
              :color="imageActiveTagId === tag.id ? 'primary' : undefined"
              :variant="imageActiveTagId === tag.id ? 'elevated' : 'outlined'"
              @click="imageActiveTagId = tag.id"
            >
              {{ tag.name }}
            </v-chip>
          </div>

          <div class="upload-box">
            <v-file-input
              v-model="imageUploadFile"
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

          <div v-if="imageLoading && imageList.length === 0" class="resource-empty">
            <v-progress-circular indeterminate color="primary" />
            <span>正在加载图片...</span>
          </div>
          <div v-else-if="imageList.length === 0" class="resource-empty">
            <v-icon size="40" color="primary">mdi-image-off-outline</v-icon>
            <span>{{ imageEmptyHint }}</span>
          </div>
          <template v-else>
            <div class="image-grid">
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
                  <div class="image-item__title">{{ getBaseName(image.name) }}</div>
                  <div class="image-item__sub">
                    <span>{{ formatFileSize(image.size) }}</span>
                    <span>{{ formatDate(image.created_at) }}</span>
                  </div>
                </div>
              </v-card>
            </div>
            <div v-if="imageLoadingMore" class="resource-load-more">
              <v-progress-circular indeterminate color="primary" size="28" />
            </div>
          </template>
        </div>

        <div v-else-if="activeTab === 'file'" class="resource-panel">
          <div class="resource-toolbar">
            <v-text-field
              v-model="fileSearch"
              label="搜索文件"
              placeholder="按名称搜索当前目录"
              prepend-inner-icon="mdi-magnify"
              variant="filled"
              density="comfortable"
              hide-details
            />
            <v-select
              v-model="fileSort"
              :items="sortOptions"
              label="排序"
              variant="filled"
              density="comfortable"
              hide-details
            />
            <v-btn
              variant="tonal"
              prepend-icon="mdi-refresh"
              :loading="fileLoading"
              @click="loadFiles(true)"
            >
              刷新
            </v-btn>
          </div>

          <div class="drive-breadcrumbs">
            <v-btn variant="text" prepend-icon="mdi-home" @click="openDriveFolder(null)">
              根目录
            </v-btn>
            <template v-for="folder in fileBreadcrumbs" :key="folder.id">
              <v-icon size="18">mdi-chevron-right</v-icon>
              <v-btn variant="text" @click="openDriveFolder(folder.id)">
                {{ folder.name }}
              </v-btn>
            </template>
          </div>

          <div class="d-flex flex-column ga-3">
            <div class="upload-box">
              <v-file-input
                v-model="driveUploadFile"
                label="选择网盘文件"
                prepend-icon="mdi-paperclip"
                variant="outlined"
                hide-details
                :disabled="uploadingDriveFile"
              />
              <v-btn
                color="primary"
                prepend-icon="mdi-upload"
                :loading="uploadingDriveFile"
                @click="uploadDriveFileAndSelect"
              >
                上传并插入
              </v-btn>
            </div>
            <template v-if="uploadingDriveFile">
              <v-progress-linear
                :model-value="driveUploadPercent"
                color="primary"
              />
              <div class="text-caption text-medium-emphasis text-end">
                {{ driveUploadPercent }}%
              </div>
            </template>
          </div>

          <div v-if="fileLoading && fileFolders.length === 0 && fileList.length === 0" class="resource-empty">
            <v-progress-circular indeterminate color="primary" />
            <span>正在加载文件...</span>
          </div>
          <div v-else-if="fileFolders.length === 0 && fileList.length === 0" class="resource-empty">
            <v-icon size="40" color="primary">mdi-folder-open-outline</v-icon>
            <span>{{ fileSearch.trim() ? '没有匹配的内容' : '当前目录为空' }}</span>
          </div>
          <template v-else>
            <v-list lines="two" class="note-list">
              <v-list-item
                v-for="folder in fileFolders"
                :key="folder.id"
                class="note-item"
                @click="openDriveFolder(folder.id)"
              >
                <template #prepend>
                  <v-avatar size="36" color="primary" variant="tonal">
                    <v-icon size="18">mdi-folder</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="note-item__title">
                  {{ folder.name }}
                </v-list-item-title>
                <v-list-item-subtitle class="note-item__content">
                  文件夹 · {{ formatDate(folder.created_at) }}
                </v-list-item-subtitle>
              </v-list-item>

              <v-list-item
                v-for="file in fileList"
                :key="file.id"
                class="note-item"
                @click="selectFile(file)"
              >
                <template #prepend>
                  <v-avatar size="36" color="surface-variant" variant="flat">
                    <v-icon size="18">{{ getFileIcon(file.mime_type) }}</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="note-item__title">
                  {{ file.name }}
                </v-list-item-title>
                <v-list-item-subtitle class="note-item__content">
                  {{ formatFileSize(file.size) }} · {{ formatDate(file.created_at) }}
                </v-list-item-subtitle>
              </v-list-item>
            </v-list>
            <div v-if="fileLoadingMore" class="resource-load-more">
              <v-progress-circular indeterminate color="primary" size="28" />
            </div>
          </template>
        </div>

        <div v-else-if="activeTab === 'note'" class="resource-panel">
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

          <div v-if="noteTagList.length > 0" class="resource-tag-row">
            <v-chip
              :color="noteActiveTagId === null ? 'primary' : undefined"
              :variant="noteActiveTagId === null ? 'elevated' : 'outlined'"
              size="small"
              @click="noteActiveTagId = null"
            >
              全部
            </v-chip>
            <v-chip
              v-for="tag in noteTagList"
              :key="tag.id"
              size="small"
              :color="noteActiveTagId === tag.id ? 'primary' : undefined"
              :variant="noteActiveTagId === tag.id ? 'elevated' : 'outlined'"
              @click="noteActiveTagId = tag.id"
            >
              {{ tag.name }}
            </v-chip>
          </div>

          <div v-if="noteLoading && notes.length === 0" class="resource-empty">
            <v-progress-circular indeterminate color="primary" />
            <span>正在加载笔记...</span>
          </div>
          <div v-else-if="filteredNotes.length === 0" class="resource-empty">
            <v-icon size="40" color="primary">mdi-note-search-outline</v-icon>
            <span>{{ noteEmptyHint }}</span>
          </div>
          <template v-else>
            <v-list lines="three" class="note-list">
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
            <div v-if="noteLoadingMore" class="resource-load-more">
              <v-progress-circular indeterminate color="primary" size="28" />
            </div>
          </template>
        </div>

        <div v-else class="resource-panel">
          <div class="resource-toolbar resource-toolbar--bookmark">
            <v-text-field
              v-model="bookmarkSearch"
              label="搜索书签"
              placeholder="标题或描述"
              prepend-inner-icon="mdi-magnify"
              variant="filled"
              density="comfortable"
              hide-details
            />
            <v-select
              v-model="bookmarkSort"
              :items="sortOptions"
              label="排序"
              variant="filled"
              density="comfortable"
              hide-details
            />
            <v-btn
              variant="tonal"
              prepend-icon="mdi-refresh"
              :loading="bookmarkLoading"
              @click="loadBookmarks(true)"
            >
              刷新
            </v-btn>
          </div>

          <div v-if="bookmarkTagList.length > 0" class="resource-tag-row">
            <v-chip
              :color="bookmarkActiveTagId === null ? 'primary' : undefined"
              :variant="bookmarkActiveTagId === null ? 'elevated' : 'outlined'"
              size="small"
              @click="bookmarkActiveTagId = null"
            >
              全部
            </v-chip>
            <v-chip
              v-for="tag in bookmarkTagList"
              :key="tag.id"
              size="small"
              :color="bookmarkActiveTagId === tag.id ? 'primary' : undefined"
              :variant="bookmarkActiveTagId === tag.id ? 'elevated' : 'outlined'"
              @click="bookmarkActiveTagId = tag.id"
            >
              {{ tag.name }}
            </v-chip>
          </div>

          <div v-if="bookmarkLoading && bookmarkList.length === 0" class="resource-empty">
            <v-progress-circular indeterminate color="primary" />
            <span>正在加载书签...</span>
          </div>
          <div v-else-if="bookmarkList.length === 0" class="resource-empty">
            <v-icon size="40" color="primary">mdi-bookmark-off-outline</v-icon>
            <span>{{ bookmarkEmptyHint }}</span>
          </div>
          <template v-else>
            <v-list lines="three" class="note-list">
              <v-list-item
                v-for="bm in bookmarkList"
                :key="bm.id"
                class="note-item"
                @click="selectBookmark(bm)"
              >
                <template #prepend>
                  <v-avatar size="36" color="primary" variant="tonal">
                    <v-icon size="18">{{ bookmarkTypeIcon(bm.type) }}</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="note-item__title">
                  {{ bm.title || '未命名书签' }}
                </v-list-item-title>
                <v-list-item-subtitle class="note-item__content">
                  {{ bm.description || bm.url || '暂无摘要' }}
                </v-list-item-subtitle>
                <template #append>
                  <div class="note-item__time">{{ formatDate(bm.created_at) }}</div>
                </template>
              </v-list-item>
            </v-list>
            <div v-if="bookmarkLoadingMore" class="resource-load-more">
              <v-progress-circular indeterminate color="primary" size="28" />
            </div>
          </template>
        </div>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { trpc } from '../../trpc'
import { putWithUploadProgress } from '../../utils/putWithUploadProgress'
import { formatFileSize, formatDate, getFileIcon } from '../../utils/format'

type ResourceTab = 'image' | 'note' | 'file' | 'bookmark'
type ResourceSort = 'time_desc' | 'time' | 'name'

interface TagItem {
  id: number
  name: string
}

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

interface DriveFolder {
  id: string
  name: string
  parent_id: string | null
  created_at: string | Date
}

interface DriveFileItem {
  id: number
  name: string
  oss_key: string
  size: number
  mime_type: string
  folder_id: string | null
  created_at: string | Date
  public_url: string
}

interface BookmarkListItem {
  id: number
  type: 'url' | 'image' | 'note' | 'file'
  title: string
  description: string
  url: string
  ref_id: string | null
  created_at: string | Date
}

const props = withDefaults(defineProps<{
  modelValue: boolean
  defaultTab?: ResourceTab
}>(), {
  defaultTab: 'image'
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'select', payload:
    | { type: 'image'; item: ImageItem }
    | { type: 'note'; item: NoteItem }
    | { type: 'file'; item: DriveFileItem }
    | { type: 'bookmark'; item: BookmarkListItem }
  ): void
}>()

const IMAGE_HOST = 'https://monika.jkloli.net/'
const NOTE_PAGE_SIZE = 30
const IMAGE_PAGE_SIZE = 30
const BOOKMARK_PAGE_SIZE = 30
const activeTab = ref<ResourceTab>(props.defaultTab)
const imageSearch = ref('')
const imageSort = ref<ResourceSort>('time_desc')
const imageActiveTagId = ref<number | null>(null)
const imageTagList = ref<TagItem[]>([])
const imageLoading = ref(false)
const imageLoadingMore = ref(false)
const imageHasMore = ref(false)
const imageNextOffset = ref(0)
const imageList = ref<ImageItem[]>([])
const imageUploadFile = ref<File | File[] | null>(null)
const uploadingImage = ref(false)
const fileSearch = ref('')
const fileSort = ref<ResourceSort>('time_desc')
const fileLoading = ref(false)
const fileLoadingMore = ref(false)
const fileListHasMore = ref(false)
const fileDriveNextOffset = ref(0)
const fileFolders = ref<DriveFolder[]>([])
const fileList = ref<DriveFileItem[]>([])
const fileBreadcrumbs = ref<DriveFolder[]>([])
const currentFileFolderId = ref<string | null>(null)
const driveUploadFile = ref<File | File[] | null>(null)
const uploadingDriveFile = ref(false)
const driveUploadPercent = ref(0)
const noteSearch = ref('')
const noteActiveTagId = ref<number | null>(null)
const noteTagList = ref<TagItem[]>([])
const noteLoading = ref(false)
const noteLoadingMore = ref(false)
const noteHasMore = ref(false)
const noteNextPage = ref(0)
const notes = ref<NoteItem[]>([])
const feedbackMessage = ref('')
const feedbackType = ref<'success' | 'warning' | 'error'>('success')
const suspendImageReload = ref(false)
const suspendFileReload = ref(false)
const suspendBookmarkReload = ref(false)
const suspendNoteReload = ref(false)
const bookmarkSearch = ref('')
const bookmarkSort = ref<ResourceSort>('time_desc')
const bookmarkActiveTagId = ref<number | null>(null)
const bookmarkTagList = ref<TagItem[]>([])
const bookmarkLoading = ref(false)
const bookmarkLoadingMore = ref(false)
const bookmarkHasMore = ref(false)
const bookmarkNextOffset = ref(0)
const bookmarkList = ref<BookmarkListItem[]>([])

const sortOptions = [
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

const imageEmptyHint = computed(() => {
  if (imageSearch.value.trim() || imageActiveTagId.value !== null) {
    return '没有匹配的图片'
  }
  return '暂无图片'
})

const noteEmptyHint = computed(() => {
  if (noteSearch.value.trim()) {
    return '没有匹配的笔记'
  }
  if (noteActiveTagId.value !== null) {
    return '该标签下暂无笔记'
  }
  return '暂无笔记'
})

const bookmarkEmptyHint = computed(() => {
  if (bookmarkSearch.value.trim()) {
    return '没有匹配的书签'
  }
  if (bookmarkActiveTagId.value !== null) {
    return '该标签下暂无书签'
  }
  return '暂无书签'
})

const setFeedback = (message: string, type: 'success' | 'warning' | 'error' = 'success') => {
  feedbackMessage.value = message
  feedbackType.value = type
}

const clearTransientState = () => {
  suspendImageReload.value = true
  suspendFileReload.value = true
  suspendBookmarkReload.value = true
  suspendNoteReload.value = true
  imageSearch.value = ''
  imageSort.value = 'time_desc'
  imageActiveTagId.value = null
  imageUploadFile.value = null
  fileSearch.value = ''
  fileSort.value = 'time_desc'
  fileFolders.value = []
  fileList.value = []
  fileBreadcrumbs.value = []
  currentFileFolderId.value = null
  driveUploadFile.value = null
  driveUploadPercent.value = 0
  noteSearch.value = ''
  noteActiveTagId.value = null
  bookmarkSearch.value = ''
  bookmarkSort.value = 'time_desc'
  bookmarkActiveTagId.value = null
  feedbackMessage.value = ''
  window.setTimeout(() => {
    suspendImageReload.value = false
    suspendFileReload.value = false
    suspendBookmarkReload.value = false
    suspendNoteReload.value = false
  }, 0)
}

const getSelectedFile = (source: File | File[] | null) => {
  if (Array.isArray(source)) {
    return source[0] ?? null
  }
  return source
}

const getImageUrl = (url: string) => `${IMAGE_HOST}${url}`

const getBaseName = (fullName: string) => fullName.split('/').pop() || fullName

const bookmarkTypeIcon = (t: string) => {
  if (t === 'url') return 'mdi-web'
  if (t === 'image') return 'mdi-image-outline'
  if (t === 'note') return 'mdi-note-text-outline'
  if (t === 'file') return 'mdi-file-outline'
  return 'mdi-bookmark-outline'
}

const loadPickerTags = async () => {
  try {
    const [img, note, bm] = await Promise.all([
      trpc.image_bed.listTags.query(),
      trpc.notepad.listTags.query(),
      trpc.bookmark.listTags.query()
    ])
    imageTagList.value = img as TagItem[]
    noteTagList.value = note as TagItem[]
    bookmarkTagList.value = bm as TagItem[]
  } catch (error) {
    console.error('加载标签失败:', error)
    setFeedback('加载标签失败，请稍后重试', 'error')
  }
}

const loadImages = async (reset: boolean) => {
  if (reset) {
    if (imageLoading.value) return
    imageLoading.value = true
    imageList.value = []
    imageNextOffset.value = 0
    imageHasMore.value = true
  } else {
    if (!imageHasMore.value || imageLoadingMore.value || imageLoading.value) return
    imageLoadingMore.value = true
  }

  const offset = reset ? 0 : imageNextOffset.value

  try {
    const rows = await trpc.image_bed.list.query({
      user_id: 'admin',
      offset,
      sort: imageSort.value,
      search: imageSearch.value.trim(),
      tag_id: imageActiveTagId.value
    }) as ImageItem[]

    if (reset) {
      imageList.value = rows
    } else {
      imageList.value.push(...rows)
    }

    imageHasMore.value = rows.length >= IMAGE_PAGE_SIZE
    if (imageHasMore.value) {
      imageNextOffset.value = offset + 1
    }
  } catch (error) {
    console.error('加载图片失败:', error)
    setFeedback('加载图片失败，请稍后重试', 'error')
  } finally {
    imageLoading.value = false
    imageLoadingMore.value = false
  }
}

const loadFiles = async (reset: boolean) => {
  if (reset) {
    if (fileLoading.value) return
    fileLoading.value = true
    fileFolders.value = []
    fileList.value = []
    fileDriveNextOffset.value = 0
    fileListHasMore.value = true
  } else {
    if (!fileListHasMore.value || fileLoadingMore.value || fileLoading.value) return
    fileLoadingMore.value = true
  }

  const offset = reset ? 0 : fileDriveNextOffset.value

  try {
    const result = await trpc.file_drive.list.query({
      folder_id: currentFileFolderId.value,
      offset,
      sort: fileSort.value,
      search: fileSearch.value.trim()
    }) as {
      breadcrumbs: DriveFolder[]
      folders: DriveFolder[]
      files: DriveFileItem[]
      hasMore: boolean
    }

    if (reset) {
      fileBreadcrumbs.value = result.breadcrumbs
      fileFolders.value = result.folders
      fileList.value = result.files
    } else {
      fileFolders.value.push(...result.folders)
      fileList.value.push(...result.files)
    }

    fileListHasMore.value = result.hasMore
    if (result.hasMore) {
      fileDriveNextOffset.value = offset + 1
    }
  } catch (error) {
    console.error('加载文件失败:', error)
    setFeedback('加载文件失败，请稍后重试', 'error')
  } finally {
    fileLoading.value = false
    fileLoadingMore.value = false
  }
}

const loadNotes = async (reset: boolean) => {
  if (reset) {
    if (noteLoading.value) return
    noteLoading.value = true
    notes.value = []
    noteNextPage.value = 0
    noteHasMore.value = true
  } else {
    if (!noteHasMore.value || noteLoadingMore.value || noteLoading.value) return
    noteLoadingMore.value = true
  }

  const page = reset ? 0 : noteNextPage.value

  try {
    const result = await trpc.notepad.getNotes.query({
      page,
      tag_id: noteActiveTagId.value
    }) as NoteItem[]

    if (reset) {
      notes.value = result
    } else {
      notes.value.push(...result)
    }

    noteHasMore.value = result.length >= NOTE_PAGE_SIZE
    if (noteHasMore.value) {
      noteNextPage.value = page + 1
    }
  } catch (error) {
    console.error('加载笔记失败:', error)
    setFeedback('加载笔记失败，请稍后重试', 'error')
  } finally {
    noteLoading.value = false
    noteLoadingMore.value = false
  }
}

const loadBookmarks = async (reset: boolean) => {
  if (reset) {
    if (bookmarkLoading.value) return
    bookmarkLoading.value = true
    bookmarkList.value = []
    bookmarkNextOffset.value = 0
    bookmarkHasMore.value = true
  } else {
    if (!bookmarkHasMore.value || bookmarkLoadingMore.value || bookmarkLoading.value) return
    bookmarkLoadingMore.value = true
  }

  const offset = reset ? 0 : bookmarkNextOffset.value

  try {
    const rows = await trpc.bookmark.list.query({
      offset,
      sort: bookmarkSort.value,
      search: bookmarkSearch.value.trim(),
      tag_id: bookmarkActiveTagId.value
    }) as BookmarkListItem[]

    if (reset) {
      bookmarkList.value = rows
    } else {
      bookmarkList.value.push(...rows)
    }

    bookmarkHasMore.value = rows.length >= BOOKMARK_PAGE_SIZE
    if (bookmarkHasMore.value) {
      bookmarkNextOffset.value = offset + 1
    }
  } catch (error) {
    console.error('加载书签失败:', error)
    setFeedback('加载书签失败，请稍后重试', 'error')
  } finally {
    bookmarkLoading.value = false
    bookmarkLoadingMore.value = false
  }
}

const loadMoreForActiveTab = async () => {
  if (!props.modelValue) return

  if (activeTab.value === 'image') {
    await loadImages(false)
    return
  }

  if (activeTab.value === 'file') {
    await loadFiles(false)
    return
  }

  if (activeTab.value === 'note') {
    await loadNotes(false)
    return
  }

  if (activeTab.value === 'bookmark') {
    await loadBookmarks(false)
  }
}

const scrollLoadBusy = ref(false)

const onPickerScroll = (e: Event) => {
  const el = e.target as HTMLElement
  if (!el?.scrollHeight) return
  const nearBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 180
  if (!nearBottom) return
  if (scrollLoadBusy.value) return
  scrollLoadBusy.value = true
  void loadMoreForActiveTab().finally(() => {
    scrollLoadBusy.value = false
  })
}

const ensureActiveTabData = async () => {
  if (!props.modelValue) return

  if (activeTab.value === 'image') {
    await loadImages(true)
    return
  }

  if (activeTab.value === 'file') {
    await loadFiles(true)
    return
  }

  if (activeTab.value === 'note') {
    await loadNotes(true)
    return
  }

  await loadBookmarks(true)
}

const selectImage = (image: ImageItem) => {
  emit('select', { type: 'image', item: image })
  emit('update:modelValue', false)
}

const selectFile = (file: DriveFileItem) => {
  emit('select', { type: 'file', item: file })
  emit('update:modelValue', false)
}

const selectNote = (note: NoteItem) => {
  emit('select', { type: 'note', item: note })
  emit('update:modelValue', false)
}

const selectBookmark = (bm: BookmarkListItem) => {
  emit('select', { type: 'bookmark', item: bm })
  emit('update:modelValue', false)
}

const openDriveFolder = async (folderId: string | null) => {
  currentFileFolderId.value = folderId
  await loadFiles(true)
}

const uploadImage = async () => {
  const file = getSelectedFile(imageUploadFile.value)
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

    const selectedImage: ImageItem = {
      name: file.name,
      url: uploadUrl.filename,
      size: file.size,
      created_at: new Date().toISOString()
    }

    await trpc.image_bed.addImage.mutate({
      name: file.name,
      filename: uploadUrl.filename,
      remark: ''
    })

    await loadImages(true)
    setFeedback('图片上传成功，已插入当前内容', 'success')
    selectImage(selectedImage)
  } catch (error) {
    console.error('上传图片失败:', error)
    setFeedback('上传图片失败，请稍后重试', 'error')
  } finally {
    uploadingImage.value = false
    imageUploadFile.value = null
  }
}

const uploadDriveFileAndSelect = async () => {
  const file = getSelectedFile(driveUploadFile.value)
  if (!file) {
    setFeedback('请先选择网盘文件', 'warning')
    return
  }

  const mimeType = file.type || 'application/octet-stream'

  try {
    uploadingDriveFile.value = true
    driveUploadPercent.value = 0
    const uploadUrl = await trpc.file_drive.getUploadUrl.query({
      filename: file.name,
      type: mimeType,
      folder_id: currentFileFolderId.value
    })

    await putWithUploadProgress(uploadUrl.url, file, mimeType, (loaded, total) => {
      if (total > 0) {
        driveUploadPercent.value = Math.min(100, Math.round((loaded / total) * 100))
      }
    })

    const created = await trpc.file_drive.addFile.mutate({
      name: file.name,
      filename: uploadUrl.filename,
      folder_id: currentFileFolderId.value,
      mime_type: mimeType
    }) as DriveFileItem

    await loadFiles(true)
    setFeedback('文件上传成功，已插入当前内容', 'success')
    selectFile(created)
  } catch (error) {
    console.error('上传网盘文件失败:', error)
    setFeedback('上传文件失败，请稍后重试', 'error')
  } finally {
    uploadingDriveFile.value = false
    driveUploadPercent.value = 0
    driveUploadFile.value = null
  }
}

let imageSearchTimer: number | null = null
let fileSearchTimer: number | null = null
let bookmarkSearchTimer: number | null = null

watch(
  () => props.modelValue,
  async (open) => {
    if (open) {
      clearTransientState()
      activeTab.value = props.defaultTab
      void loadPickerTags()
      await ensureActiveTabData()
      return
    }

    feedbackMessage.value = ''
    imageUploadFile.value = null
    driveUploadFile.value = null
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
    await loadImages(true)
  }
})

watch(imageActiveTagId, async () => {
  if (suspendImageReload.value) return
  if (props.modelValue && activeTab.value === 'image') {
    await loadImages(true)
  }
})

watch(fileSort, async () => {
  if (suspendFileReload.value) return
  if (props.modelValue && activeTab.value === 'file') {
    await loadFiles(true)
  }
})

watch(bookmarkSort, async () => {
  if (suspendBookmarkReload.value) return
  if (props.modelValue && activeTab.value === 'bookmark') {
    await loadBookmarks(true)
  }
})

watch(bookmarkActiveTagId, async () => {
  if (suspendBookmarkReload.value) return
  if (props.modelValue && activeTab.value === 'bookmark') {
    await loadBookmarks(true)
  }
})

watch(noteActiveTagId, async () => {
  if (suspendNoteReload.value) return
  if (!props.modelValue || activeTab.value !== 'note') return
  await loadNotes(true)
})

watch(imageSearch, () => {
  if (suspendImageReload.value) return
  if (imageSearchTimer) {
    window.clearTimeout(imageSearchTimer)
  }

  imageSearchTimer = window.setTimeout(() => {
    if (props.modelValue && activeTab.value === 'image') {
      void loadImages(true)
    }
  }, 300)
})

watch(fileSearch, () => {
  if (suspendFileReload.value) return
  if (fileSearchTimer) {
    window.clearTimeout(fileSearchTimer)
  }

  fileSearchTimer = window.setTimeout(() => {
    if (props.modelValue && activeTab.value === 'file') {
      void loadFiles(true)
    }
  }, 300)
})

watch(bookmarkSearch, () => {
  if (suspendBookmarkReload.value) return
  if (bookmarkSearchTimer) {
    window.clearTimeout(bookmarkSearchTimer)
  }

  bookmarkSearchTimer = window.setTimeout(() => {
    if (props.modelValue && activeTab.value === 'bookmark') {
      void loadBookmarks(true)
    }
  }, 300)
})

onBeforeUnmount(() => {
  if (imageSearchTimer) {
    window.clearTimeout(imageSearchTimer)
  }
  if (fileSearchTimer) {
    window.clearTimeout(fileSearchTimer)
  }
  if (bookmarkSearchTimer) {
    window.clearTimeout(bookmarkSearchTimer)
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
  overflow-y: auto;
}

.resource-load-more {
  display: flex;
  justify-content: center;
  padding: 16px 0 8px;
}

.resource-picker__feedback {
  margin-top: 4px;
}

.resource-tag-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
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

.resource-toolbar--bookmark {
  grid-template-columns: minmax(0, 1fr) 180px auto;
}

.upload-box {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 12px;
  align-items: center;
}

.drive-breadcrumbs {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px;
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
