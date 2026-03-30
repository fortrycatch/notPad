import { ref } from 'vue';

/** 仅用于通知侧栏等 UI 重新拉取展示用资料，不存放任何个人信息 */
export const userProfileDisplayTick = ref(0);

export function bumpUserProfileDisplay() {
	userProfileDisplayTick.value++;
}
