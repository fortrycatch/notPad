import { defineStore } from "pinia";

const SETTINGS_CACHE_KEY = "userSettings";

function loadCachedSettings(): Record<string, string> {
    try {
        return JSON.parse(localStorage.getItem(SETTINGS_CACHE_KEY) || "{}");
    } catch {
        return {};
    }
}

export const useMainStore = defineStore("main", {
    state: () => ({
        authenticated: true,
        /** becomes true after App.vue finishes verifyToken (success or fail) */
        authReady: false,
        token: localStorage.getItem("token") || "",
        darkMode: localStorage.getItem("darkMode") !== "false",
        refreshTrigger: 0,
        settings: loadCachedSettings(),
    }),
    getters: {
        primaryColor: (state) => state.settings.primaryColor || "",
    },
    actions: {
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
        applySettings(settings: Record<string, string>) {
            this.settings = settings;
            localStorage.setItem(SETTINGS_CACHE_KEY, JSON.stringify(settings));
        },
    }
});