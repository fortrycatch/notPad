import { defineStore } from "pinia";

const PRIMARY_CACHE_KEY = "cachedPrimaryColor";

export interface GroupInfo {
    id: string;
    name: string;
    role: string;
    avatar?: string;
    primaryColor?: string;
}

export const useMainStore = defineStore("main", {
    state: () => ({
        authenticated: true,
        authReady: false,
        token: localStorage.getItem("token") || "",
        darkMode: localStorage.getItem("darkMode") !== "false",
        refreshTrigger: 0,
        activeGroupId: null as string | null,
        groups: [] as GroupInfo[],
        userAvatar: '' as string,
        userPrimaryColor: '' as string,
    }),
    getters: {
        primaryColor(state): string {
            if (state.activeGroupId) {
                const g = state.groups.find(g => g.id === state.activeGroupId);
                if (g?.primaryColor) return g.primaryColor;
            }
            return state.userPrimaryColor;
        },
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
        setUserPrimaryColor(color: string) {
            this.userPrimaryColor = color;
            localStorage.setItem(PRIMARY_CACHE_KEY, color);
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