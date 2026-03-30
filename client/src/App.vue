<script setup lang="ts">
import Normal from "./components/frame/Normal.vue";
import WorkspaceSwitcher from "./components/compose/WorkspaceSwitcher.vue";
import routes from "~pages";
import { computed, onMounted, watch } from "vue";
import { useMainStore } from "./store/mainStore";
import { useTheme } from "vuetify";
import { deriveThemeColors } from "./utils/themeColors";
console.log(routes);
import { server } from "./server";
const mainStore = useMainStore();
const theme = useTheme();
const darkMode = computed({
	get: () => mainStore.darkMode,
	set: (value: boolean) => mainStore.setDarkMode(value),
});

watch(darkMode, (value) => {
	theme.global.name.value = value ? "dark" : "light";
}, { immediate: true });

const DEFAULT_PRIMARY = '#ff9edd';
const applyPrimaryColor = (color: string) => {
	const derived = deriveThemeColors(color || DEFAULT_PRIMARY);
	Object.assign(theme.themes.value.light.colors, derived.light);
	Object.assign(theme.themes.value.dark.colors, derived.dark);
};

watch(() => mainStore.primaryColor, applyPrimaryColor, { immediate: true });

async function loadGroups() {
	try {
		const groups = await server.group.list.query();
		mainStore.setGroups(groups.map(g => ({
			id: g.id, name: g.name, role: g.role,
			avatar: (g as any).meta?.avatar,
			primaryColor: (g as any).meta?.primaryColor,
		})));
		mainStore.restoreActiveGroup();
	} catch { /* noop on fail */ }
}

async function loadUserProfile() {
	try {
		const p = await server.auth.getProfile.query();
		mainStore.userAvatar = (p.meta?.avatar as string) || '';
		mainStore.setUserPrimaryColor((p.meta?.primaryColor as string) || '');
	} catch { /* noop */ }
}

onMounted(async () => {
	try {
		const result = await server.auth.verifyToken.query(mainStore.token);
		if (!result.ok) {
			mainStore.authenticated = false;
		} else {
			mainStore.authenticated = true;
			await Promise.all([loadGroups(), loadUserProfile()]);
		}
	} catch {
		mainStore.authenticated = false;
	} finally {
		mainStore.authReady = true;
	}
});

watch(() => mainStore.authenticated, (val) => {
	if (val) { loadGroups(); loadUserProfile(); }
});
</script>

<template>
  
    <Normal :title="mainStore.activeGroup ? mainStore.activeGroup.name : 'LoliAllinone'" >
		<template #bar>
			<v-menu location="bottom end">
				<template #activator="{ props }">
					<v-btn v-bind="props" icon="mdi-brightness-6"></v-btn>
				</template>
				<v-list min-width="220">
					<v-list-item prepend-icon="mdi-theme-light-dark" title="暗黑模式">
						<template #append>
							<v-switch
								v-model="darkMode"
								hide-details
								inset
								color="primary"
							></v-switch>
						</template>
					</v-list-item>
					<v-divider class="my-1" />
					<v-list-item
						prepend-icon="mdi-palette"
						title="设置主题色"
						to="/setting"
						link
					/>
				</v-list>
			</v-menu>
		</template>
		<template #drawer>
			<WorkspaceSwitcher />
			<v-divider class="my-1" />
			<v-list nav density="comfortable">
				<v-list-item nav link title="首页" prepend-icon="mdi-home" to="/" />
				<v-list-item nav link title="笔记" prepend-icon="mdi-note-text" to="/notes" />
				<v-list-item nav link title="图床" prepend-icon="mdi-image" to="/image" />
				<v-list-item nav link title="网盘" prepend-icon="mdi-folder-multiple" to="/file" />
				<v-list-item nav link title="书签" prepend-icon="mdi-bookmark-multiple" to="/bookmark" />
				<v-list-item nav link title="群组" prepend-icon="mdi-account-group" to="/group" />
				<v-list-item nav link title="账户" prepend-icon="mdi-information" to="/account" />
				<v-list-item nav link title="设置" prepend-icon="mdi-cog" to="/setting" />
			</v-list>
		</template>
	</Normal>

</template>

<style scoped></style>
