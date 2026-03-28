<template>
  <div ref="containerRef" class="images-page">
    <div class="row">
      <div class="page-head">
        <div class="page-icon">
          <v-icon icon="mdi-image-multiple-outline" size="22" />
        </div>
        <div>
          <div class="page-title">图床</div>
          <div class="page-subtitle">
            {{ activeSortLabel }}{{ search ? ` · 搜索“${search}”` : ' · 支持粘贴上传' }}
          </div>
        </div>
      </div>

      <div class="toolbar-actions desktop-toolbar">
        <div class="search-wrap">
          <v-text-field
            v-model="search"
            placeholder="搜索图片"
            prepend-inner-icon="mdi-magnify"
            density="comfortable"
            variant="filled"
            :loading="loading"
            hide-details
            single-line
            rounded="lg"
            color="primary"
            bg-color="surface-variant"
            class="search-field"
          />
        </div>

        <v-btn-toggle v-model="sortKey" mandatory divided class="sort-toggle">
          <v-btn
            v-for="option in sortOptions"
            :key="option.value"
            :value="option.value"
            :icon="option.icon"
            :title="option.label"
          />
        </v-btn-toggle>

        <v-btn variant="tonal" prepend-icon="mdi-tag-multiple" @click="showTagManager = true">
          标签管理
        </v-btn>

        <v-btn color="primary" prepend-icon="mdi-upload" @click="openUploadDialog">
          上传图片
        </v-btn>
      </div>
    </div>

    <div v-if="tags.length > 0" class="tag-filter-row">
      <v-chip
        :color="activeTagId === null ? 'primary' : undefined"
        :variant="activeTagId === null ? 'elevated' : 'outlined'"
        @click="activeTagId = null"
      >
        全部
      </v-chip>
      <v-chip
        v-for="tag in tags"
        :key="tag.id"
        :color="activeTagId === tag.id ? 'primary' : undefined"
        :variant="activeTagId === tag.id ? 'elevated' : 'outlined'"
        @click="activeTagId = tag.id"
      >
        {{ tag.name }}
      </v-chip>
    </div>

    <div v-if="isInitialLoading" class="images-grid">
      <v-skeleton-loader
        v-for="item in skeletonItems"
        :key="item"
        class="image-skeleton"
        type="image, article"
      />
    </div>

    <div v-else-if="list.length > 0" class="images-grid">
      <ImageCard
        v-for="image in list"
        :key="image.url"
        :image="image"
        :all-tags="tags"
        @renamed="getList()"
        @tag-changed="getList()"
      />
    </div>

    <div v-else class="empty-state">
      <v-icon size="64" color="primary" class="mb-4">mdi-image-off-outline</v-icon>
      <h3 class="text-h6 mb-2">还没有图片</h3>
      <p class="empty-description">试试上传图片，或检查当前搜索条件</p>
    </div>

    <div v-if="loadingMore" class="pagination">
      <v-progress-circular indeterminate color="primary" size="32" />
    </div>
    <div v-else-if="!hasMore && list.length > 0" class="pagination pagination-text">
      没有更多图片了
    </div>
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
          @click="sortKey = option.value"
        >
          <template #prepend>
            <v-icon>{{ option.icon }}</v-icon>
          </template>
          <v-list-item-title>{{ option.label }}</v-list-item-title>
        </v-list-item>
      </v-list>
    </v-menu>

    <v-btn variant="text" prepend-icon="mdi-tag-multiple" @click="showTagManager = true">
      标签
    </v-btn>

    <v-btn color="primary" prepend-icon="mdi-upload" @click="openUploadDialog">
      上传
    </v-btn>
  </div>

  <v-dialog v-model="showSearchDialog" max-width="480">
    <v-card>
      <v-card-title class="dialog-title">搜索图片</v-card-title>
      <v-card-text>
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
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn variant="text" @click="search = ''">清空</v-btn>
        <v-btn color="primary" @click="showSearchDialog = false">完成</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <v-dialog v-model="showUploadDialog" max-width="600">
    <v-card>
      <v-card-title class="dialog-title">上传图片</v-card-title>
      <v-card-text>
        <div class="upload-tip">
          选择图片、拖入文件，或直接在页面中粘贴截图/图片文件。
        </div>
        <v-file-input
          v-model="file"
          label="选择或拖动图片到这里"
          accept="image/*"
          prepend-icon="mdi-paperclip"
          variant="outlined"
          rounded="lg"
          show-size
        />
        <div v-if="tags.length > 0" class="upload-tags-section">
          <div class="text-caption text-medium-emphasis mb-1">标签</div>
          <div class="tag-chips-row">
            <v-chip
              v-for="tag in tags"
              :key="tag.id"
              :color="uploadSelectedTagIds.includes(tag.id) ? 'primary' : undefined"
              :variant="uploadSelectedTagIds.includes(tag.id) ? 'elevated' : 'outlined'"
              size="small"
              @click="toggleUploadTag(tag.id)"
            >
              {{ tag.name }}
            </v-chip>
          </div>
        </div>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="showUploadDialog = false">取消</v-btn>
        <v-btn color="primary" @click="uploadImage" :loading="uploading">上传</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <v-dialog v-model="showTagManager" max-width="480">
    <v-card>
      <v-card-title class="dialog-title">标签管理</v-card-title>
      <v-card-text class="tag-manager-body">
        <div class="tag-create-row">
          <v-text-field
            v-model="newTagName"
            label="新标签名称"
            variant="outlined"
            density="comfortable"
            hide-details
            @keydown.enter="createTag"
          />
          <v-btn color="primary" :loading="creatingTag" @click="createTag">添加</v-btn>
        </div>
        <v-list v-if="tags.length > 0" density="compact" class="tag-list">
          <v-list-item v-for="tag in tags" :key="tag.id">
            <v-list-item-title>{{ tag.name }}</v-list-item-title>
            <template #append>
              <v-btn
                icon="mdi-delete-outline"
                size="small"
                variant="text"
                color="error"
                @click="deleteTag(tag.id)"
              />
            </template>
          </v-list-item>
        </v-list>
        <div v-else class="text-medium-emphasis text-center pa-4">暂无标签</div>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="showTagManager = false">关闭</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <v-snackbar v-model="showAlert" color="warning" timeout="3000" location="top">
    <v-icon start>mdi-alert-circle</v-icon>
    {{ alertMessage }}
  </v-snackbar>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import ImageCard from '../components/compose/ImageCard.vue'
import { server } from '../server'

type SortKey = 'time_desc' | 'time' | 'name'

interface TagItem {
  id: number
  name: string
}

const sortOptions: Array<{ value: SortKey; label: string; icon: string }> = [
  { value: 'time_desc', label: '最新上传', icon: 'mdi-clock-time-eight-outline' },
  { value: 'time', label: '最早上传', icon: 'mdi-clock-time-eight' },
  { value: 'name', label: '名称排序', icon: 'mdi-format-font-size-decrease' }
]

const showUploadDialog = ref(false)
const showSearchDialog = ref(false)
const showTagManager = ref(false)
const file = ref<File | null>(null)
const page = ref(0)
const showAlert = ref(false)
const alertMessage = ref('')
const sortKey = ref<SortKey>('time_desc')
const search = ref('')
const loading = ref(false)
const loadingMore = ref(false)
const uploading = ref(false)
const hasMore = ref(true)
const containerRef = ref<HTMLElement | null>(null)
const list = ref<any[]>([])
const tags = ref<TagItem[]>([])
const activeTagId = ref<number | null>(null)
const newTagName = ref('')
const creatingTag = ref(false)
const uploadSelectedTagIds = ref<number[]>([])

const PAGE_SIZE = 30
const skeletonItems = Array.from({ length: 8 }, (_, index) => index)

const isInitialLoading = computed(() => loading.value && list.value.length === 0)
const activeSortLabel = computed(() => {
  return sortOptions.find((option) => option.value === sortKey.value)?.label || '最新上传'
})

const showAlert3s = (message: string) => {
  showAlert.value = true
  alertMessage.value = message
}

const openUploadDialog = () => {
  uploadSelectedTagIds.value = []
  showUploadDialog.value = true
}

const toggleUploadTag = (id: number) => {
  const idx = uploadSelectedTagIds.value.indexOf(id)
  if (idx >= 0) {
    uploadSelectedTagIds.value.splice(idx, 1)
  } else {
    uploadSelectedTagIds.value.push(id)
  }
}

const uploadImage = async () => {
  if (!file.value) {
    showAlert3s('请选择文件')
    return
  }

  try {
    uploading.value = true
    const uploadUrl = await server.image_bed.getUploadUrl.query({
      filename: file.value.name,
      type: file.value.type
    })

    const res = await fetch(uploadUrl.url, {
      method: 'PUT',
      body: file.value
    })

    if (!res.ok) {
      throw new Error('上传失败')
    }

    const result = await server.image_bed.addImage.mutate({
      name: file.value.name,
      filename: uploadUrl.filename,
      remark: ''
    })

    if (uploadSelectedTagIds.value.length > 0 && result.insertId) {
      await Promise.all(
        uploadSelectedTagIds.value.map((tagId) =>
          server.image_bed.addTagToImage.mutate({ image_id: result.insertId, tag_id: tagId })
        )
      )
    }

    file.value = null
    uploadSelectedTagIds.value = []
    showUploadDialog.value = false
    await getList()
  } catch (error) {
    console.error('上传图片失败:', error)
    showAlert3s('上传失败，请稍后重试')
  } finally {
    uploading.value = false
  }
}

function pasteHandler(e: ClipboardEvent) {
  const items = e.clipboardData?.items
  if (!items?.length) return

  const pasteFile = Array.from(items).find((item) => item.kind === 'file')?.getAsFile()
  if (!pasteFile) return

  e.preventDefault()
  file.value = pasteFile
  showUploadDialog.value = true
}

async function loadTags() {
  tags.value = await server.image_bed.listTags.query() as TagItem[]
}

async function createTag() {
  const name = newTagName.value.trim()
  if (!name) return

  creatingTag.value = true
  try {
    await server.image_bed.createTag.mutate({ name })
    newTagName.value = ''
    await loadTags()
  } catch (error) {
    console.error('创建标签失败:', error)
    showAlert3s('创建标签失败')
  } finally {
    creatingTag.value = false
  }
}

async function deleteTag(id: number) {
  try {
    await server.image_bed.deleteTag.mutate({ id })
    if (activeTagId.value === id) {
      activeTagId.value = null
    }
    await loadTags()
    await getList()
  } catch (error) {
    console.error('删除标签失败:', error)
    showAlert3s('删除标签失败')
  }
}

async function getList() {
  if (loading.value) return

  loading.value = true
  try {
    const result = await server.image_bed.list.query({
      user_id: 'admin',
      offset: 0,
      sort: sortKey.value,
      search: search.value,
      tag_id: activeTagId.value
    })
    list.value = result
    page.value = 1
    hasMore.value = result.length >= PAGE_SIZE
  } catch (error) {
    console.error('获取图片列表失败:', error)
    showAlert3s('获取图片失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

async function loadMore() {
  if (loading.value || loadingMore.value || !hasMore.value) return

  loadingMore.value = true
  try {
    const more = await server.image_bed.list.query({
      user_id: 'admin',
      offset: page.value,
      sort: sortKey.value,
      search: search.value,
      tag_id: activeTagId.value
    })
    if (more.length === 0) {
      hasMore.value = false
      return
    }
    list.value.push(...more)
    page.value++
    if (more.length < PAGE_SIZE) {
      hasMore.value = false
    }
  } catch (error) {
    console.error('加载更多图片失败:', error)
    showAlert3s('加载更多失败，请稍后重试')
  } finally {
    loadingMore.value = false
  }
}

watch(sortKey, () => {
  getList()
})

watch(activeTagId, () => {
  getList()
})

let searchTimer: number | null = null
watch(search, () => {
  if (searchTimer) {
    clearTimeout(searchTimer)
  }
  searchTimer = window.setTimeout(async () => {
    await getList()
  }, 400)
})

let scrollTimer: number | null = null
const handleScroll = () => {
  if (scrollTimer) {
    clearTimeout(scrollTimer)
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
      loadMore()
    }
  }, 200)
}

onMounted(() => {
  document.addEventListener('paste', pasteHandler)
  window.addEventListener('scroll', handleScroll, { passive: true })
  loadTags()
  getList()
})

onUnmounted(() => {
  document.removeEventListener('paste', pasteHandler)
  window.removeEventListener('scroll', handleScroll)
  if (searchTimer) {
    clearTimeout(searchTimer)
  }
  if (scrollTimer) {
    clearTimeout(scrollTimer)
  }
})
</script>

<style scoped>
.images-page {
  min-height: 100%;
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
  gap: 16px;
  flex: 1;
  min-width: 0;
  justify-content: flex-end;
}

.search-wrap {
  flex: 1 1 320px;
  min-width: 220px;
  max-width: 520px;
}

.search-field {
  width: 100%;
}

.sort-toggle {
  flex-shrink: 0;
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.tag-filter-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 12px 0 4px;
}

.tag-manager-body {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.tag-create-row {
  display: flex;
  gap: 12px;
  align-items: center;
}

.tag-list {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 12px;
  padding: 0;
}

.images-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 16px;
  padding: 20px 0 16px;
}

.image-skeleton {
  border-radius: 20px;
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

.upload-tip {
  margin-bottom: 16px;
  color: rgb(var(--v-theme-on-surface-variant));
  line-height: 1.6;
}

.upload-tags-section {
  margin-top: 8px;
}

.tag-chips-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
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
  .images-page {
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
    gap: 10px;
    padding: 10px 12px calc(env(safe-area-inset-bottom, 0px) + 10px);
    border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
    background: rgba(var(--v-theme-surface), 0.96);
    backdrop-filter: blur(12px);
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.16);
  }

  .mobile-toolbar > * {
    flex: 1 1 auto;
    min-width: 0;
  }
}
</style>