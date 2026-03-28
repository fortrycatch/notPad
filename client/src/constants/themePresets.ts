/** 应用默认主色（与 Vuetify 初始主题一致） */
export const DEFAULT_THEME_PRIMARY = '#ff9edd'

export interface ThemeColorPreset {
  label: string
  value: string
}

export const THEME_COLOR_PRESETS: ThemeColorPreset[] = [
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
