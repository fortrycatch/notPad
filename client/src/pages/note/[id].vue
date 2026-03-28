<template>
  <div class="note-detail-page" :class="{ 'is-editor-mode': isEditing }">
    <div v-if="loading" class="note-state">
      <v-progress-circular indeterminate color="primary" size="56" />
      <p>正在加载笔记...</p>
    </div>

    <div v-else-if="error" class="note-state note-state-error">
      <v-icon size="52" color="error">mdi-alert-circle</v-icon>
      <h3>{{ error }}</h3>
      <div class="note-state-actions">
        <v-btn color="primary" prepend-icon="mdi-refresh" @click="fetchNote">重试</v-btn>
        <v-btn variant="text" prepend-icon="mdi-arrow-left" @click="goBack">返回</v-btn>
      </div>
    </div>

    <div v-else-if="note" class="note-shell">
      <header class="note-topbar">
        <div class="note-topbar-main">
          <v-btn
            icon="mdi-arrow-left"
            variant="text"
            density="comfortable"
            @click="goBack"
            title="返回"
          />
          <div class="note-topbar-meta">
            <div class="note-topbar-time">
              <span>创建于 {{ formatDate(note.created_at) }}</span>
              <span>更新于 {{ formatDate(note.updated_at) }}</span>
            </div>
          </div>
        </div>

        <div class="note-topbar-actions">
          <template v-if="!isEditing">
            <v-menu :close-on-content-click="false">
              <template #activator="{ props: tagMenuProps }">
                <v-btn variant="text" prepend-icon="mdi-tag-outline" v-bind="tagMenuProps">
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
            <v-btn
              variant="text"
              :prepend-icon="noteIsBookmarked ? 'mdi-bookmark' : 'mdi-bookmark-outline'"
              :color="noteIsBookmarked ? 'primary' : undefined"
              @click="showBookmarkDialog = true"
            >
              收藏
            </v-btn>
            <v-btn color="primary" prepend-icon="mdi-pencil" @click="enterEditMode" :disabled="saving">
              编辑
            </v-btn>
            <v-menu>
              <template #activator="{ props }">
                <v-btn icon="mdi-dots-horizontal" variant="text" v-bind="props" />
              </template>
              <v-list>
                <v-list-item @click="deleteNote" color="error">
                  <template #prepend>
                    <v-icon color="error">mdi-delete</v-icon>
                  </template>
                  <v-list-item-title>删除笔记</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-menu>
          </template>
        </div>
      </header>

      <div v-if="!isEditing" class="note-mobile-toolbar">
        <v-btn
          icon="mdi-format-list-bulleted"
          variant="text"
          :disabled="tocItems.length === 0"
          @click="showMobileToc = true"
        />
        <v-menu :close-on-content-click="false">
          <template #activator="{ props: tagMenuProps }">
            <v-btn icon="mdi-tag-outline" variant="text" v-bind="tagMenuProps" />
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
        <v-btn
          :icon="noteIsBookmarked ? 'mdi-bookmark' : 'mdi-bookmark-outline'"
          variant="text"
          :color="noteIsBookmarked ? 'primary' : undefined"
          @click="showBookmarkDialog = true"
        />
        <v-btn
          icon="mdi-pencil"
          variant="text"
          color="primary"
          @click="enterEditMode"
          :disabled="saving"
        />
        <v-menu>
          <template #activator="{ props }">
            <v-btn icon="mdi-dots-horizontal" variant="text" v-bind="props" />
          </template>
          <v-list>
            <v-list-item @click="deleteNote" color="error">
              <template #prepend>
                <v-icon color="error">mdi-delete</v-icon>
              </template>
              <v-list-item-title>删除笔记</v-list-item-title>
            </v-list-item>
          </v-list>
        </v-menu>
      </div>

      <div v-if="!isEditing" class="note-layout">
        <aside class="note-sidebar">
          <div class="note-sidebar-title">目录</div>
          <v-divider class="note-sidebar-divider" />

          <div v-if="tocItems.length > 0" class="note-toc">
            <button
              v-for="item in tocItems"
              :key="item.id"
              type="button"
              class="note-toc-item"
              :class="{ 'is-active': activeHeadingId === item.id }"
              :style="{ '--level': item.level }"
              @click="scrollToHeading(item.id)"
            >
              {{ item.text }}
            </button>
          </div>

          <div v-else class="note-toc-empty">无目录</div>
        </aside>

        <section class="note-main">
          <div class="note-reader">
            <div class="note-reader-header">
              <h1 class="note-title">{{ note.title }}</h1>
              <div v-if="noteTags.length > 0" class="note-tags-row">
                <v-chip
                  v-for="tag in noteTags"
                  :key="tag.id"
                  size="small"
                  closable
                  @click:close="removeTag(tag.id)"
                >
                  {{ tag.name }}
                </v-chip>
              </div>
            </div>
            <v-divider />

            <article
              ref="articleRef"
              :key="`reader-${mainStore.darkMode ? 'dark' : 'light'}`"
              class="note-markdown"
              v-html="viewDocument.html"
              @click="handleArticleClick"
            />
          </div>
        </section>
      </div>

      <NoteMarkdownEditor
        v-else
        v-model="editForm"
        :saving="saving"
        :save-disabled="!canSave || !hasChanges"
        @cancel="cancelEdit"
        @save="saveNote"
      />

      <v-navigation-drawer
        v-model="showMobileToc"
        location="right"
        temporary
        width="300"
        class="note-mobile-toc"
      >
        <div class="note-mobile-toc__header">
          <div class="note-mobile-toc__title">目录</div>
          <v-btn icon="mdi-close" variant="text" @click="showMobileToc = false" />
        </div>
        <v-divider />
        <div v-if="tocItems.length > 0" class="note-mobile-toc__body">
          <button
            v-for="item in tocItems"
            :key="item.id"
            type="button"
            class="note-toc-item"
            :class="{ 'is-active': activeHeadingId === item.id }"
            :style="{ '--level': item.level }"
            @click="selectMobileTocItem(item.id)"
          >
            {{ item.text }}
          </button>
        </div>
        <div v-else class="note-mobile-toc__empty">无目录</div>
      </v-navigation-drawer>
    </div>

    <v-dialog v-model="showDeleteDialog" max-width="400">
      <v-card>
        <v-card-title class="text-h6">
          <v-icon color="error" class="mr-2">mdi-alert</v-icon>
          确认删除
        </v-card-title>
        <v-card-text>
          <p>确定要删除这篇笔记吗？</p>
          <p class="text-medium-emphasis text-caption mt-2">此操作无法撤销，请谨慎操作。</p>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="showDeleteDialog = false" :disabled="deleting">取消</v-btn>
          <v-btn color="error" @click="confirmDelete" :loading="deleting">删除</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="showSaveSuccess" color="success" timeout="2000" location="top">
      <v-icon start>mdi-check-circle</v-icon>
      保存成功
    </v-snackbar>

    <v-snackbar v-model="showSaveError" color="error" timeout="3000" location="top">
      <v-icon start>mdi-alert-circle</v-icon>
      {{ saveErrorMessage }}
    </v-snackbar>

    <AddBookmarkDialog
      v-if="note"
      v-model="showBookmarkDialog"
      resource-type="note"
      :resource-id="note.id"
      :resource-title="note.title"
      :resource-description="note.content?.slice(0, 200) || ''"
      @bookmarked="noteIsBookmarked = true"
    />
  </div>
</template>

<script setup lang="ts">
import MarkdownIt from 'markdown-it'
import Viewer from 'viewerjs'
import 'viewerjs/dist/viewer.css'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import NoteMarkdownEditor from '../../components/note/NoteMarkdownEditor.vue'
import AddBookmarkDialog from '../../components/compose/AddBookmarkDialog.vue'
import { useMainStore } from '../../store/mainStore'
import { trpc } from '../../trpc'

const router = useRouter()
const route = useRoute()
const mainStore = useMainStore()

interface Note {
  id: string
  title: string
  content: string
  created_at: string | Date
  updated_at: string | Date
}

interface TagItem {
  id: number
  name: string
}

interface TocItem {
  id: string
  text: string
  level: number
}

interface MarkdownDocument {
  html: string
  headings: TocItem[]
}

const note = ref<Note | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)
const allTags = ref<TagItem[]>([])
const noteTags = ref<TagItem[]>([])
const isEditing = ref(false)
const saving = ref(false)
const deleting = ref(false)
const showDeleteDialog = ref(false)
const showSaveSuccess = ref(false)
const showSaveError = ref(false)
const saveErrorMessage = ref('')
const showMobileToc = ref(false)
const showBookmarkDialog = ref(false)
const noteIsBookmarked = ref(false)
const articleRef = ref<HTMLElement | null>(null)
const activeHeadingId = ref('')
let headingObserver: IntersectionObserver | null = null
let imageViewer: Viewer | null = null
let mermaidModulePromise: Promise<typeof import('mermaid')> | null = null
let mermaidRenderCount = 0

const editForm = ref({
  title: '',
  content: ''
})

const STICKY_TOP = 72
const HEADING_OFFSET = STICKY_TOP + 36
const IMAGE_FILE_EXTENSION_RE = /\.(?:apng|avif|bmp|gif|ico|jpe?g|jfif|png|svg|webp)(?:[?#].*)?$/i
const VIDEO_FILE_EXTENSION_RE = /\.(?:m4v|mov|mp4|ogg|webm)(?:[?#].*)?$/i

const slugify = (text: string) => {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\u4e00-\u9fa5\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-') || 'section'
}

const markdown = new MarkdownIt({
  html: false,
  linkify: true,
  breaks: true,
  typographer: true
})

const defaultFenceRenderer = markdown.renderer.rules.fence?.bind(markdown.renderer.rules)
const defaultHeadingOpenRenderer = markdown.renderer.rules.heading_open
  ?.bind(markdown.renderer.rules)
const defaultLinkOpenRenderer = markdown.renderer.rules.link_open
  ?.bind(markdown.renderer.rules)

const getFileIconClass = (mime: string) => {
  if (!mime) return 'mdi-file-outline'
  if (mime.startsWith('image/')) return 'mdi-file-image-outline'
  if (mime.startsWith('video/')) return 'mdi-file-video-outline'
  if (mime.includes('pdf')) return 'mdi-file-pdf-box'
  if (mime.includes('zip') || mime.includes('compressed')) return 'mdi-folder-zip-outline'
  if (mime.startsWith('text/')) return 'mdi-file-document-outline'
  return 'mdi-file-outline'
}

const formatCardFileSize = (bytes: number) => {
  if (!bytes) return ''
  const units = ['B', 'KB', 'MB', 'GB']
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  return `${(bytes / 1024 ** i).toFixed(i === 0 ? 0 : 1)} ${units[i]}`
}

const renderResourceCard = (data: any): string => {
  const esc = markdown.utils.escapeHtml

  if (data.type === 'note') {
    const title = esc(data.title || '未命名笔记')
    const href = `/note/${encodeURIComponent(data.id)}`
    return `<a href="${esc(href)}" class="note-resource-card note-resource-card--note"><span class="note-resource-card__icon mdi mdi-note-text-outline"></span><span class="note-resource-card__body"><span class="note-resource-card__title">${title}</span><span class="note-resource-card__meta">笔记引用</span></span></a>`
  }

  if (data.type === 'file') {
    const name = esc(data.name || '文件')
    const url = esc(data.url || '')
    const iconClass = getFileIconClass(data.mime || '')
    const size = data.size ? formatCardFileSize(data.size) : ''
    return `<a href="${url}" class="note-resource-card note-resource-card--file" target="_blank" rel="noreferrer noopener"><span class="note-resource-card__icon mdi ${iconClass}"></span><span class="note-resource-card__body"><span class="note-resource-card__title">${name}</span>${size ? `<span class="note-resource-card__meta">${esc(size)}</span>` : ''}</span></a>`
  }

  return ''
}

markdown.renderer.rules.fence = (
  tokens: any[],
  idx: number,
  options: any,
  env: any,
  self: any
) => {
  const token = tokens[idx]
  const language = token.info.trim().split(/\s+/)[0]

  if (language === 'mermaid') {
    return `<div class="mermaid">${markdown.utils.escapeHtml(token.content)}</div>`
  }

  if (language === 'notecard') {
    try {
      return renderResourceCard(JSON.parse(token.content.trim()))
    } catch {
      // malformed notecard
    }
  }

  if (defaultFenceRenderer) {
    return defaultFenceRenderer(tokens, idx, options, env, self)
  }

  return self.renderToken(tokens, idx, options)
}

markdown.renderer.rules.heading_open = (
  tokens: any[],
  idx: number,
  options: any,
  env: any,
  self: any
) => {
  const inlineToken = tokens[idx + 1]
  const title = inlineToken?.content?.trim() || `section-${idx}`
  const baseSlug = slugify(title)
  const slugCounts = env.slugCounts as Map<string, number>
  const currentCount = slugCounts.get(baseSlug) ?? 0
  const id = currentCount === 0 ? baseSlug : `${baseSlug}-${currentCount}`
  slugCounts.set(baseSlug, currentCount + 1)

  tokens[idx].attrSet('id', id)
  env.headings.push({
    id,
    text: title,
    level: Number(tokens[idx].tag.replace('h', ''))
  })

  if (defaultHeadingOpenRenderer) {
    return defaultHeadingOpenRenderer(tokens, idx, options, env, self)
  }

  return self.renderToken(tokens, idx, options)
}

markdown.renderer.rules.link_open = (
  tokens: any[],
  idx: number,
  options: any,
  env: any,
  self: any
) => {
  const href = tokens[idx].attrGet('href') || ''

  if (!href.startsWith('#')) {
    tokens[idx].attrSet('target', '_blank')
    tokens[idx].attrSet('rel', 'noreferrer noopener')
  }

  if (defaultLinkOpenRenderer) {
    return defaultLinkOpenRenderer(tokens, idx, options, env, self)
  }

  return self.renderToken(tokens, idx, options)
}

const isImageUrl = (url: string) => IMAGE_FILE_EXTENSION_RE.test(url)

const isVideoUrl = (url: string) => VIDEO_FILE_EXTENSION_RE.test(url)

const elementHasOnlyNode = (element: Element, selector: string) => {
  if (element.children.length !== 1) return false

  const onlyChild = element.firstElementChild
  if (!onlyChild?.matches(selector)) return false

  return Array.from(element.childNodes).every((node) => {
    if (node === onlyChild) return true
    return node.textContent?.trim() === ''
  })
}

const createVideoElement = (doc: Document, src: string, title: string) => {
  const video = doc.createElement('video')
  video.setAttribute('src', src)
  video.setAttribute('controls', '')
  video.setAttribute('preload', 'metadata')
  video.setAttribute('playsinline', '')
  video.classList.add('note-embedded-video')

  if (title) {
    video.setAttribute('title', title)
    video.setAttribute('aria-label', title)
  }

  return video
}

const enhanceRenderedHtml = (html: string) => {
  if (!html || typeof window === 'undefined') return html

  const parser = new DOMParser()
  const documentNode = parser.parseFromString(`<div>${html}</div>`, 'text/html')
  const root = documentNode.body.firstElementChild

  if (!root) return html

  Array.from(root.querySelectorAll<HTMLImageElement>('img')).forEach((image) => {
    const src = image.getAttribute('src') || ''
    const alt = image.getAttribute('alt') || ''

    if (isVideoUrl(src)) {
      image.replaceWith(createVideoElement(documentNode, src, alt))
      return
    }

    image.classList.add('note-embedded-image')
    image.setAttribute('loading', 'lazy')
    image.setAttribute('decoding', 'async')
  })

  Array.from(root.querySelectorAll<HTMLAnchorElement>('a[href]')).forEach((link) => {
    const href = link.getAttribute('href') || ''
    const label = link.textContent?.trim() || ''
    const parent = link.parentElement

    if (!parent || parent.tagName !== 'P' || !elementHasOnlyNode(parent, 'a[href]')) {
      return
    }

    if (isImageUrl(href)) {
      const image = documentNode.createElement('img')
      image.setAttribute('src', href)
      image.setAttribute('alt', label || '图片')
      image.setAttribute('loading', 'lazy')
      image.setAttribute('decoding', 'async')
      image.classList.add('note-embedded-image')
      parent.replaceWith(image)
      return
    }

    if (isVideoUrl(href)) {
      parent.replaceWith(createVideoElement(documentNode, href, label || '视频'))
    }
  })

  Array.from(root.querySelectorAll('p')).forEach((paragraph) => {
    if (!elementHasOnlyNode(paragraph, 'img.note-embedded-image, video.note-embedded-video')) {
      return
    }

    const media = paragraph.firstElementChild
    if (media) {
      paragraph.replaceWith(media)
    }
  })

  return root.innerHTML
}

const buildMarkdownDocument = (content: string) => {
  const safeContent = content || ''
  const env = {
    headings: [] as TocItem[],
    slugCounts: new Map<string, number>()
  }
  const html = markdown.render(safeContent, env)

  return {
    html: enhanceRenderedHtml(html),
    headings: env.headings
  } as MarkdownDocument
}

const canSave = computed(() => {
  return editForm.value.title.trim() !== ''
})

const hasChanges = computed(() => {
  if (!note.value) return false

  return (
    editForm.value.title.trim() !== note.value.title.trim() ||
    editForm.value.content.trim() !== note.value.content.trim()
  )
})

const noteId = computed(() => route.params.id as string)
const isEditRoute = computed(() => route.query.mode === 'edit')
const tocItems = computed(() => viewDocument.value.headings)
const viewDocument = computed(() => buildMarkdownDocument(note.value?.content || ''))
const articleHtml = computed(() => note.value && !isEditing.value ? viewDocument.value.html : '')

const syncEditModeToRoute = (editing: boolean) => {
  const query = { ...route.query }

  if (editing) {
    query.mode = 'edit'
  } else {
    delete query.mode
  }

  router.replace({
    path: route.path,
    query
  })
}

const disconnectHeadingObserver = () => {
  headingObserver?.disconnect()
  headingObserver = null
}

const destroyImageViewer = () => {
  imageViewer?.destroy()
  imageViewer = null
}

const syncImageViewer = () => {
  destroyImageViewer()

  if (!articleRef.value) return

  const images = articleRef.value.querySelectorAll('img.note-embedded-image')
  if (images.length === 0) return

  imageViewer = new Viewer(articleRef.value, {
    backdrop: true,
    button: true,
    filter: (image: HTMLImageElement) => image.classList.contains('note-embedded-image'),
    keyboard: true,
    loop: true,
    movable: true,
    navbar: true,
    rotatable: false,
    scalable: false,
    title: (image: HTMLImageElement) => image.alt || image.getAttribute('alt') || '图片预览',
    toolbar: true,
    transition: true,
    zIndex: 2400,
    zoomable: true
  })
}

const syncHeadingObserver = () => {
  disconnectHeadingObserver()

  if (!articleRef.value) {
    activeHeadingId.value = ''
    return
  }

  const headings = Array.from(articleRef.value.querySelectorAll<HTMLElement>('h1,h2,h3,h4,h5,h6'))

  if (headings.length === 0) {
    activeHeadingId.value = ''
    return
  }

  activeHeadingId.value = headings[0].id
  headingObserver = new IntersectionObserver(
    (entries) => {
      const visibleEntries = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => {
          return (a.target as HTMLElement).offsetTop - (b.target as HTMLElement).offsetTop
        })

      if (visibleEntries[0]) {
        activeHeadingId.value = (visibleEntries[0].target as HTMLElement).id
      }
    },
    {
      rootMargin: `-${HEADING_OFFSET}px 0px -70% 0px`,
      threshold: [0, 1]
    }
  )

  headings.forEach((heading) => headingObserver?.observe(heading))
}

const renderMermaidDiagrams = async () => {
  if (!articleRef.value) return

  const mermaidBlocks = Array.from(articleRef.value.querySelectorAll<HTMLElement>('.mermaid'))
  if (mermaidBlocks.length === 0) return

  mermaidModulePromise ??= import('mermaid')
  const mermaid = (await mermaidModulePromise).default

  mermaid.initialize({
    startOnLoad: false,
    securityLevel: 'loose',
    theme: mainStore.darkMode ? 'dark' : 'default',
    fontFamily: 'inherit'
  })

  await Promise.all(mermaidBlocks.map(async (block) => {
    const source = block.textContent?.trim()
    if (!source) return

    try {
      const renderId = `note-mermaid-${mermaidRenderCount++}`
      const { svg, bindFunctions } = await mermaid.render(renderId, source)
      block.innerHTML = svg
      bindFunctions?.(block)
    } catch (error) {
      console.error('Mermaid 渲染失败:', error)
      block.innerHTML = `<pre>${markdown.utils.escapeHtml(source)}</pre>`
    }
  }))
}

const loadAllTags = async () => {
  allTags.value = await trpc.notepad.listTags.query() as TagItem[]
}

const loadNoteTags = async () => {
  if (!noteId.value) return
  noteTags.value = await trpc.notepad.getNoteTags.query({ note_id: noteId.value }) as TagItem[]
}

const isTagged = (tagId: number) => noteTags.value.some((t) => t.id === tagId)

const toggleTag = async (tag: TagItem) => {
  if (!noteId.value) return
  if (isTagged(tag.id)) {
    await trpc.notepad.removeTagFromNote.mutate({ note_id: noteId.value, tag_id: tag.id })
  } else {
    await trpc.notepad.addTagToNote.mutate({ note_id: noteId.value, tag_id: tag.id })
  }
  await loadNoteTags()
}

const removeTag = async (tagId: number) => {
  if (!noteId.value) return
  await trpc.notepad.removeTagFromNote.mutate({ note_id: noteId.value, tag_id: tagId })
  await loadNoteTags()
}

const fetchNote = async () => {
  if (!noteId.value) {
    error.value = '笔记ID不存在'
    return
  }

  try {
    loading.value = true
    error.value = null
    const result = await trpc.notepad.getNoteById.query({ id: noteId.value }) as Note
    note.value = result
    editForm.value = {
      title: result.title,
      content: result.content
    }
    isEditing.value = isEditRoute.value
    loadAllTags()
    loadNoteTags()
    trpc.bookmark.isBookmarked.query({ type: 'note', ref_id: noteId.value }).then(r => {
      noteIsBookmarked.value = r.bookmarked
    })
  } catch (err: any) {
    console.error('获取笔记失败:', err)
    error.value = err?.message || '获取笔记失败，请稍后重试'
  } finally {
    loading.value = false
  }
}

const enterEditMode = () => {
  if (!note.value) return

  editForm.value = {
    title: note.value.title,
    content: note.value.content
  }
  isEditing.value = true
  syncEditModeToRoute(true)
}

const cancelEdit = () => {
  if (!note.value) return

  editForm.value = {
    title: note.value.title,
    content: note.value.content
  }
  isEditing.value = false
  syncEditModeToRoute(false)
}

const saveNote = async (options?: { keepEditing?: boolean }) => {
  if (!canSave.value || !note.value || !hasChanges.value) return

  try {
    saving.value = true
    const result = await trpc.notepad.updateNote.mutate({
      id: note.value.id,
      title: editForm.value.title.trim(),
      content: editForm.value.content.trim()
    }) as Note

    note.value = result
    editForm.value = {
      title: result.title,
      content: result.content
    }
    isEditing.value = options?.keepEditing === true
    syncEditModeToRoute(isEditing.value)
    showSaveSuccess.value = true
    mainStore.triggerRefresh()
  } catch (err: any) {
    console.error('保存笔记失败:', err)
    saveErrorMessage.value = err?.message || '保存失败，请稍后重试'
    showSaveError.value = true
  } finally {
    saving.value = false
  }
}

const deleteNote = () => {
  showDeleteDialog.value = true
}

const confirmDelete = async () => {
  if (!note.value) return

  try {
    deleting.value = true
    await trpc.notepad.deleteNote.mutate({ id: note.value.id })
    mainStore.triggerRefresh()
    router.push('/notes')
  } catch (err: any) {
    console.error('删除笔记失败:', err)
    saveErrorMessage.value = err?.message || '删除失败，请稍后重试'
    showSaveError.value = true
    showDeleteDialog.value = false
  } finally {
    deleting.value = false
  }
}

const goBack = () => {
  if (window.history.length > 1) {
    router.back()
    return
  }

  router.push('/notes')
}

const scrollToHeading = async (id: string) => {
  const target = document.getElementById(id)
  if (!target) return

  activeHeadingId.value = id
  const top = window.scrollY + target.getBoundingClientRect().top - HEADING_OFFSET
  window.scrollTo({ top, behavior: 'smooth' })
}

const handleArticleClick = (event: MouseEvent) => {
  const card = (event.target as HTMLElement).closest<HTMLAnchorElement>('.note-resource-card--note')
  if (!card) return

  const href = card.getAttribute('href')
  if (!href) return

  event.preventDefault()
  router.push(href)
}

const selectMobileTocItem = async (id: string) => {
  showMobileToc.value = false
  await scrollToHeading(id)
}

const formatDate = (dateString: string | Date) => {
  const date = typeof dateString === 'string' ? new Date(dateString) : dateString
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

watch(
  () => route.params.id,
  (newId) => {
    if (newId) {
      fetchNote()
    }
  }
)

watch(
  () => route.query.mode,
  (mode) => {
    if (!note.value) return

    if (mode === 'edit') {
      editForm.value = {
        title: note.value.title,
        content: note.value.content
      }
      isEditing.value = true
      return
    }

    if (isEditing.value) {
      isEditing.value = false
      editForm.value = {
        title: note.value.title,
        content: note.value.content
      }
    }
  }
)

watch(
  () => mainStore.authenticated,
  (authenticated) => {
    if (authenticated && noteId.value) {
      fetchNote()
    }
  }
)

watch(
  [articleHtml, () => isEditing.value, () => mainStore.darkMode],
  async ([html, editing]) => {
    await nextTick()

    if (editing || !html) {
      disconnectHeadingObserver()
      destroyImageViewer()
      activeHeadingId.value = ''
      return
    }

    await renderMermaidDiagrams()
    syncHeadingObserver()
    syncImageViewer()
  },
  { flush: 'post' }
)

onMounted(() => {
  if (mainStore.authenticated) {
    fetchNote()
  }
})

onBeforeUnmount(() => {
  disconnectHeadingObserver()
  destroyImageViewer()
})
</script>

<style scoped>
.note-detail-page {
  --note-sticky-top: 72px;
  min-height: 100%;
  padding: 0 clamp(16px, 4vw, 32px) 48px;
}

.note-state {
  min-height: 55vh;
  display: grid;
  place-items: center;
  gap: 12px;
  text-align: center;
  color: rgba(var(--v-theme-on-surface), 0.74);
}

.note-state-error {
  background: rgba(var(--v-theme-error), 0.06);
  border: 1px solid rgba(var(--v-theme-error), 0.16);
  border-radius: 20px;
  padding: 32px;
}

.note-state-actions {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
}

.note-shell {
  display: grid;
  gap: 0;
}

.note-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  min-height: var(--note-sticky-top);
  padding: 14px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}

.note-topbar-main {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.note-topbar-meta {
  min-width: 0;
}

.note-topbar-time {
  display: flex;
  flex-wrap: wrap;
  gap: 10px 18px;
  font-size: 13px;
  color: rgba(var(--v-theme-on-surface), 0.8);
}

.note-topbar-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.note-mobile-toolbar {
  display: none;
}

.note-layout {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  gap: 24px;
  align-items: start;
  padding-top: 24px;
}

.note-sidebar {
  position: sticky;
  top: calc(var(--note-sticky-top) + 24px);
  align-self: start;
  min-width: 0;
  max-height: calc(100vh - var(--note-sticky-top) - 36px);
  overflow: auto;
  padding-right: 16px;
  border-right: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}

.note-sidebar-title {
  font-size: 14px;
  font-weight: 700;
}

.note-sidebar-divider {
  margin: 12px 0 14px;
}

.note-toc {
  display: grid;
  gap: 4px;
}

.note-toc-item {
  appearance: none;
  width: 100%;
  border: 0;
  background: transparent;
  color: rgba(var(--v-theme-on-surface), 0.72);
  text-align: left;
  padding: 7px 0 7px calc((var(--level, 1) - 1) * 14px);
  cursor: pointer;
  transition: color 0.16s ease;
}

.note-toc-item:hover,
.note-toc-item.is-active {
  color: rgb(var(--v-theme-primary));
}

.note-toc-empty {
  font-size: 13px;
  color: rgba(var(--v-theme-on-surface), 0.58);
}

.note-mobile-toc__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 16px;
}

.note-mobile-toc__title {
  font-size: 16px;
  font-weight: 700;
}

.note-mobile-toc__body {
  display: grid;
  gap: 4px;
  padding: 12px 16px 20px;
}

.note-mobile-toc__empty {
  padding: 20px 16px;
  font-size: 13px;
  color: rgba(var(--v-theme-on-surface), 0.58);
}

.note-main {
  min-width: 0;
  padding-left: 8px;
}

.note-reader {
  min-height: calc(100vh - var(--note-sticky-top) - 24px);
}

.note-reader-header {
  padding: 0 0 24px;
}

.note-tags-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 16px;
}

.note-title {
  margin: 0;
  font-size: clamp(32px, 4vw, 48px);
  line-height: 1.08;
  word-break: break-word;
}

.note-markdown {
  padding: 24px 0 0;
  font-size: 16px;
  line-height: 1.85;
  color: rgb(var(--v-theme-on-surface));
  word-break: break-word;
}

.note-markdown :deep(h1),
.note-markdown :deep(h2),
.note-markdown :deep(h3),
.note-markdown :deep(h4) {
  margin: 1.9em 0 0.7em;
  line-height: 1.2;
  scroll-margin-top: calc(var(--note-sticky-top) + 54px);
}

.note-markdown :deep(h1:first-child),
.note-markdown :deep(h2:first-child) {
  margin-top: 0;
}

.note-markdown :deep(p),
.note-markdown :deep(ul),
.note-markdown :deep(ol),
.note-markdown :deep(blockquote),
.note-markdown :deep(pre),
.note-markdown :deep(table) {
  margin: 0 0 1.1em;
}

.note-markdown :deep(ul),
.note-markdown :deep(ol) {
  padding-left: 1.4em;
}

.note-markdown :deep(li + li) {
  margin-top: 0.35em;
}

.note-markdown :deep(a) {
  color: rgb(var(--v-theme-primary));
  text-decoration: none;
}

.note-markdown :deep(a:hover) {
  text-decoration: underline;
}

.note-markdown :deep(code) {
  padding: 0.15em 0.42em;
  border-radius: 6px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  font-size: 0.9em;
}

.note-markdown :deep(pre) {
  overflow-x: auto;
  padding: 16px 18px;
  background: rgba(var(--v-theme-on-surface), 0.06);
}

.note-markdown :deep(pre code) {
  padding: 0;
  background: transparent;
}

.note-markdown :deep(blockquote) {
  padding: 4px 0 4px 16px;
  border-left: 3px solid rgba(var(--v-theme-primary), 0.55);
  color: rgba(var(--v-theme-on-surface), 0.72);
}

.note-markdown :deep(table) {
  width: 100%;
  border-collapse: collapse;
}

.note-markdown :deep(th),
.note-markdown :deep(td) {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  padding: 10px 12px;
  text-align: left;
}

.note-markdown :deep(.mermaid) {
  display: block;
  overflow-x: auto;
  padding: 20px;
  background: rgba(var(--v-theme-on-surface), 0.04);
}

.note-markdown :deep(.note-embedded-image) {
  display: block;
  max-width: min(100%, 820px);
  width: auto;
  height: auto;
  margin: 1.25rem auto;
  border-radius: 18px;
  cursor: zoom-in;
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.14);
}

.note-markdown :deep(.note-embedded-video) {
  display: block;
  width: min(100%, 820px);
  max-width: 100%;
  margin: 1.25rem auto;
  border-radius: 18px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.14);
}

.note-markdown :deep(.note-resource-card) {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px 20px;
  margin: 1.1em 0;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  border-radius: 12px;
  background: rgba(var(--v-theme-on-surface), 0.03);
  text-decoration: none !important;
  color: inherit !important;
  transition: background 0.15s, border-color 0.15s;
  cursor: pointer;
}

.note-markdown :deep(.note-resource-card:hover) {
  background: rgba(var(--v-theme-primary), 0.06);
  border-color: rgba(var(--v-theme-primary), 0.3);
}

.note-markdown :deep(.note-resource-card__icon) {
  font-size: 28px;
  color: rgb(var(--v-theme-primary));
  flex-shrink: 0;
}

.note-markdown :deep(.note-resource-card__body) {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.note-markdown :deep(.note-resource-card__title) {
  font-weight: 600;
  font-size: 15px;
  line-height: 1.4;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.note-markdown :deep(.note-resource-card__meta) {
  font-size: 13px;
  color: rgba(var(--v-theme-on-surface), 0.6);
}

@media (max-width: 1100px) {
  .note-layout {
    grid-template-columns: 1fr;
  }

  .note-sidebar {
    position: static;
    max-height: none;
    overflow: visible;
    padding-right: 0;
    padding-bottom: 18px;
    border-right: 0;
    border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  }

  .note-main {
    padding-left: 0;
  }
}

@media (max-width: 760px) {
  .note-detail-page {
    padding: 0 12px calc(env(safe-area-inset-bottom, 0px) + 104px);
  }

  .note-topbar {
    min-height: auto;
    padding: 12px 0;
  }

  .note-topbar-time {
    width: 100%;
  }

  .note-topbar-meta {
    display: none;
  }

  .note-topbar-actions {
    display: none;
  }

  .note-mobile-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-around;
    position: fixed;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 30;
    padding: 6px 12px calc(env(safe-area-inset-bottom, 0px) + 6px);
    border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
    background: rgba(var(--v-theme-surface), 0.96);
    backdrop-filter: blur(12px);
    box-shadow: 0 -4px 16px rgba(15, 23, 42, 0.08);
  }

  .note-sidebar {
    display: none;
  }

  .note-reader-header,
  .note-markdown {
    padding-left: 0;
    padding-right: 0;
  }
}

@media print {
  .note-topbar,
  .note-sidebar {
    display: none;
  }

  .note-reader {
    border: 0;
    background: transparent;
  }

  .note-markdown {
    padding: 0;
  }
}
</style>
