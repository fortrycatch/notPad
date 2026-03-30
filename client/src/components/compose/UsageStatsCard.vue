<template>
  <v-card variant="elevated" elevation="1" :class="cardClass">
    <v-card-item>
      <template #append>
        <v-btn
          icon="mdi-refresh"
          variant="text"
          size="small"
          :loading="recalculating"
          @click="recalculate"
        />
      </template>
      <v-card-title class="text-title-md">{{ title }}</v-card-title>
      <v-card-subtitle v-if="subtitle" class="text-wrap">{{ subtitle }}</v-card-subtitle>
    </v-card-item>
    <v-divider />
    <v-card-text v-if="statsLoading" class="d-flex align-center justify-center py-6">
      <v-progress-circular indeterminate color="primary" size="28" width="2" />
    </v-card-text>
    <v-list v-else density="compact" class="py-0" bg-color="transparent">
      <template v-for="(item, i) in statItems" :key="item.label">
        <v-divider v-if="i > 0" />
        <v-list-item class="px-4">
          <template #prepend>
            <v-icon :icon="item.icon" :color="item.color" size="20" class="mr-3" />
          </template>
          <v-list-item-title class="text-body-2">
            {{ item.label }}
            <span v-if="item.size != null" class="text-caption text-medium-emphasis ml-1">
              {{ formatSize(item.size) }}
            </span>
          </v-list-item-title>
          <template #append>
            <span class="text-body-1 font-weight-bold">{{ item.count }}</span>
          </template>
        </v-list-item>
      </template>
    </v-list>
  </v-card>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { storeToRefs } from 'pinia';
import { server } from '../../server';
import { useMainStore } from '../../store/mainStore';

const props = withDefaults(
  defineProps<{
    /** 个人空间 / 当前群组空间 */
    variant?: 'personal' | 'group';
    cardClass?: string;
  }>(),
  { variant: 'personal', cardClass: '' }
);

const emit = defineEmits<{ reloaded: []; error: [message: string] }>();

const mainStore = useMainStore();
const { refreshTrigger } = storeToRefs(mainStore);

const title = computed(() =>
  props.variant === 'group' ? '群组空间用量' : '用量数据'
);
const subtitle = computed(() =>
  props.variant === 'group' && mainStore.activeGroup
    ? `「${mainStore.activeGroup.name}」`
    : ''
);

type UsageStats = {
  notes_count: number;
  bookmarks_count: number;
  images_count: number;
  images_size: number;
  files_count: number;
  files_size: number;
};

const stats = ref<UsageStats | null>(null);
const statsLoading = ref(true);
const recalculating = ref(false);

function formatSize(bytes: number): string {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

const statItems = computed(() => {
  const s = stats.value;
  return [
    { label: '笔记', icon: 'mdi-note-text-outline', color: 'primary', count: s?.notes_count ?? 0, size: null as number | null },
    { label: '书签', icon: 'mdi-bookmark-outline', color: 'secondary', count: s?.bookmarks_count ?? 0, size: null as number | null },
    { label: '图片', icon: 'mdi-image-outline', color: 'info', count: s?.images_count ?? 0, size: s?.images_size ?? 0 },
    { label: '文件', icon: 'mdi-file-outline', color: 'success', count: s?.files_count ?? 0, size: s?.files_size ?? 0 },
  ];
});

async function loadStats() {
  statsLoading.value = true;
  try {
    stats.value = await server.setting.getUsageStats.query();
  } catch (e: any) {
    console.error(e);
  } finally {
    statsLoading.value = false;
  }
}

async function recalculate() {
  recalculating.value = true;
  try {
    stats.value = await server.setting.recalculateStats.mutate();
    emit('reloaded');
  } catch (e: any) {
    console.error(e);
    emit('error', e.message || '统计失败');
  } finally {
    recalculating.value = false;
  }
}

onMounted(loadStats);
watch(refreshTrigger, loadStats);
</script>
