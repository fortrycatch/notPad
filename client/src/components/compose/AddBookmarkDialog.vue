<template>
  <v-dialog
    :model-value="modelValue"
    max-width="520"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <v-card>
      <v-card-title class="d-flex justify-space-between align-center">
        <span>收藏到书签</span>
        <v-btn icon="mdi-close" variant="text" @click="close" />
      </v-card-title>

      <v-card-text>
        <div class="bookmark-preview">
          <v-icon size="20" class="mr-2">{{ typeIcon }}</v-icon>
          <span class="text-truncate">{{ resourceTitle }}</span>
        </div>

        <div class="mt-4 mb-2 text-subtitle-2">选择标签</div>

        <div v-if="tags.length > 0" class="tag-list">
          <v-chip
            v-for="tag in tags"
            :key="tag.id"
            :color="selectedTagIds.has(tag.id) ? 'primary' : undefined"
            :variant="selectedTagIds.has(tag.id) ? 'elevated' : 'outlined'"
            @click="toggleTag(tag.id)"
          >
            {{ tag.name }}
          </v-chip>
        </div>
        <div v-else class="text-medium-emphasis text-body-2 mb-2">
          暂无标签，可在下方快速创建
        </div>

        <div class="d-flex align-center ga-2 mt-3">
          <v-text-field
            v-model="newTagName"
            label="新标签名称"
            variant="outlined"
            density="compact"
            hide-details
            @keydown.enter="createTag"
          />
          <v-btn
            variant="tonal"
            :loading="creatingTag"
            :disabled="!newTagName.trim()"
            @click="createTag"
          >
            创建
          </v-btn>
        </div>
      </v-card-text>

      <v-card-actions>
        <v-spacer />
        <v-btn @click="close">取消</v-btn>
        <v-btn color="primary" :loading="saving" @click="save">
          收藏
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { server } from '../../server'

interface TagItem {
  id: number
  name: string
}

const props = defineProps<{
  modelValue: boolean
  resourceType: 'image' | 'note' | 'file'
  resourceId: string
  resourceTitle: string
  resourceUrl?: string
  resourceDescription?: string
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'bookmarked'): void
}>()

const tags = ref<TagItem[]>([])
const selectedTagIds = ref(new Set<number>())
const newTagName = ref('')
const creatingTag = ref(false)
const saving = ref(false)

const typeIcon = computed(() => {
  const icons: Record<string, string> = {
    image: 'mdi-image',
    note: 'mdi-note-text',
    file: 'mdi-file'
  }
  return icons[props.resourceType] || 'mdi-bookmark'
})

const loadTags = async () => {
  tags.value = await server.bookmark.listTags.query() as TagItem[]
}

const toggleTag = (id: number) => {
  const s = new Set(selectedTagIds.value)
  if (s.has(id)) {
    s.delete(id)
  } else {
    s.add(id)
  }
  selectedTagIds.value = s
}

const createTag = async () => {
  const name = newTagName.value.trim()
  if (!name) return

  creatingTag.value = true
  try {
    const tag = await server.bookmark.createTag.mutate({ name }) as TagItem
    await loadTags()
    selectedTagIds.value = new Set([...selectedTagIds.value, tag.id])
    newTagName.value = ''
  } catch {
    console.error('创建标签失败')
  } finally {
    creatingTag.value = false
  }
}

const save = async () => {
  saving.value = true
  try {
    await server.bookmark.add.mutate({
      type: props.resourceType,
      title: props.resourceTitle,
      description: props.resourceDescription || '',
      url: props.resourceUrl || '',
      ref_id: props.resourceId,
      tag_ids: [...selectedTagIds.value]
    })
    emit('bookmarked')
    close()
  } catch (err: unknown) {
    const e = err as { message?: string }
    if (e.message?.includes('已收藏')) {
      close()
    }
    console.error('收藏失败:', err)
  } finally {
    saving.value = false
  }
}

const close = () => {
  emit('update:modelValue', false)
}

watch(() => props.modelValue, async (open) => {
  if (open) {
    selectedTagIds.value = new Set()
    newTagName.value = ''
    await loadTags()
  }
})
</script>

<style scoped>
.bookmark-preview {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  border-radius: 8px;
  background: rgba(var(--v-theme-on-surface), 0.04);
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
</style>
