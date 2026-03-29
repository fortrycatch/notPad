<template>
  <div ref="containerRef" class="files-page">
    <div class="row">
      <div class="page-head">
        <!-- <div class="page-icon">
          <v-icon icon="mdi-folder-multiple-outline" size="22" />
        </div> -->
        <div>
          <!-- <div class="page-title">共 {{ itemCount }} 项</div> -->
          <div class="page-subtitle">
            {{ activeSortLabel
            }}{{ search.trim() ? ` · 搜索「${search.trim()}」` : ''
            }}{{ searchScope === 'all' ? ' · 全局搜索' : '' }}
          </div>
        </div>
      </div>

      <div class="toolbar-actions desktop-toolbar">
        <div class="search-wrap">
          <v-text-field
            v-model="search"
            placeholder="搜索文件或文件夹"
            prepend-inner-icon="mdi-magnify"
            variant="filled"
            density="comfortable"
            :loading="loading"
            hide-details
            single-line
            rounded="lg"
            color="primary"
            bg-color="surface-variant"
            class="search-field"
          />
        </div>

        <v-btn-toggle v-model="searchScope" mandatory divided class="scope-toggle">
          <v-btn value="current" class="scope-btn">当前目录</v-btn>
          <v-btn value="all" class="scope-btn">所有文件</v-btn>
        </v-btn-toggle>

        <v-btn-toggle v-model="sortKey" mandatory divided class="sort-toggle">
          <v-btn
            v-for="option in sortOptions"
            :key="option.value"
            :value="option.value"
            :icon="option.icon"
            :title="option.label"
          />
        </v-btn-toggle>

        <v-btn color="primary" variant="tonal" prepend-icon="mdi-folder-plus" @click="openFolderDialog">
          新建文件夹
        </v-btn>
        <v-btn color="primary" prepend-icon="mdi-upload" @click="openUploadDialog">
          上传文件
        </v-btn>
      </div>
    </div>

    <div class="breadcrumbs">
      <v-btn variant="text" prepend-icon="mdi-home" @click="goToFolder(null)">
        根目录
      </v-btn>
      <template v-for="folder in breadcrumbs" :key="folder.id">
        <v-icon size="18">mdi-chevron-right</v-icon>
        <v-btn variant="text" @click="goToFolder(folder.id)">
          {{ folder.name }}
        </v-btn>
      </template>
    </div>

    <div v-if="isInitialLoading" class="files-skeleton">
      <v-skeleton-loader
        v-for="item in skeletonItems"
        :key="item"
        class="file-skeleton"
        type="list-item-avatar-two-line"
      />
    </div>

    <div v-else-if="folders.length === 0 && files.length === 0" class="empty-state">
      <v-icon size="64" color="primary" class="mb-4">mdi-folder-open-outline</v-icon>
      <h3 class="text-h6 mb-2">
        {{ search.trim() ? '没有匹配的内容' : '当前目录为空' }}
      </h3>
      <p class="empty-description">
        试试上传文件、新建文件夹，或调整搜索条件
      </p>
    </div>

    <v-card v-else class="files-panel" rounded="xl">
      <v-list lines="two" class="file-list">
        <v-list-item
          v-for="folder in folders"
          :key="folder.id"
          class="entry-item"
          @click="goToFolder(folder.id)"
        >
          <template #prepend>
            <v-avatar color="primary" variant="tonal">
              <v-icon>mdi-folder</v-icon>
            </v-avatar>
          </template>
          <v-list-item-title>{{ folder.name }}</v-list-item-title>
          <v-list-item-subtitle>{{ formatDate(folder.created_at) }}</v-list-item-subtitle>
          <template #append>
            <div class="file-actions">
              <v-menu>
                <template #activator="{ props: menuProps }">
                  <v-btn variant="text" icon="mdi-dots-vertical" v-bind="menuProps" @click.stop />
                </template>
                <v-list density="compact" min-width="160">
                  <v-list-item
                    prepend-icon="mdi-pencil-outline"
                    title="重命名"
                    @click="openRenameFolder(folder)"
                  />
                </v-list>
              </v-menu>
              <v-btn variant="text" icon="mdi-chevron-right" />
            </div>
          </template>
        </v-list-item>

        <v-list-item
          v-for="file in files"
          :key="file.id"
          class="entry-item"
        >
          <template #prepend>
            <v-avatar color="surface-variant" variant="flat">
              <v-icon>{{ getFileIcon(file.mime_type) }}</v-icon>
            </v-avatar>
          </template>
          <v-list-item-title>{{ file.name }}</v-list-item-title>
          <v-list-item-subtitle>
            {{ formatFileSize(file.size) }} · {{ formatDate(file.created_at) }}
          </v-list-item-subtitle>
          <template #append>
            <div class="file-actions">
              <v-btn
                variant="text"
                icon="mdi-download"
                title="下载"
                @click.stop="downloadFile(file)"
              />
              <v-menu>
                <template #activator="{ props: menuProps }">
                  <v-btn variant="text" icon="mdi-dots-vertical" v-bind="menuProps" @click.stop />
                </template>
                <v-list density="compact" min-width="160">
                  <v-list-item
                    prepend-icon="mdi-pencil-outline"
                    title="重命名"
                    @click="openRenameFile(file)"
                  />
                  <v-list-item
                    prepend-icon="mdi-link-variant"
                    title="复制链接"
                    @click="copyFileUrl(file)"
                  />
                  <v-list-item
                    prepend-icon="mdi-bookmark-plus-outline"
                    title="收藏"
                    @click="openBookmarkForFile(file)"
                  />
                </v-list>
              </v-menu>
            </div>
          </template>
        </v-list-item>
      </v-list>
    </v-card>

    <div v-if="loadingMore" class="pagination">
      <v-progress-circular indeterminate color="primary" size="32" />
    </div>
    <div v-else-if="!hasMore && (folders.length > 0 || files.length > 0)" class="pagination pagination-text">
      没有更多内容了
    </div>

    <div class="mobile-toolbar">
      <v-btn variant="text" prepend-icon="mdi-magnify" @click="showSearchDialog = true">
        搜索
      </v-btn>

      <v-menu>
        <template #activator="{ props }">
          <v-btn variant="text" prepend-icon="mdi-sort" v-bind="props">
            排序
          </v-btn>
        </template>
        <v-list>
          <v-list-item
            v-for="option in sortOptions"
            :key="option.value"
            :active="sortKey === option.value"
            @click="setSortKey(option.value)"
          >
            <template #prepend>
              <v-icon>{{ option.icon }}</v-icon>
            </template>
            <v-list-item-title>{{ option.label }}</v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>

      <v-btn variant="text" prepend-icon="mdi-folder-plus" @click="openFolderDialog">
        新建
      </v-btn>

      <v-btn color="primary" prepend-icon="mdi-upload" @click="openUploadDialog">
        上传
      </v-btn>
    </div>

    <v-dialog v-model="showSearchDialog" max-width="480">
      <v-card>
        <v-card-title class="dialog-title">搜索网盘</v-card-title>
        <v-card-text class="search-dialog-body">
          <v-text-field
            v-model="search"
            placeholder="按名称搜索"
            prepend-inner-icon="mdi-magnify"
            density="comfortable"
            variant="filled"
            hide-details
            autofocus
            rounded="lg"
            color="primary"
            bg-color="surface-variant"
          />
          <div class="mobile-scope-label">搜索范围</div>
          <v-btn-toggle v-model="searchScope" mandatory divided class="scope-toggle scope-toggle--stacked">
            <v-btn value="current" class="scope-btn scope-btn--block">当前目录</v-btn>
            <v-btn value="all" class="scope-btn scope-btn--block">所有文件</v-btn>
          </v-btn-toggle>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="search = ''">清空</v-btn>
          <v-btn color="primary" @click="showSearchDialog = false">完成</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="showUploadDialog" max-width="560">
      <v-card>
        <v-card-title class="dialog-title">上传文件</v-card-title>
        <v-card-text>
          <div class="d-flex flex-column ga-4">
            <v-file-input
              v-model="uploadFileValue"
              label="选择文件"
              prepend-icon="mdi-paperclip"
              variant="outlined"
              show-size
              :disabled="uploading"
            />
            <template v-if="uploading">
              <v-progress-linear
                :model-value="uploadPercent"
                color="primary"
              />
              <div class="text-caption text-medium-emphasis text-end">
                {{ uploadPercent }}%
              </div>
            </template>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn :disabled="uploading" @click="showUploadDialog = false">取消</v-btn>
          <v-btn color="primary" :loading="uploading" @click="uploadFile">
            上传
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="showFolderDialog" max-width="420">
      <v-card>
        <v-card-title class="dialog-title">新建文件夹</v-card-title>
        <v-card-text>
          <v-text-field
            v-model="newFolderName"
            label="文件夹名称"
            variant="outlined"
            hide-details
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="showFolderDialog = false">取消</v-btn>
          <v-btn color="primary" :loading="creatingFolder" @click="createFolder">
            创建
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="showRenameDialog" max-width="420">
      <v-card>
        <v-card-title class="dialog-title">重命名</v-card-title>
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

    <v-snackbar v-model="showAlert" timeout="2800" location="top">
      {{ alertMessage }}
    </v-snackbar>

    <AddBookmarkDialog
      v-model="showBookmarkDialog"
      resource-type="file"
      :resource-id="bookmarkFileId"
      :resource-title="bookmarkFileName"
      :resource-url="bookmarkFileUrl"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { server } from '../server'
import { putWithUploadProgress } from '../utils/putWithUploadProgress'
import { formatFileSize, formatDate, getFileIcon } from '../utils/format'
import { downloadUrl } from '../utils/download'
import AddBookmarkDialog from '../components/compose/AddBookmarkDialog.vue'

type SortKey = 'time_desc' | 'time' | 'name'
type SearchScope = 'current' | 'all'

interface DriveFolder {
  id: string
  name: string
  parent_id: string | null
  created_at: string | Date
}

interface DriveFile {
  id: number
  name: string
  oss_key: string
  size: number
  mime_type: string
  folder_id: string | null
  created_at: string | Date
  public_url: string
}

const sortOptions: Array<{ value: SortKey; label: string; icon: string }> = [
  { value: 'time_desc', label: '最新优先', icon: 'mdi-clock-time-eight-outline' },
  { value: 'time', label: '最早优先', icon: 'mdi-clock-time-eight' },
  { value: 'name', label: '名称排序', icon: 'mdi-format-font-size-decrease' }
]

const route = useRoute()
const router = useRouter()

const showUploadDialog = ref(false)
const showFolderDialog = ref(false)
const showSearchDialog = ref(false)
const uploadFileValue = ref<File | File[] | null>(null)
const newFolderName = ref('')
const page = ref(0)
const loading = ref(false)
const loadingMore = ref(false)
const uploading = ref(false)
const uploadPercent = ref(0)
const creatingFolder = ref(false)
const hasMore = ref(true)
const search = ref('')
const searchScope = ref<SearchScope>('current')
const sortKey = ref<SortKey>('time_desc')
const showAlert = ref(false)
const alertMessage = ref('')
const containerRef = ref<HTMLElement | null>(null)
const currentFolder = ref<DriveFolder | null>(null)
const breadcrumbs = ref<DriveFolder[]>([])
const folders = ref<DriveFolder[]>([])
const files = ref<DriveFile[]>([])
const showRenameDialog = ref(false)
const renameValue = ref('')
const renaming = ref(false)
const renameTarget = ref<{ type: 'file'; id: number } | { type: 'folder'; id: string } | null>(null)

const showBookmarkDialog = ref(false)
const bookmarkFileId = ref('')
const bookmarkFileName = ref('')
const bookmarkFileUrl = ref('')

const openBookmarkForFile = (file: DriveFile) => {
  bookmarkFileId.value = String(file.id)
  bookmarkFileName.value = file.name
  bookmarkFileUrl.value = file.public_url || ''
  showBookmarkDialog.value = true
}

const skeletonItems = Array.from({ length: 8 }, (_, index) => index)

const itemCount = computed(() => folders.value.length + files.value.length)
const isInitialLoading = computed(() => loading.value && folders.value.length === 0 && files.value.length === 0)
const activeSortLabel = computed(() => {
  return sortOptions.find((option) => option.value === sortKey.value)?.label || '最新优先'
})

const openUploadDialog = () => {
  uploadPercent.value = 0
  showUploadDialog.value = true
}

const openFolderDialog = () => {
  showFolderDialog.value = true
}

const setSortKey = (key: SortKey) => {
  sortKey.value = key
}

const currentFolderId = computed(() => {
  const folder = route.query.folder
  return typeof folder === 'string' && folder.trim() !== '' ? folder : null
})

const showMessage = (message: string) => {
  alertMessage.value = message
  showAlert.value = true
}

const getSelectedFile = () => {
  if (Array.isArray(uploadFileValue.value)) {
    return uploadFileValue.value[0] ?? null
  }
  return uploadFileValue.value
}

const getList = async () => {
  if (loading.value) return

  loading.value = true
  try {
    const result = await server.file_drive.list.query({
      folder_id: currentFolderId.value,
      offset: 0,
      sort: sortKey.value,
      search: search.value.trim(),
      search_scope: searchScope.value
    }) as {
      currentFolder: DriveFolder | null
      breadcrumbs: DriveFolder[]
      folders: DriveFolder[]
      files: DriveFile[]
      hasMore: boolean
    }

    currentFolder.value = result.currentFolder
    breadcrumbs.value = result.breadcrumbs
    folders.value = result.folders
    files.value = result.files
    page.value = 1
    hasMore.value = result.hasMore
  } catch (error) {
    console.error('加载网盘列表失败:', error)
    showMessage('加载网盘失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

const loadMore = async () => {
  if (loading.value || loadingMore.value || !hasMore.value) return

  loadingMore.value = true
  try {
    const result = await server.file_drive.list.query({
      folder_id: currentFolderId.value,
      offset: page.value,
      sort: sortKey.value,
      search: search.value.trim(),
      search_scope: searchScope.value
    }) as {
      folders: DriveFolder[]
      files: DriveFile[]
      hasMore: boolean
    }

    if (result.folders.length === 0 && result.files.length === 0) {
      hasMore.value = false
      return
    }

    folders.value.push(...result.folders)
    files.value.push(...result.files)
    page.value++
    hasMore.value = result.hasMore
  } catch (error) {
    console.error('加载更多网盘内容失败:', error)
    showMessage('加载更多失败，请稍后重试')
  } finally {
    loadingMore.value = false
  }
}

const goToFolder = async (folderId: string | null) => {
  const query = { ...route.query }
  if (folderId) {
    query.folder = folderId
  } else {
    delete query.folder
  }
  await router.replace({ query })
}

const createFolder = async () => {
  const name = newFolderName.value.trim()
  if (!name) {
    showMessage('请输入文件夹名称')
    return
  }

  try {
    creatingFolder.value = true
    await server.file_drive.createFolder.mutate({
      name,
      parent_id: currentFolderId.value
    })
    newFolderName.value = ''
    showFolderDialog.value = false
    showMessage('文件夹已创建')
    await getList()
  } catch (error) {
    console.error('创建文件夹失败:', error)
    showMessage('创建文件夹失败，请检查名称是否重复')
  } finally {
    creatingFolder.value = false
  }
}

const uploadFile = async () => {
  const file = getSelectedFile()
  if (!file) {
    showMessage('请选择文件')
    return
  }

  const mimeType = file.type || 'application/octet-stream'

  try {
    uploading.value = true
    uploadPercent.value = 0
    const uploadUrl = await server.file_drive.getUploadUrl.query({
      filename: file.name,
      type: mimeType,
      folder_id: currentFolderId.value
    })

    await putWithUploadProgress(uploadUrl.url, file, mimeType, (loaded, total) => {
      if (total > 0) {
        uploadPercent.value = Math.min(100, Math.round((loaded / total) * 100))
      }
    })

    await server.file_drive.addFile.mutate({
      name: file.name,
      filename: uploadUrl.filename,
      folder_id: currentFolderId.value,
      mime_type: mimeType
    })

    uploadFileValue.value = null
    showUploadDialog.value = false
    showMessage('文件上传成功')
    await getList()
  } catch (error) {
    console.error('上传文件失败:', error)
    showMessage('上传文件失败，请稍后重试')
  } finally {
    uploading.value = false
    uploadPercent.value = 0
  }
}

const copyFileUrl = async (file: DriveFile) => {
  await navigator.clipboard.writeText(file.public_url)
  showMessage('链接已复制')
}

const downloadFile = (file: DriveFile) => {
  downloadUrl(file.public_url)
}

const openRenameFolder = (folder: DriveFolder) => {
  renameTarget.value = { type: 'folder', id: folder.id }
  renameValue.value = folder.name
  showRenameDialog.value = true
}

const openRenameFile = (file: DriveFile) => {
  renameTarget.value = { type: 'file', id: file.id }
  renameValue.value = file.name
  showRenameDialog.value = true
}

const confirmRename = async () => {
  const name = renameValue.value.trim()
  if (!name || !renameTarget.value) return

  renaming.value = true
  try {
    if (renameTarget.value.type === 'file') {
      await server.file_drive.renameFile.mutate({ id: renameTarget.value.id, name })
    } else {
      await server.file_drive.renameFolder.mutate({ id: renameTarget.value.id, name })
    }
    showRenameDialog.value = false
    showMessage('重命名成功')
    await getList()
  } catch (error) {
    console.error('重命名失败:', error)
    showMessage('重命名失败')
  } finally {
    renaming.value = false
  }
}

watch(currentFolderId, () => {
  void getList()
}, { immediate: true })

watch(sortKey, () => {
  void getList()
})

watch(searchScope, () => {
  void getList()
})

let searchTimer: number | null = null
watch(search, () => {
  if (searchTimer) {
    window.clearTimeout(searchTimer)
  }

  searchTimer = window.setTimeout(() => {
    void getList()
  }, 300)
})

let scrollTimer: number | null = null
const handleScroll = () => {
  if (scrollTimer) {
    window.clearTimeout(scrollTimer)
  }

  scrollTimer = window.setTimeout(() => {
    if (loading.value || loadingMore.value || !hasMore.value) return

    const container = containerRef.value?.parentElement || window
    const scrollTop = container === window
      ? window.scrollY || document.documentElement.scrollTop
      : (container as HTMLElement).scrollTop
    const scrollHeight = container === window
      ? document.documentElement.scrollHeight
      : (container as HTMLElement).scrollHeight
    const clientHeight = container === window
      ? window.innerHeight
      : (container as HTMLElement).clientHeight

    if (scrollTop + clientHeight >= scrollHeight - 100) {
      void loadMore()
    }
  }, 200)
}

onMounted(() => {
  window.addEventListener('scroll', handleScroll, { passive: true })
})

onUnmounted(() => {
  window.removeEventListener('scroll', handleScroll)
  if (searchTimer) {
    window.clearTimeout(searchTimer)
  }
  if (scrollTimer) {
    window.clearTimeout(scrollTimer)
  }
})
</script>

<style scoped>
.files-page {
  min-height: 100%;
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding-bottom: 32px;
}

.row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
}

.page-head {
  display: flex;
  align-items: center;
  gap: 14px;
  min-width: 0;
}

.page-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 14px;
  background: rgb(var(--v-theme-surface-variant));
  color: rgb(var(--v-theme-primary));
  flex-shrink: 0;
}

.page-title {
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
}

.page-subtitle {
  margin-top: 4px;
  color: rgb(var(--v-theme-on-surface-variant));
  font-size: 14px;
}

.toolbar-actions {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
  min-width: 0;
  justify-content: flex-end;
  flex-wrap: wrap;
}

.search-wrap {
  flex: 1 1 240px;
  min-width: 200px;
  max-width: 420px;
}

.search-field {
  width: 100%;
}

.scope-toggle {
  flex-shrink: 0;
}

.scope-btn {
  min-width: 96px;
  padding-inline: 16px;
  text-transform: none;
  letter-spacing: normal;
  font-weight: 600;
}

.sort-toggle {
  flex-shrink: 0;
}

.breadcrumbs {
  display: flex;
  align-items: center;
  flex-wrap: nowrap;
  gap: 4px;
  overflow-x: auto;
  padding-bottom: 4px;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: thin;
}

.files-skeleton {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 8px 0;
}

.file-skeleton {
  border-radius: 16px;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  min-height: 320px;
  margin: 24px 0;
  padding: 32px 24px;
  border-radius: 20px;
  background: rgb(var(--v-theme-surface));
}

.empty-description {
  color: rgb(var(--v-theme-on-surface-variant));
}

.files-panel {
  padding: 8px;
}

.file-list {
  padding: 0;
}

.entry-item {
  border-radius: 16px;
}

.entry-item + .entry-item {
  margin-top: 4px;
}

.file-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}

.pagination {
  display: flex;
  justify-content: center;
  padding: 8px 0 24px;
}

.pagination-text {
  color: rgb(var(--v-theme-on-surface-variant));
}

.dialog-title {
  padding-bottom: 0;
  font-size: 18px;
  font-weight: 700;
}

.search-dialog-body {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.mobile-scope-label {
  font-size: 13px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.72);
}

.scope-toggle--stacked {
  flex-direction: column;
  width: 100%;
}

.scope-toggle--stacked .scope-btn--block {
  width: 100%;
  min-height: 48px;
  justify-content: center;
  text-transform: none;
  letter-spacing: normal;
  font-weight: 600;
}

.mobile-toolbar {
  display: none;
}

@media (max-width: 900px) {
  .desktop-toolbar {
    display: none;
  }
}

@media (max-width: 760px) {
  .files-page {
    padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 104px);
  }

  .row {
    align-items: flex-start;
  }

  .page-title {
    font-size: 24px;
  }

  .page-subtitle {
    display: none;
  }

  .mobile-toolbar {
    position: fixed;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 30;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 6px;
    padding: 10px 8px calc(env(safe-area-inset-bottom, 0px) + 10px);
    border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
    background: rgba(var(--v-theme-surface), 0.96);
    backdrop-filter: blur(12px);
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.16);
  }

  .mobile-toolbar > * {
    flex: 1 1 auto;
    min-width: 0;
  }

  .mobile-toolbar :deep(.v-btn) {
    padding-inline: 6px;
    font-size: 12px;
  }
}

@media (max-width: 700px) {
  .row {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
