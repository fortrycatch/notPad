import { defineStore } from "pinia";

const SETTINGS_CACHE_KEY = "userSettings";

function loadCachedSettings(): Record<string, string> {
    try {
        return JSON.parse(localStorage.getItem(SETTINGS_CACHE_KEY) || "{}");
    } catch {
        return {};
    }
}

export interface GroupInfo {
    id: string;
    name: string;
    role: string;
}

export const useMainStore = defineStore("main", {
    state: () => ({
        authenticated: true,
        authReady: false,
        token: localStorage.getItem("token") || "",
        darkMode: localStorage.getItem("darkMode") !== "false",
        refreshTrigger: 0,
        settings: loadCachedSettings(),
        activeGroupId: null as string | null,
        groups: [] as GroupInfo[],
    }),
    getters: {
        primaryColor: (state) => state.settings.primaryColor || "",
        activeGroup: (state) => state.groups.find(g => g.id === state.activeGroupId) ?? null,
        isGroupContext: (state) => state.activeGroupId !== null,
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
        switchGroup(groupId: string | null) {
            this.activeGroupId = groupId;
            if (groupId) {
                localStorage.setItem("activeGroupId", groupId);
            } else {
                localStorage.removeItem("activeGroupId");
            }
            this.triggerRefresh();
        },
        setGroups(groups: GroupInfo[]) {
            this.groups = groups;
            if (this.activeGroupId && !groups.find(g => g.id === this.activeGroupId)) {
                this.switchGroup(null);
            }
        },
        restoreActiveGroup() {
            const saved = localStorage.getItem("activeGroupId");
            if (saved && this.groups.find(g => g.id === saved)) {
                this.activeGroupId = saved;
            }
        },
    }
});