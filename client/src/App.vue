<script setup lang="ts">
// import { ref } from "vue";
// import { server } from "./server";
import Normal from "./components/frame/Normal.vue";
import routes from "~pages";
import { computed, onMounted, watch } from "vue";
import { uigo } from "./easyKit";
import { useMainStore } from "./store/mainStore";
import { useTheme } from "vuetify";
// const test = ref("null");
// const input = ref("");
// async function hello() {
// 	const res = await server.hello.query(input.value);
// 	test.value = res;
// }
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

const applyPrimaryColor = (color: string) => {
	if (!color) return;
	theme.themes.value.light.colors.primary = color;
	theme.themes.value.dark.colors.primary = color;
};

watch(() => mainStore.primaryColor, applyPrimaryColor, { immediate: true });

onMounted(async () => {
	try {
		const result = await server.auth.verifyToken.query(mainStore.token);
		if (!result.ok) {
			mainStore.authenticated = false;
		} else {
			mainStore.authenticated = true;
			mainStore.applySettings(result.settings);
		}
	} catch {
		mainStore.authenticated = false;
	} finally {
		mainStore.authReady = true;
	}
});
</script>

<template>
  
    <Normal title="LoliAllinone" >
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
			<v-list nav density="comfortable">
				<v-list-item nav link title="首页" prepend-icon="mdi-home" to="/" />
				<v-list-item nav link title="笔记" prepend-icon="mdi-note-text" to="/notes" />
				<v-list-item nav link title="图床" prepend-icon="mdi-image" to="/image" />
				<v-list-item nav link title="网盘" prepend-icon="mdi-folder-multiple" to="/file" />
				<v-list-item nav link title="书签" prepend-icon="mdi-bookmark-multiple" to="/bookmark" />
				<v-list-item nav link title="账户" prepend-icon="mdi-information" to="/account" />
				<v-list-item nav link title="设置" prepend-icon="mdi-cog" to="/setting" />
			</v-list>
		</template>
	</Normal>

</template>

<style scoped></style>
