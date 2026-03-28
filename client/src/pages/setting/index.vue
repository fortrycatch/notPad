<template>
  <v-container class="py-8" fluid>
    <v-card variant="elevated" elevation="1">
      <v-card-item>
        <v-card-title class="text-title-md">
          <v-icon class="mr-2" size="22">mdi-palette</v-icon>
          主题色
        </v-card-title>
      </v-card-item>
      <v-divider />

      <v-card-text class="setting-body">
        <div class="color-presets">
          <v-tooltip
            v-for="preset in presets"
            :key="preset.value"
            location="top"
            :text="preset.label"
          >
            <template #activator="{ props: tipProps }">
              <button
                v-bind="tipProps"
                type="button"
                class="color-swatch"
                :class="{ 'color-swatch--active': selectedColor === preset.value }"
                :style="{ backgroundColor: preset.value }"
                :aria-label="preset.label"
                @click="pickColor(preset.value)"
              />
            </template>
          </v-tooltip>
        </div>

        <div class="custom-color-row">
          <v-text-field
            v-model="customInput"
            label="自定义色值"
            placeholder="#ff9edd"
            variant="outlined"
            density="comfortable"
            hide-details
            maxlength="7"
            @keydown.enter="applyCustom"
          >
            <template #prepend-inner>
              <div class="color-dot" :style="{ backgroundColor: validCustom || '#ccc' }" />
            </template>
          </v-text-field>
          <v-btn
            color="primary"
            variant="flat"
            :disabled="!validCustom"
            @click="applyCustom"
          >
            应用
          </v-btn>
        </div>

        <div v-if="selectedColor" class="current-color-hint">
          当前：
          <span class="color-dot" :style="{ backgroundColor: selectedColor }" />
          <span class="current-name">{{ currentPresetName }}</span>
          <code class="current-hex">{{ selectedColor }}</code>
          <v-btn
            v-if="selectedColor !== DEFAULT_PRIMARY"
            variant="text"
            size="small"
            @click="resetColor"
          >
            恢复默认
          </v-btn>
        </div>
      </v-card-text>
    </v-card>

    <v-snackbar v-model="snackbar" :timeout="2000" color="primary">
      {{ snackbarText }}
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useMainStore } from '../../store/mainStore'
import { server } from '../../server'

const DEFAULT_PRIMARY = '#ff9edd'

/** B 站早年梗色命名，仅作展示用 */
const presets = [
  { label: '猛男粉', value: '#ff9edd' },
  { label: '胖次蓝', value: '#00a1d6' },
  { label: '早苗绿', value: '#43a047' },
  { label: '咸蛋黄', value: '#ffb300' },
  { label: '基佬紫', value: '#7b1fa2' },
  { label: '姨妈红', value: '#d32f2f' },
  { label: '高级黑', value: '#455a64' },
  { label: '原谅绿', value: '#8bc34a' },
  { label: '土豪金', value: '#c0a060' },
  { label: '橙汁儿', value: '#ff9800' },
]

const mainStore = useMainStore()
const selectedColor = ref(mainStore.primaryColor || DEFAULT_PRIMARY)
const customInput = ref('')
const snackbar = ref(false)
const snackbarText = ref('')

const HEX_RE = /^#[0-9a-fA-F]{6}$/
const validCustom = computed(() => {
  const v = customInput.value.trim()
  return HEX_RE.test(v) ? v : ''
})

const currentPresetName = computed(() => {
  const hit = presets.find((p) => p.value.toLowerCase() === selectedColor.value.toLowerCase())
  if (hit) return hit.label
  return '自定义'
})

const toast = (msg: string) => {
  snackbarText.value = msg
  snackbar.value = true
}

const saveColor = async (color: string) => {
  selectedColor.value = color
  const newSettings = { ...mainStore.settings, primaryColor: color }
  mainStore.applySettings(newSettings)
  await server.setting.set.mutate({ key: 'primaryColor', value: color })
  toast('主题色已更新')
}

const pickColor = (color: string) => {
  void saveColor(color)
}

const applyCustom = () => {
  if (!validCustom.value) return
  void saveColor(validCustom.value)
  customInput.value = ''
}

const resetColor = async () => {
  selectedColor.value = DEFAULT_PRIMARY
  const newSettings = { ...mainStore.settings }
  delete newSettings.primaryColor
  mainStore.applySettings(newSettings)
  await server.setting.remove.mutate({ key: 'primaryColor' })
  toast('已恢复默认主题色')
}
</script>

<style scoped>
.setting-body {
  display: grid;
  gap: 20px;
}

.color-presets {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.color-swatch {
  width: 40px;
  height: 40px;
  padding: 0;
  border: none;
  cursor: pointer;
  transition: outline-color 0.12s, transform 0.12s;
  outline: 2px solid transparent;
  outline-offset: 2px;
}

.color-swatch:hover {
  transform: scale(1.06);
}

.color-swatch--active {
  outline-color: rgb(var(--v-theme-on-surface));
}

.custom-color-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 12px;
  align-items: center;
}

.color-dot {
  display: inline-block;
  width: 18px;
  height: 18px;
  vertical-align: middle;
  margin-right: 6px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.2);
}

.current-color-hint {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  font-size: 14px;
  color: rgb(var(--v-theme-on-surface-variant));
}

.current-name {
  font-weight: 600;
  color: rgb(var(--v-theme-on-surface));
}

.current-hex {
  font-size: 13px;
  background: rgba(var(--v-theme-on-surface), 0.06);
  padding: 2px 8px;
}
</style>
