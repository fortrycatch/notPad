<template>
  <div ref="containerRef" class="bookmarks-container">
    <div class="row">
      <div class="page-head">
        <div class="page-icon">
          <v-icon icon="mdi-bookmark-multiple-outline" size="22" />
        </div>
        <div>
          <div class="page-title">书签</div>
          <!-- <div class="page-subtitle">共 {{ list.length }} 条</div> -->
        </div>
      </div>
      <div class="toolbar-actions desktop-toolbar">
        <div class="search-wrap">
          <v-text-field
            v-model="search"
            placeholder="搜索书签"
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
          <v-btn value="time_desc" icon="mdi-sort-clock-descending-outline" title="最新优先" />
          <v-btn value="time" icon="mdi-sort-clock-ascending-outline" title="最早优先" />
          <v-btn value="name" icon="mdi-sort-alphabetical-ascending" title="按名称" />
        </v-btn-toggle>
        <v-btn variant="tonal" prepend-icon="mdi-tag-multiple" @click="showTagManager = true">
          标签管理
        </v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" @click="showAddDialog = true">
          添加书签
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

    <div v-if="typeFilter" class="type-filter-row">
      <v-chip closable @click:close="typeFilter = null">
        <v-icon start size="16">{{ typeIconMap[typeFilter] }}</v-icon>
        {{ typeLabelMap[typeFilter] }}
      </v-chip>
    </div>

    <div v-if="isInitialLoading" class="bookmarks-grid">
      <v-skeleton-loader
        v-for="item in 6"
        :key="item"
        class="bookmark-skeleton"
        type="article"
      />
    </div>

    <div v-else-if="list.length > 0" class="bookmarks-grid">
      <v-card
        v-for="bm in list"
        :key="bm.id"
        class="bookmark-card"
        hover
        elevation="2"
        @click="openBookmark(bm)"
      >
        <div v-if="bm.type === 'image' && bm.url" class="bookmark-card-thumb">
          <v-img
            :src="imageBookmarkThumbSrc(bm.url)"
            :alt="bm.title"
            cover
            height="158"
            class="bookmark-card-thumb-img"
          >
            <template #placeholder>
              <div class="d-flex align-center justify-center fill-height">
                <v-progress-circular indeterminate color="primary" size="32" />
              </div>
            </template>
          </v-img>
        </div>
        <div class="bookmark-card-header">
          <v-icon size="20" class="bookmark-type-icon" :color="typeColorMap[bm.type]">
            {{ typeIconMap[bm.type] }}
          </v-icon>
          <div class="bookmark-card-title-wrap">
            <div class="bookmark-card-title text-truncate">{{ bm.title }}</div>
            <div class="bookmark-card-date">{{ formatDate(bm.created_at) }}</div>
          </div>
          <v-menu>
            <template #activator="{ props }">
              <v-btn
                icon="mdi-dots-vertical"
                variant="text"
                size="small"
                v-bind="props"
                @click.stop
              />
            </template>
            <v-list density="compact" min-width="160">
              <v-list-item
                v-if="bm.type === 'url'"
                prepend-icon="mdi-text-box-outline"
                @click.stop="router.push(`/bookmark/${bm.id}`)"
              >
                <v-list-item-title>详情</v-list-item-title>
              </v-list-item>
              <v-list-item
                v-if="bm.type === 'url' && bm.url"
                prepend-icon="mdi-open-in-new"
                @click.stop="openExternalUrl(bm.url)"
              >
                <v-list-item-title>打开链接</v-list-item-title>
              </v-list-item>
              <v-list-item prepend-icon="mdi-tag-outline" @click.stop="openTagEditor(bm)">
                <v-list-item-title>编辑标签</v-list-item-title>
              </v-list-item>
              <v-list-item prepend-icon="mdi-delete" color="error" @click.stop="confirmRemove(bm)">
                <v-list-item-title>删除</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
        </div>
        <div v-if="bm.description" class="bookmark-card-content">
          {{ truncate(bm.description, 120) }}
        </div>
        <div v-if="bm.url && bm.type === 'url'" class="bookmark-card-url text-truncate">
          {{ bm.url }}
        </div>
        <div v-if="bookmarkTagsMap[bm.id]?.length" class="bookmark-card-footer">
          <v-chip
            v-for="tag in bookmarkTagsMap[bm.id]"
            :key="tag.id"
            size="x-small"
            variant="tonal"
          >
            {{ tag.name }}
          </v-chip>
        </div>
      </v-card>
    </div>

    <div v-else class="empty-state">
      <v-icon size="64" color="primary" class="mb-4">mdi-bookmark-off-outline</v-icon>
      <h3 class="text-h6 mb-2">还没有书签</h3>
      <p class="empty-description">收藏笔记、图片、文件或网页链接到这里</p>
    </div>

    <div v-if="loadingMore" class="pagination">
      <v-progress-circular indeterminate color="primary" size="32" />
    </div>
    <div v-else-if="!hasMore && list.length > 0" class="pagination pagination-text">
      没有更多了
    </div>

    <!-- Add Bookmark Dialog -->
    <v-dialog v-model="showAddDialog" max-width="560">
      <v-card>
        <v-card-title class="d-flex justify-space-between align-center">
          <span class="dialog-title">添加书签</span>
          <v-btn icon="mdi-close" variant="text" @click="showAddDialog = false" />
        </v-card-title>
        <v-card-text class="add-bookmark-body">
          <v-text-field
            v-model="addForm.url"
            label="URL"
            placeholder="粘贴链接后自动获取摘要"
            variant="outlined"
            hide-details
          />
          <div class="d-flex align-center ga-2">
            <v-switch
              v-model="autoFetchEnabled"
              label="自动获取摘要"
              hide-details
              color="primary"
              density="compact"
              inset
            />
            <v-spacer />
            <v-btn
              v-if="!autoFetchEnabled"
              variant="tonal"
              prepend-icon="mdi-web"
              :loading="fetching"
              :disabled="!isUrl(addForm.url)"
              @click="fetchUrlSummary"
            >
              获取摘要
            </v-btn>
            <v-chip v-if="fetching" size="small" color="primary" variant="tonal">
              <v-progress-circular size="14" width="2" indeterminate class="mr-2" />
              正在获取...
            </v-chip>
          </div>
          <v-text-field
            v-model="addForm.title"
            label="标题"
            variant="outlined"
            hide-details
          />
          <v-textarea
            v-model="addForm.description"
            label="描述"
            variant="outlined"
            rows="3"
            hide-details
          />

          <div class="text-subtitle-2">标签</div>
          <div v-if="tags.length > 0" class="tag-chips-row">
            <v-chip
              v-for="tag in tags"
              :key="tag.id"
              :color="addFormTagIds.has(tag.id) ? 'primary' : undefined"
              :variant="addFormTagIds.has(tag.id) ? 'elevated' : 'outlined'"
              @click="toggleAddFormTag(tag.id)"
            >
              {{ tag.name }}
            </v-chip>
          </div>
          <div v-else class="text-medium-emphasis text-body-2">
            暂无标签
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="showAddDialog = false">取消</v-btn>
          <v-btn
            color="primary"
            :loading="addSaving"
            :disabled="!addForm.title.trim()"
            @click="submitAdd"
          >
            添加
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Tag Manager Dialog -->
    <v-dialog v-model="showTagManager" max-width="480">
      <v-card>
        <v-card-title class="dialog-title">标签管理</v-card-title>
        <v-card-text class="tag-manager-body">
          <div class="tag-create-row">
            <v-text-field
              v-model="newTagName"
              label="新标签名称"
              variant="outlined"
              density="compact"
              hide-details
              @keydown.enter="handleCreateTag"
            />
            <v-btn
              variant="tonal"
              :loading="creatingTag"
              :disabled="!newTagName.trim()"
              @click="handleCreateTag"
            >
              创建
            </v-btn>
          </div>
          <v-list v-if="tags.length > 0" density="compact" class="tag-list">
            <v-list-item v-for="tag in tags" :key="tag.id">
              <v-list-item-title>{{ tag.name }}</v-list-item-title>
              <template #append>
                <v-btn
                  icon="mdi-delete-outline"
                  variant="text"
                  size="small"
                  color="error"
                  @click="handleDeleteTag(tag.id)"
                />
              </template>
            </v-list-item>
          </v-list>
          <div v-else class="text-medium-emphasis text-body-2 text-center pa-4">
            暂无标签
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="showTagManager = false">关闭</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Tag Editor Dialog -->
    <v-dialog v-model="showTagEditor" max-width="420">
      <v-card v-if="editingBookmark">
        <v-card-title class="dialog-title">编辑标签</v-card-title>
        <v-card-text>
          <div class="text-body-2 mb-3 text-truncate">{{ editingBookmark.title }}</div>
          <div v-if="tags.length > 0" class="tag-chips-row">
            <v-chip
              v-for="tag in tags"
              :key="tag.id"
              :color="editingTagIds.has(tag.id) ? 'primary' : undefined"
              :variant="editingTagIds.has(tag.id) ? 'elevated' : 'outlined'"
              @click="toggleEditingTag(tag.id)"
            >
              {{ tag.name }}
            </v-chip>
          </div>
          <div v-else class="text-medium-emphasis text-body-2">
            暂无标签，请先在标签管理中创建
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="showTagEditor = false">关闭</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete Confirm Dialog -->
    <v-dialog v-model="showDeleteDialog" max-width="400">
      <v-card>
        <v-card-title class="dialog-title">确认删除</v-card-title>
        <v-card-text>确定要删除这个书签吗？</v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="showDeleteDialog = false">取消</v-btn>
          <v-btn color="error" :loading="deleting" @click="doRemove">删除</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Mobile toolbar -->
    <div class="mobile-toolbar">
      <v-btn variant="text" prepend-icon="mdi-magnify" @click="showMobileSearch = true">搜索</v-btn>
      <v-btn variant="text" prepend-icon="mdi-tag-multiple" @click="showTagManager = true">标签</v-btn>
      <v-btn color="primary" prepend-icon="mdi-plus" @click="showAddDialog = true">添加</v-btn>
    </div>

    <v-dialog v-model="showMobileSearch" max-width="480">
      <v-card>
        <v-card-title class="dialog-title">搜索书签</v-card-title>
        <v-card-text>
          <v-text-field
            v-model="search"
            placeholder="标题或描述关键词"
            prepend-inner-icon="mdi-magnify"
            variant="outlined"
            density="comfortable"
            hide-details
            autofocus
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="showMobileSearch = false">关闭</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <ImagePreviewDialog
      v-model="showImagePreview"
      :image-url="previewImageUrl"
      :image-name="previewImageName"
      :image-id="previewImageId"
      :image-date="previewImageDate"
    />

    <FileDownloadDialog
      v-model="showFileDialog"
      :file-name="fileDialogName"
      :file-url="fileDialogUrl"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { server } from '../../server'
import { useMainStore } from '../../store/mainStore'
import ImagePreviewDialog from '../../components/compose/ImagePreviewDialog.vue'
import FileDownloadDialog from '../../components/compose/FileDownloadDialog.vue'

interface BookmarkItem {
  id: number
  type: string
  title: string
  description: string
  url: string
  ref_id: string | null
  created_at: string | Date
}

interface TagItem {
  id: number
  name: string
}

const IMAGE_HOST = 'https://monika.jkloli.net/'

const router = useRouter()
const mainStore = useMainStore()

const list = ref<BookmarkItem[]>([])
const tags = ref<TagItem[]>([])
const bookmarkTagsMap = ref<Record<number, TagItem[]>>({})

const loading = ref(false)
const isInitialLoading = ref(true)
const loadingMore = ref(false)
const hasMore = ref(true)
const page = ref(0)

const search = ref('')
const sortKey = ref<'time' | 'time_desc' | 'name'>('time_desc')
const activeTagId = ref<number | null>(null)
const typeFilter = ref<string | null>(null)

const showAddDialog = ref(false)
const showTagManager = ref(false)
const showTagEditor = ref(false)
const showDeleteDialog = ref(false)
const showMobileSearch = ref(false)

const addForm = ref({ url: '', title: '', description: '' })
const addFormContent = ref('')
const addFormTagIds = ref(new Set<number>())
const addSaving = ref(false)
const fetching = ref(false)
const autoFetchEnabled = ref(true)
let urlFetchTimer: number | null = null

const newTagName = ref('')
const creatingTag = ref(false)

const editingBookmark = ref<BookmarkItem | null>(null)
const editingTagIds = ref(new Set<number>())

const deletingBookmark = ref<BookmarkItem | null>(null)
const deleting = ref(false)

let searchTimer: number | null = null
let scrollTimer: number | null = null

const typeIconMap: Record<string, string> = {
  url: 'mdi-web',
  image: 'mdi-image',
  note: 'mdi-note-text',
  file: 'mdi-file'
}

const typeLabelMap: Record<string, string> = {
  url: '网页',
  image: '图片',
  note: '笔记',
  file: '文件'
}

const typeColorMap: Record<string, string> = {
  url: 'blue',
  image: 'green',
  note: 'orange',
  file: 'purple'
}

const isUrl = (s: string) => {
  try {
    const u = new URL(s)
    return u.protocol === 'http:' || u.protocol === 'https:'
  } catch {
    return false
  }
}

const truncate = (s: string, max: number) => s.length > max ? s.slice(0, max) + '...' : s

const resolveImageBookmarkUrl = (url: string) => {
  const t = url.trim()
  if (t.startsWith('http://') || t.startsWith('https://')) return t
  return IMAGE_HOST + t.replace(/^\//, '')
}

/** 图床 OSS 缩略图；非 monika 域名则直接用原 URL */
const imageBookmarkThumbSrc = (url: string) => {
  const full = resolveImageBookmarkUrl(url)
  if (!full.includes('monika.jkloli.net')) return full
  const sep = full.includes('?') ? '&' : '?'
  return `${full}${sep}x-oss-process=image/resize,w_480`
}

const openExternalUrl = (url: string) => {
  window.open(url, '_blank', 'noopener,noreferrer')
}

const formatDate = (v: string | Date) => {
  const d = typeof v === 'string' ? new Date(v) : v
  return d.toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

const loadTags = async () => {
  tags.value = await server.bookmark.listTags.query() as TagItem[]
}

const fetchList = async () => {
  loading.value = true
  page.value = 0
  try {
    list.value = await server.bookmark.list.query({
      offset: 0,
      sort: sortKey.value,
      search: search.value,
      tag_id: activeTagId.value,
      type: (typeFilter.value as 'url' | 'image' | 'note' | 'file') ?? null
    }) as BookmarkItem[]
    hasMore.value = list.value.length >= 30
    await loadTagsForList(list.value)
  } finally {
    loading.value = false
    isInitialLoading.value = false
  }
}

const loadMore = async () => {
  if (loadingMore.value || !hasMore.value) return
  loadingMore.value = true
  page.value += 1
  try {
    const more = await server.bookmark.list.query({
      offset: page.value,
      sort: sortKey.value,
      search: search.value,
      tag_id: activeTagId.value,
      type: (typeFilter.value as 'url' | 'image' | 'note' | 'file') ?? null
    }) as BookmarkItem[]
    list.value.push(...more)
    hasMore.value = more.length >= 30
    await loadTagsForList(more)
  } finally {
    loadingMore.value = false
  }
}

const loadTagsForList = async (items: BookmarkItem[]) => {
  const results = await Promise.all(
    items.map(async (bm) => {
      const bmTags = await server.bookmark.getBookmarkTags.query({ bookmark_id: bm.id }) as TagItem[]
      return { id: bm.id, tags: bmTags }
    })
  )
  for (const r of results) {
    bookmarkTagsMap.value[r.id] = r.tags
  }
}

const showImagePreview = ref(false)
const previewImageUrl = ref('')
const previewImageName = ref('')
const previewImageId = ref(0)
const previewImageDate = ref('')

const showFileDialog = ref(false)
const fileDialogName = ref('')
const fileDialogUrl = ref('')

const openBookmark = (bm: BookmarkItem) => {
  if (bm.type === 'url') {
    router.push(`/bookmark/${bm.id}`)
    return
  }
  if (bm.type === 'note' && bm.ref_id) {
    router.push(`/note/${bm.ref_id}`)
    return
  }
  if (bm.type === 'image' && bm.url) {
    previewImageUrl.value = resolveImageBookmarkUrl(bm.url)
    previewImageName.value = bm.title
    previewImageId.value = bm.ref_id ? Number(bm.ref_id) : 0
    previewImageDate.value = typeof bm.created_at === 'string' ? bm.created_at : new Date(bm.created_at).toISOString()
    showImagePreview.value = true
    return
  }
  if (bm.type === 'file' && bm.url) {
    fileDialogName.value = bm.title
    fileDialogUrl.value = bm.url
    showFileDialog.value = true
    return
  }
  router.push(`/bookmark/${bm.id}`)
}

const fetchUrlSummary = async () => {
  if (!isUrl(addForm.value.url)) return
  fetching.value = true
  try {
    const result = await server.bookmark.fetchUrl.query({ url: addForm.value.url })
    if (result.title) addForm.value.title = result.title
    if (result.description) addForm.value.description = result.description
    addFormContent.value = result.content || ''
  } catch (err) {
    console.error('获取摘要失败:', err)
  } finally {
    fetching.value = false
  }
}

const toggleAddFormTag = (id: number) => {
  const s = new Set(addFormTagIds.value)
  if (s.has(id)) s.delete(id)
  else s.add(id)
  addFormTagIds.value = s
}

const submitAdd = async () => {
  const title = addForm.value.title.trim()
  if (!title) return
  addSaving.value = true
  try {
    await server.bookmark.add.mutate({
      type: 'url',
      title,
      description: addForm.value.description,
      content: addFormContent.value || undefined,
      url: addForm.value.url,
      ref_id: null,
      tag_ids: [...addFormTagIds.value]
    })
    showAddDialog.value = false
    addForm.value = { url: '', title: '', description: '' }
    addFormContent.value = ''
    addFormTagIds.value = new Set()
    await fetchList()
  } catch (err) {
    console.error('添加书签失败:', err)
  } finally {
    addSaving.value = false
  }
}

const handleCreateTag = async () => {
  const name = newTagName.value.trim()
  if (!name || creatingTag.value) return
  creatingTag.value = true
  try {
    await server.bookmark.createTag.mutate({ name })
    newTagName.value = ''
    await loadTags()
  } catch (err) {
    console.error('创建标签失败:', err)
  } finally {
    creatingTag.value = false
  }
}

const handleDeleteTag = async (id: number) => {
  try {
    await server.bookmark.deleteTag.mutate({ id })
    if (activeTagId.value === id) activeTagId.value = null
    await loadTags()
    await fetchList()
  } catch (err) {
    console.error('删除标签失败:', err)
  }
}

const openTagEditor = async (bm: BookmarkItem) => {
  editingBookmark.value = bm
  const bmTags = await server.bookmark.getBookmarkTags.query({ bookmark_id: bm.id }) as TagItem[]
  editingTagIds.value = new Set(bmTags.map(t => t.id))
  showTagEditor.value = true
}

const toggleEditingTag = async (tagId: number) => {
  if (!editingBookmark.value) return
  const bmId = editingBookmark.value.id
  if (editingTagIds.value.has(tagId)) {
    await server.bookmark.removeTagFromBookmark.mutate({ bookmark_id: bmId, tag_id: tagId })
    editingTagIds.value.delete(tagId)
    editingTagIds.value = new Set(editingTagIds.value)
  } else {
    await server.bookmark.addTagToBookmark.mutate({ bookmark_id: bmId, tag_id: tagId })
    editingTagIds.value.add(tagId)
    editingTagIds.value = new Set(editingTagIds.value)
  }
  bookmarkTagsMap.value[bmId] = await server.bookmark.getBookmarkTags.query({ bookmark_id: bmId }) as TagItem[]
}

const confirmRemove = (bm: BookmarkItem) => {
  deletingBookmark.value = bm
  showDeleteDialog.value = true
}

const doRemove = async () => {
  if (!deletingBookmark.value) return
  deleting.value = true
  try {
    await server.bookmark.remove.mutate({ id: deletingBookmark.value.id })
    showDeleteDialog.value = false
    await fetchList()
  } catch (err) {
    console.error('删除书签失败:', err)
  } finally {
    deleting.value = false
  }
}

const handleScroll = () => {
  if (scrollTimer) clearTimeout(scrollTimer)
  scrollTimer = window.setTimeout(() => {
    const scrollBottom = document.documentElement.scrollHeight - window.innerHeight - window.scrollY
    if (scrollBottom < 200 && hasMore.value && !loadingMore.value) {
      loadMore()
    }
  }, 150)
}

watch(search, () => {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = window.setTimeout(() => fetchList(), 400)
})

watch(sortKey, () => fetchList())
watch(activeTagId, () => fetchList())
watch(typeFilter, () => fetchList())

watch(() => addForm.value.url, (url) => {
  if (urlFetchTimer) clearTimeout(urlFetchTimer)
  if (!autoFetchEnabled.value || !isUrl(url)) return
  urlFetchTimer = window.setTimeout(() => fetchUrlSummary(), 600)
})

watch(showAddDialog, (open) => {
  if (open) {
    addForm.value = { url: '', title: '', description: '' }
    addFormContent.value = ''
    addFormTagIds.value = new Set()
    loadTags()
  }
})

watch(
  () => mainStore.authenticated,
  (authed) => {
    if (authed) {
      loadTags()
      fetchList()
    }
  }
)

onMounted(() => {
  loadTags()
  fetchList()
  window.addEventListener('scroll', handleScroll, { passive: true })
})

onUnmounted(() => {
  window.removeEventListener('scroll', handleScroll)
  if (scrollTimer) clearTimeout(scrollTimer)
  if (searchTimer) clearTimeout(searchTimer)
  if (urlFetchTimer) clearTimeout(urlFetchTimer)
})
</script>

<style scoped>
.bookmarks-container {
  min-height: 100%;
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
  justify-content: flex-end;
}

.search-wrap {
  max-width: 240px;
  flex: 1;
}

.tag-filter-row,
.type-filter-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 16px 0 0;
}

.bookmarks-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 16px;
  padding: 20px 0 16px;
}

.bookmark-card,
.bookmark-skeleton {
  border-radius: 20px;
}

.bookmark-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 18px;
  cursor: pointer;
  overflow: hidden;
}

.bookmark-card-thumb {
  margin: -18px -18px 12px -18px;
  border-radius: 20px 20px 0 0;
  overflow: hidden;
  background: rgba(var(--v-theme-on-surface), 0.06);
}

.bookmark-card-thumb-img {
  display: block;
}

.bookmark-card-header {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.bookmark-type-icon {
  margin-top: 2px;
  flex-shrink: 0;
}

.bookmark-card-title-wrap {
  min-width: 0;
  flex: 1;
}

.bookmark-card-title {
  font-size: 17px;
  font-weight: 600;
  color: rgb(var(--v-theme-on-surface));
}

.bookmark-card-date {
  margin-top: 4px;
  font-size: 13px;
  color: rgb(var(--v-theme-on-surface-variant));
}

.bookmark-card-content {
  margin-top: 12px;
  flex: 1;
  color: rgb(var(--v-theme-on-surface-variant));
  display: -webkit-box;
  -webkit-line-clamp: 3;
  line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}

.bookmark-card-url {
  margin-top: 8px;
  font-size: 12px;
  color: rgb(var(--v-theme-primary));
  opacity: 0.7;
}

.bookmark-card-footer {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding-top: 14px;
}

.add-bookmark-body {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.dialog-title {
  font-size: 18px;
  font-weight: 700;
}

.tag-manager-body {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.tag-create-row {
  display: flex;
  align-items: center;
  gap: 12px;
}

.tag-list {
  max-height: 300px;
  overflow-y: auto;
}

.tag-chips-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
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

.mobile-toolbar {
  display: none;
}

@media (max-width: 760px) {
  .desktop-toolbar {
    display: none;
  }

  .bookmarks-container {
    padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 104px);
  }

  .page-title {
    font-size: 24px;
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
