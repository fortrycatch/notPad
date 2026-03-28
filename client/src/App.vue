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

onMounted(async () => {
	if(await server.auth.verifyToken.query(localStorage.getItem("token") || "") == false){
		mainStore.authenticated = false;
	}else{
		mainStore.authenticated = true;
		mainStore.token = localStorage.getItem("token") || "";
	}
});
</script>

<template>
  
    <Normal title="LoliCloud" >
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
				</v-list>
			</v-menu>
		</template>
		<template #drawer>
			<v-list nav density="comfortable">
				<v-list-item nav link title="首页" prepend-icon="mdi-home" to="/" />
				<v-list-item nav link title="笔记" prepend-icon="mdi-note-text" to="/notes" />
				<v-list-item nav link title="图床" prepend-icon="mdi-image" to="/image" />
				<v-list-item nav link title="账户" prepend-icon="mdi-information" to="/account" />
				<v-list-item nav link title="设置" prepend-icon="mdi-cog" to="/setting" />
			</v-list>
		</template>
	</Normal>

</template>

<style scoped></style>
