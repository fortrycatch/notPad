<template>
  <v-dialog v-model="open" max-width="720" scrollable scrim-opacity="0.32">
    <v-card>
      <v-card-item>
        <v-card-title>选择图片</v-card-title>
        <template #append>
          <v-btn icon="mdi-close" variant="text" size="small" @click="open = false" />
        </template>
      </v-card-item>
      <v-divider />

      <v-card-text class="pa-3" style="min-height: 320px; max-height: 60vh">
        <v-text-field
          v-model="search"
          placeholder="搜索图片"
          prepend-inner-icon="mdi-magnify"
          density="compact"
          variant="outlined"
          hide-details
          single-line
          class="mb-3"
        />

        <div v-if="loading && images.length === 0" class="d-flex justify-center py-8">
          <v-progress-circular indeterminate color="primary" />
        </div>

        <div v-else-if="images.length === 0" class="text-center text-medium-emphasis py-8">
          暂无图片
        </div>

        <div v-else class="image-grid">
          <div
            v-for="img in images"
            :key="img.id"
            class="image-grid-item"
            :class="{ selected: selectedUrl === fullUrl(img.url) }"
            @click="selectedUrl = fullUrl(img.url)"
          >
            <v-img
              :src="fullUrl(img.url) + '?x-oss-process=image/resize,w_200'"
              cover
              aspect-ratio="1"
              class="rounded"
            >
              <template #placeholder>
                <div class="d-flex align-center justify-center fill-height">
                  <v-progress-circular indeterminate size="20" width="2" color="grey" />
                </div>
              </template>
            </v-img>
            <v-icon
              v-if="selectedUrl === fullUrl(img.url)"
              class="check-badge"
              color="primary"
              size="22"
            >mdi-check-circle</v-icon>
          </div>
        </div>

        <div v-if="hasMore" class="d-flex justify-center mt-3">
          <v-btn variant="text" size="small" :loading="loading" @click="loadMore">加载更多</v-btn>
        </div>
      </v-card-text>

      <v-divider />
      <v-card-actions class="px-4 py-3">
        <v-btn v-if="selectedUrl" variant="text" color="error" size="small" @click="selectedUrl = ''">清除头像</v-btn>
        <v-spacer />
        <v-btn variant="text" @click="open = false">取消</v-btn>
        <v-btn color="primary" variant="flat" @click="confirm">确定</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { server } from '../../server'

const IMAGE_HOST = 'https://monika.jkloli.net/'

const props = defineProps<{ modelValue: boolean; currentUrl?: string }>()
const emit = defineEmits<{
  (e: 'update:modelValue', v: boolean): void
  (e: 'select', url: string): void
}>()

const open = ref(props.modelValue)
watch(() => props.modelValue, v => { open.value = v })
watch(open, v => emit('update:modelValue', v))

type ImageItem = { id: number; url: string; name: string }
const images = ref<ImageItem[]>([])
const search = ref('')
const loading = ref(false)
const offset = ref(0)
const hasMore = ref(true)
const selectedUrl = ref(props.currentUrl ?? '')

watch(() => props.currentUrl, v => { selectedUrl.value = v ?? '' })

function fullUrl(url: string) {
  if (url.startsWith('http')) return url
  return IMAGE_HOST + url
}

async function fetchImages(reset = false) {
  if (reset) { offset.value = 0; hasMore.value = true }
  loading.value = true
  try {
    const list = await server.image_bed.list.query({
      user_id: '',
      offset: offset.value,
      sort: 'time_desc',
      search: search.value,
    })
    if (reset) {
      images.value = list as ImageItem[]
    } else {
      images.value.push(...(list as ImageItem[]))
    }
    hasMore.value = list.length >= 30
  } catch { /* noop */ } finally {
    loading.value = false
  }
}

function loadMore() {
  offset.value++
  fetchImages()
}

let searchTimer: ReturnType<typeof setTimeout>
watch(search, () => {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => fetchImages(true), 300)
})

watch(open, v => {
  if (v) {
    images.value = []
    search.value = ''
    selectedUrl.value = props.currentUrl ?? ''
    fetchImages(true)
  }
})

function confirm() {
  emit('select', selectedUrl.value)
  open.value = false
}
</script>

<style scoped>
.image-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
  gap: 8px;
}
.image-grid-item {
  position: relative;
  cursor: pointer;
  border-radius: 8px;
  overflow: hidden;
  border: 2px solid transparent;
  transition: border-color .15s;
}
.image-grid-item.selected {
  border-color: rgb(var(--v-theme-primary));
}
.check-badge {
  position: absolute;
  top: 4px;
  right: 4px;
  background: white;
  border-radius: 50%;
}
</style>
