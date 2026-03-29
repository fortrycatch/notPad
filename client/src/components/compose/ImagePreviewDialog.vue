<template>
  <v-dialog
    :model-value="modelValue"
    max-width="min(1100px, 96vw)"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <v-card class="preview-dialog">
      <v-card-title class="preview-header">
        <div class="preview-header__meta">
          <div class="preview-title">{{ currentName }}</div>
          <div v-if="imageSize || imageDate" class="preview-subtitle">
            {{ imageSize ? formatFileSize(imageSize) : '' }}{{ imageSize && imageDate ? ' · ' : '' }}{{ imageDate ? formatDate(imageDate, true) : '' }}
          </div>
        </div>
        <v-btn icon="mdi-close" variant="text" @click="close" />
      </v-card-title>

      <v-card-text class="preview-content">
        <v-img
          :src="imageUrl"
          :alt="currentName"
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
        <v-btn prepend-icon="mdi-download" @click="download">
          下载
        </v-btn>
        <v-btn prepend-icon="mdi-link-variant" @click="copyUrl">
          图片链接
        </v-btn>
        <v-btn prepend-icon="mdi-language-markdown" @click="copyMarkdown">
          Markdown
        </v-btn>
        <template v-if="imageId">
          <v-btn prepend-icon="mdi-pencil" @click="startRename">
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
              v-for="tag in effectiveAllTags"
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
            <v-list-item v-if="effectiveAllTags.length === 0" disabled>
                <v-list-item-title class="text-medium-emphasis">暂无标签</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
          <v-btn prepend-icon="mdi-tune" @click="showOssConfig = true">
            图片处理
          </v-btn>
          <v-btn
            :prepend-icon="isBookmarked ? 'mdi-bookmark' : 'mdi-bookmark-plus-outline'"
            :color="isBookmarked ? 'primary' : undefined"
            @click="showBookmarkDialog = true"
          >
            收藏
          </v-btn>
        </template>
        <v-spacer />
        <v-btn variant="text" @click="close">关闭</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <AddBookmarkDialog
    v-if="imageId"
    v-model="showBookmarkDialog"
    resource-type="image"
    :resource-id="String(imageId)"
    :resource-title="currentName"
    :resource-url="imageUrl"
    @bookmarked="isBookmarked = true"
  />

  <v-dialog v-if="imageId" v-model="showRenameDialog" max-width="420">
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
    v-if="imageId"
    v-model="showOssConfig"
    :image-url="imageUrl"
    :image-name="currentName"
  />

  <img
    ref="viewerImageRef"
    :src="imageUrl"
    :alt="currentName"
    class="viewer-source"
  />
</template>

<script setup lang="ts">
import Viewer from 'viewerjs'
import 'viewerjs/dist/viewer.css'
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import OssProcessDialog from './OssProcessDialog.vue'
import AddBookmarkDialog from './AddBookmarkDialog.vue'
import { server } from '../../server'
import { formatFileSize, formatDate } from '../../utils/format'
import { downloadUrl } from '../../utils/download'

interface TagItem {
  id: number
  name: string
}

const props = withDefaults(defineProps<{
  modelValue: boolean
  imageUrl: string
  imageName: string
  imageId?: number
  imageSize?: number
  imageDate?: string
  allTags?: TagItem[]
}>(), {
  imageId: 0,
  imageSize: 0,
  imageDate: '',
  allTags: () => []
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'renamed'): void
  (e: 'tagChanged'): void
}>()

const currentName = ref(props.imageName)
const imageTags = ref<TagItem[]>([])
const internalAllTags = ref<TagItem[]>([])
const showOssConfig = ref(false)
const showBookmarkDialog = ref(false)
const isBookmarked = ref(false)
const showRenameDialog = ref(false)
const renameValue = ref('')
const renaming = ref(false)
const viewerImageRef = ref<HTMLImageElement | null>(null)
let imageViewer: Viewer | null = null

const effectiveAllTags = computed(() =>
  props.allTags.length > 0 ? props.allTags : internalAllTags.value
)

watch(() => props.imageName, (n) => { currentName.value = n })

watch(() => props.modelValue, async (open) => {
  if (!open || !props.imageId) return
  void loadImageTags()
  if (props.allTags.length === 0) {
    server.image_bed.listTags.query().then((tags: TagItem[]) => {
      internalAllTags.value = tags as TagItem[]
    })
  }
  const result = await server.bookmark.isBookmarked.query({ type: 'image', ref_id: String(props.imageId) })
  isBookmarked.value = result.bookmarked
})

const close = () => emit('update:modelValue', false)


const destroyImageViewer = () => {
  imageViewer?.destroy()
  imageViewer = null
}

const openViewer = () => {
  if (!viewerImageRef.value) return
  destroyImageViewer()
  imageViewer = new Viewer(viewerImageRef.value, {
    backdrop: true, button: true, keyboard: true, loop: false,
    movable: true, navbar: false, rotatable: false, scalable: false,
    title: () => currentName.value,
    toolbar: true, transition: true, zIndex: 2400, zoomable: true,
    hidden: () => { destroyImageViewer() }
  })
  imageViewer.show()
}

const loadImageTags = async () => {
  if (!props.imageId) return
  imageTags.value = await server.image_bed.getImageTags.query({ image_id: props.imageId }) as TagItem[]
}

const isTagged = (tagId: number) => imageTags.value.some((t) => t.id === tagId)

const toggleTag = async (tag: TagItem) => {
  if (!props.imageId) return
  if (isTagged(tag.id)) {
    await server.image_bed.removeTagFromImage.mutate({ image_id: props.imageId, tag_id: tag.id })
  } else {
    await server.image_bed.addTagToImage.mutate({ image_id: props.imageId, tag_id: tag.id })
  }
  await loadImageTags()
  emit('tagChanged')
}

const removeTag = async (tagId: number) => {
  if (!props.imageId) return
  await server.image_bed.removeTagFromImage.mutate({ image_id: props.imageId, tag_id: tagId })
  await loadImageTags()
  emit('tagChanged')
}

const startRename = () => {
  renameValue.value = currentName.value
  showRenameDialog.value = true
}

const confirmRename = async () => {
  const name = renameValue.value.trim()
  if (!name || !props.imageId) return
  renaming.value = true
  try {
    await server.image_bed.rename.mutate({ id: props.imageId, name })
    currentName.value = name
    showRenameDialog.value = false
    emit('renamed')
  } finally {
    renaming.value = false
  }
}

const download = () => {
  downloadUrl(props.imageUrl)
}

const copyUrl = () => {
  navigator.clipboard.writeText(props.imageUrl)
}

const copyMarkdown = () => {
  navigator.clipboard.writeText(`![${currentName.value}](${props.imageUrl})`)
}

onBeforeUnmount(() => {
  destroyImageViewer()
})
</script>

<style scoped>
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

.viewer-source {
  position: fixed;
  width: 1px;
  height: 1px;
  opacity: 0;
  pointer-events: none;
  left: -9999px;
  top: -9999px;
}

@media (max-width: 760px) {
  .preview-actions {
    padding: 0 16px 16px;
  }
}
</style>
