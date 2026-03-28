<template>
  <v-card class="image-card" elevation="2" hover @click="showPreview = true">
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
        {{ baseName }}
      </div>
      <div class="image-info">
        <span>{{ formatFileSize(image.size) }}</span>
        <span>{{ formatDate(image.created_at) }}</span>
      </div>
    </v-card-text>
  </v-card>

  <ImagePreviewDialog
    v-model="showPreview"
    :image-url="imageUrl"
    :image-name="baseName"
    :image-id="image.id"
    :image-size="image.size"
    :image-date="image.created_at"
    :all-tags="allTags"
    @renamed="emit('renamed')"
    @tag-changed="emit('tagChanged')"
  />
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue'
import ImagePreviewDialog from './ImagePreviewDialog.vue'

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

const IMAGE_HOST = 'https://monika.jkloli.net/'
const imageUrl = IMAGE_HOST + props.image.url
const showPreview = ref(false)

const baseName = computed(() => {
  const full: string = props.image.name || ''
  return full.split('/').pop() || full
})

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
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit'
  })
}
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

@media (max-width: 760px) {
  .image-body {
    padding-bottom: 16px;
  }
}
</style>
