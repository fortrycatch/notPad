<template>
  <div class="note-editor-workspace">
    <div class="note-editor-toolbar desktop-toolbar">
      <div class="note-editor-toolbar__right">
        <v-btn
          variant="text"
          prepend-icon="mdi-paperclip"
          @click="openResourcePicker('image')"
        >
          插入资源
        </v-btn>
        <v-btn-toggle
          v-model="editorView"
          mandatory
          density="comfortable"
          variant="text"
          divided
        >
          <v-btn value="write">编辑</v-btn>
          <v-btn value="preview">预览</v-btn>
        </v-btn-toggle>
        <v-btn
          v-if="showCancel"
          variant="text"
          @click="emit('cancel')"
          :disabled="saving || cancelDisabled"
        >
          取消
        </v-btn>
        <v-btn
          color="primary"
          prepend-icon="mdi-content-save"
          @click="emit('save', { keepEditing: false })"
          :loading="saving"
          :disabled="saveDisabled"
        >
          {{ saveLabel }}
        </v-btn>
      </div>
    </div>

    <div class="note-editor-layout" :class="{ 'is-write-mode': editorView === 'write' }">
      <aside class="note-editor-sidebar">
        <div class="note-editor-sidebar__title">目录</div>
        <v-divider class="note-editor-sidebar__divider" />

        <div v-if="tocItems.length > 0" class="note-editor-toc">
          <button
            v-for="item in tocItems"
            :key="item.id"
            type="button"
            class="note-editor-toc__item"
            :class="{ 'is-active': activeHeadingId === item.id }"
            :style="{ '--level': item.level }"
            @click="scrollToHeading(item.id)"
          >
            {{ item.text }}
          </button>
        </div>

        <div v-else class="note-editor-sidebar__empty">无目录</div>
      </aside>

      <section class="note-editor-main">
        <div class="note-editor-card">
          <div class="note-editor-card__header">
            <input
              :value="modelValue.title"
              class="note-editor-title-input"
              type="text"
              :placeholder="titlePlaceholder"
              :autofocus="autofocusTitle"
              @input="updateTitle(($event.target as HTMLInputElement).value)"
            />
          </div>
          <v-divider />

          <div v-if="editorView === 'write'" class="note-editor-card__write">
            <textarea
              ref="noteEditorRef"
              :value="modelValue.content"
              class="note-editor-body"
              :placeholder="contentPlaceholder"
              spellcheck="false"
              @input="handleContentInput"
              @click="syncEditorSelection"
              @focus="syncEditorSelection"
              @keyup="syncEditorSelection"
              @select="syncEditorSelection"
            />
          </div>

          <article
            v-else
            ref="articleRef"
            :key="`preview-${mainStore.darkMode ? 'dark' : 'light'}`"
            class="note-markdown note-preview"
            v-html="previewDocument.html"
          />
        </div>
      </section>
    </div>

    <ResourcePickerDialog
      v-model="showResourcePicker"
      :default-tab="resourcePickerTab"
      @select="handleResourceSelect"
    />

    <v-navigation-drawer
      v-model="showMobileToc"
      location="right"
      temporary
      width="300"
      class="note-editor-mobile-toc"
    >
      <div class="note-editor-mobile-toc__header">
        <div class="note-editor-mobile-toc__title">目录</div>
        <v-btn icon="mdi-close" variant="text" @click="showMobileToc = false" />
      </div>
      <v-divider />
      <div v-if="tocItems.length > 0" class="note-editor-mobile-toc__body">
        <button
          v-for="item in tocItems"
          :key="item.id"
          type="button"
          class="note-editor-toc__item"
          :class="{ 'is-active': activeHeadingId === item.id }"
          :style="{ '--level': item.level }"
          @click="selectMobileTocItem(item.id)"
        >
          {{ item.text }}
        </button>
      </div>
      <div v-else class="note-editor-mobile-toc__empty">无目录</div>
    </v-navigation-drawer>

    <div class="mobile-toolbar">
      <v-btn
        variant="text"
        prepend-icon="mdi-format-list-bulleted"
        :disabled="tocItems.length === 0"
        @click="showMobileToc = true"
      >
        目录
      </v-btn>
      <v-btn
        variant="text"
        prepend-icon="mdi-paperclip"
        @click="openResourcePicker('image')"
      >
        插入
      </v-btn>
      <v-btn
        variant="text"
        :prepend-icon="editorView === 'write' ? 'mdi-eye' : 'mdi-pencil'"
        @click="toggleEditorView"
      >
        {{ editorView === 'write' ? '预览' : '编辑' }}
      </v-btn>
      <v-btn
        v-if="showCancel"
        variant="text"
        @click="emit('cancel')"
        :disabled="saving || cancelDisabled"
      >
        取消
      </v-btn>
      <v-btn
        color="primary"
        prepend-icon="mdi-content-save"
        @click="emit('save', { keepEditing: false })"
        :loading="saving"
        :disabled="saveDisabled"
      >
        {{ saveLabel }}
      </v-btn>
    </div>
  </div>
</template>

<script setup lang="ts">
import MarkdownIt from 'markdown-it'
import Viewer from 'viewerjs'
import 'viewerjs/dist/viewer.css'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import ResourcePickerDialog from '../compose/ResourcePickerDialog.vue'
import { useMainStore } from '../../store/mainStore'

interface EditorForm {
  title: string
  content: string
}

interface NoteItem {
  id: string
  title: string
  content: string
  created_at?: string | Date
  updated_at?: string | Date
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

type EditorViewMode = 'write' | 'preview'
type ResourcePickerTab = 'image' | 'note' | 'file'

const props = withDefaults(defineProps<{
  modelValue: EditorForm
  saving?: boolean
  saveDisabled?: boolean
  saveLabel?: string
  showCancel?: boolean
  cancelDisabled?: boolean
  titlePlaceholder?: string
  contentPlaceholder?: string
  autofocusTitle?: boolean
}>(), {
  saving: false,
  saveDisabled: false,
  saveLabel: '保存',
  showCancel: true,
  cancelDisabled: false,
  titlePlaceholder: '标题',
  contentPlaceholder: '开始编写 Markdown 内容...',
  autofocusTitle: true
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: EditorForm): void
  (e: 'save', payload?: { keepEditing?: boolean }): void
  (e: 'cancel'): void
}>()

const mainStore = useMainStore()

const STICKY_TOP = 72
const HEADING_OFFSET = STICKY_TOP + 36
const IMAGE_FILE_EXTENSION_RE = /\.(?:apng|avif|bmp|gif|ico|jpe?g|jfif|png|svg|webp)(?:[?#].*)?$/i
const VIDEO_FILE_EXTENSION_RE = /\.(?:m4v|mov|mp4|ogg|webm)(?:[?#].*)?$/i

const editorView = ref<EditorViewMode>('write')
const articleRef = ref<HTMLElement | null>(null)
const noteEditorRef = ref<HTMLTextAreaElement | null>(null)
const activeHeadingId = ref('')
const showResourcePicker = ref(false)
const showMobileToc = ref(false)
const resourcePickerTab = ref<ResourcePickerTab>('image')
const editorSelectionStart = ref(0)
const editorSelectionEnd = ref(0)
const isApplyingResourceSelection = ref(false)
let headingObserver: IntersectionObserver | null = null
let imageViewer: Viewer | null = null
let mermaidModulePromise: Promise<typeof import('mermaid')> | null = null
let mermaidRenderCount = 0

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
  const env = {
    headings: [] as TocItem[],
    slugCounts: new Map<string, number>()
  }
  const html = markdown.render(content || '', env)

  return {
    html: enhanceRenderedHtml(html),
    headings: env.headings
  } as MarkdownDocument
}

const previewDocument = computed(() => buildMarkdownDocument(props.modelValue.content))
const tocItems = computed(() => previewDocument.value.headings)
const articleHtml = computed(() => editorView.value === 'preview' ? previewDocument.value.html : '')

const updateForm = (patch: Partial<EditorForm>) => {
  emit('update:modelValue', {
    ...props.modelValue,
    ...patch
  })
}

const updateTitle = (title: string) => {
  updateForm({ title })
}

const updateContent = (content: string) => {
  updateForm({ content })
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
        .sort((a, b) => (a.target as HTMLElement).offsetTop - (b.target as HTMLElement).offsetTop)

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

const syncEditorSelection = () => {
  if (!noteEditorRef.value) return

  editorSelectionStart.value = noteEditorRef.value.selectionStart ?? 0
  editorSelectionEnd.value = noteEditorRef.value.selectionEnd ?? editorSelectionStart.value
}

const resizeEditorTextarea = async () => {
  if (editorView.value !== 'write') return

  await nextTick()

  if (!noteEditorRef.value) return

  const textarea = noteEditorRef.value
  textarea.style.height = 'auto'
  textarea.style.height = `${Math.max(textarea.scrollHeight, 420)}px`
}

const handleContentInput = async (event: Event) => {
  const target = event.target as HTMLTextAreaElement
  updateContent(target.value)
  syncEditorSelection()
  await resizeEditorTextarea()
}

const restoreEditorFocus = async () => {
  if (editorView.value !== 'write') return

  await nextTick()

  if (!noteEditorRef.value) return

  noteEditorRef.value.focus()
  noteEditorRef.value.setSelectionRange(editorSelectionStart.value, editorSelectionEnd.value)
}

const insertTextAtCursor = async (text: string) => {
  const textarea = noteEditorRef.value
  const start = editorSelectionStart.value
  const end = editorSelectionEnd.value
  const nextCursor = start + text.length

  if (!textarea) {
    const content = props.modelValue.content
    updateContent(`${content.slice(0, start)}${text}${content.slice(end)}`)
    editorSelectionStart.value = nextCursor
    editorSelectionEnd.value = nextCursor
    await restoreEditorFocus()
    return
  }

  const scrollTop = textarea.scrollTop
  textarea.focus()
  textarea.setSelectionRange(start, end)
  textarea.setRangeText(text, start, end, 'end')

  updateContent(textarea.value)
  editorSelectionStart.value = textarea.selectionStart ?? nextCursor
  editorSelectionEnd.value = textarea.selectionEnd ?? nextCursor

  await resizeEditorTextarea()
  await nextTick()

  requestAnimationFrame(() => {
    if (!noteEditorRef.value) return

    noteEditorRef.value.focus()
    noteEditorRef.value.setSelectionRange(editorSelectionStart.value, editorSelectionEnd.value)
    noteEditorRef.value.scrollTop = scrollTop
  })
}

const toggleEditorView = () => {
  editorView.value = editorView.value === 'write' ? 'preview' : 'write'
}

const openResourcePicker = (tab: ResourcePickerTab = 'image') => {
  if (editorView.value !== 'write') {
    editorView.value = 'write'
  }

  syncEditorSelection()
  resourcePickerTab.value = tab
  showResourcePicker.value = true
}

const handleResourceSelect = async (
  payload:
    | { type: 'image'; item: { name: string; url: string } }
    | { type: 'file'; item: { name: string; public_url: string } }
    | { type: 'note'; item: NoteItem }
) => {
  try {
    isApplyingResourceSelection.value = true

    if (payload.type === 'image') {
      const imageName = payload.item.name.split('/').pop() || payload.item.name
      await insertTextAtCursor(`![${imageName}](https://monika.jkloli.net/${payload.item.url})`)
      return
    }

    if (payload.type === 'file') {
      await insertTextAtCursor(`[${payload.item.name}](${payload.item.public_url})`)
      return
    }

    const title = payload.item.title.trim() || '未命名笔记'
    await insertTextAtCursor(`[${title}](/note/${payload.item.id})`)
  } finally {
    requestAnimationFrame(() => {
      isApplyingResourceSelection.value = false
    })
  }
}

const scrollToHeading = async (id: string) => {
  if (editorView.value !== 'preview') {
    editorView.value = 'preview'
    await nextTick()
  }

  const target = document.getElementById(id)
  if (!target) return

  activeHeadingId.value = id
  const top = window.scrollY + target.getBoundingClientRect().top - HEADING_OFFSET
  window.scrollTo({ top, behavior: 'smooth' })
}

const selectMobileTocItem = async (id: string) => {
  showMobileToc.value = false
  await scrollToHeading(id)
}

const handleKeydown = (event: KeyboardEvent) => {
  if (!(event.metaKey || event.ctrlKey)) return
  if (event.key.toLowerCase() !== 's') return

  event.preventDefault()

  if (!props.saveDisabled && !props.saving) {
    emit('save', { keepEditing: true })
  }
}

watch(showResourcePicker, async (open) => {
  if (!open && !isApplyingResourceSelection.value) {
    await restoreEditorFocus()
  }
})

watch(
  () => props.modelValue.content,
  async () => {
    if (editorView.value === 'write') {
      await resizeEditorTextarea()
    }
  }
)

watch(
  () => editorView.value,
  async (view) => {
    if (view === 'write') {
      await resizeEditorTextarea()
    }
  },
  { flush: 'post' }
)

watch(
  [articleHtml, () => mainStore.darkMode],
  async () => {
    await nextTick()

    if (!articleHtml.value) {
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
  window.addEventListener('keydown', handleKeydown)
  void resizeEditorTextarea()
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleKeydown)
  disconnectHeadingObserver()
  destroyImageViewer()
})
</script>

<style scoped>
.note-editor-workspace {
  display: grid;
  gap: 20px;
  min-height: calc(100vh - var(--note-sticky-top, 72px) - 48px);
}

.note-editor-toolbar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 16px;
  flex-wrap: wrap;
}

.note-editor-toolbar__right {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.mobile-toolbar {
  display: none;
}

.note-editor-layout {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  gap: 24px;
  align-items: start;
  min-height: 0;
}

.note-editor-layout.is-write-mode {
  height: calc(100vh - var(--note-sticky-top, 72px) - 132px);
  align-items: stretch;
}

.note-editor-sidebar {
  position: sticky;
  top: calc(var(--note-sticky-top, 72px) + 24px);
  align-self: start;
  min-width: 0;
  max-height: calc(100vh - var(--note-sticky-top, 72px) - 36px);
  overflow: auto;
  padding-right: 16px;
  border-right: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}

.note-editor-sidebar__title {
  font-size: 14px;
  font-weight: 700;
}

.note-editor-sidebar__divider {
  margin: 12px 0 14px;
}

.note-editor-toc {
  display: grid;
  gap: 4px;
}

.note-editor-toc__item {
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

.note-editor-toc__item:hover,
.note-editor-toc__item.is-active {
  color: rgb(var(--v-theme-primary));
}

.note-editor-sidebar__empty {
  font-size: 13px;
  color: rgba(var(--v-theme-on-surface), 0.58);
}

.note-editor-mobile-toc__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 16px;
}

.note-editor-mobile-toc__title {
  font-size: 16px;
  font-weight: 700;
}

.note-editor-mobile-toc__body {
  display: grid;
  gap: 4px;
  padding: 12px 16px 20px;
}

.note-editor-mobile-toc__empty {
  padding: 20px 16px;
  font-size: 13px;
  color: rgba(var(--v-theme-on-surface), 0.58);
}

.note-editor-main {
  min-width: 0;
  min-height: 0;
}

.note-editor-card {
  min-height: calc(100vh - var(--note-sticky-top, 72px) - 120px);
}

.note-editor-layout.is-write-mode .note-editor-card {
  height: 100%;
  min-height: 0;
  overflow: auto;
}

.note-editor-card__header {
  padding: 10px 0 24px;
}

.note-editor-title-input {
  width: 100%;
  border: 0;
  outline: 0;
  background: transparent;
  color: rgb(var(--v-theme-on-surface));
  font: inherit;
  font-size: clamp(32px, 4vw, 48px);
  font-weight: 700;
  line-height: 1.08;
}

.note-editor-card__write {
  min-height: 0;
}

.note-editor-body {
  display: block;
  width: 100%;
  min-height: 420px;
  height: auto;
  overflow: hidden;
  resize: none;
  border: 0;
  outline: 0;
  background: transparent;
  color: rgb(var(--v-theme-on-surface));
  font-size: 15px;
  line-height: 1.8;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
  padding: 24px 0 24px;
}

.note-preview,
.note-markdown {
  min-height: calc(100vh - var(--note-sticky-top, 72px) - 120px);
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
  scroll-margin-top: calc(var(--note-sticky-top, 72px) + 54px);
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

@media (max-width: 1100px) {
  .note-editor-layout {
    grid-template-columns: 1fr;
  }

  .note-editor-layout.is-write-mode {
    height: auto;
  }

  .note-editor-sidebar {
    position: static;
    max-height: none;
    overflow: visible;
    padding-right: 0;
    padding-bottom: 18px;
    border-right: 0;
    border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  }

  .note-editor-card,
  .note-editor-layout.is-write-mode .note-editor-card {
    min-height: 0;
    height: auto;
    overflow: visible;
  }
}

@media (max-width: 760px) {
  .note-editor-workspace {
    gap: 0;
    padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 88px);
  }

  .desktop-toolbar {
    display: none;
  }

  .note-editor-sidebar {
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

  .note-editor-card__header,
  .note-preview,
  .note-editor-card__write {
    padding-left: 0;
    padding-right: 0;
  }
}
</style>
