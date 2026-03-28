import { defineStore } from "pinia";
export const useMainStore = defineStore("main", {
    state: () => ({
        authenticated: true,
        token: "null",
        darkMode: localStorage.getItem("darkMode") !== "false",
        refreshTrigger: 0, // 用于触发页面刷新的计数器
    }),
    actions: {
        // 触发刷新
        triggerRefresh() {
            this.refreshTrigger++
        },
        setDarkMode(value: boolean) {
            this.darkMode = value;
            localStorage.setItem("darkMode", String(value));
        },
        toggleDarkMode() {
            this.setDarkMode(!this.darkMode);
        },
    }
});