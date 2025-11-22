import { defineStore } from "pinia";
export const useMainStore = defineStore("main", {
    state: () => ({
        authenticated: true,
        token: "null",
        refreshTrigger: 0, // 用于触发页面刷新的计数器
    }),
    actions: {
        // 触发刷新
        triggerRefresh() {
            this.refreshTrigger++
        }
    }
});