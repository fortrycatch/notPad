<script setup lang="ts">
import { computed, ref, watch, onMounted } from 'vue';
import { useMainStore } from '../../store/mainStore';
import { server } from '../../server';
import { userProfileDisplayTick } from '../../utils/userProfileSync';

const mainStore = useMainStore();

const userDisplayName = ref('');
const userAvatarUrl = ref('');

async function loadDisplayProfile() {
	userDisplayName.value = '';
	userAvatarUrl.value = '';
	if (!mainStore.authenticated) return;
	try {
		const p = await server.auth.getProfile.query();
		userDisplayName.value = p.name || '';
		userAvatarUrl.value = (p.meta?.avatar as string) || '';
	} catch { /* noop */ }
}

onMounted(loadDisplayProfile);
watch(() => mainStore.authenticated, (ok) => {
	if (ok) loadDisplayProfile();
	else {
		userDisplayName.value = '';
		userAvatarUrl.value = '';
	}
});
watch(userProfileDisplayTick, loadDisplayProfile);

const workspaceTitle = computed(() => {
	if (mainStore.activeGroup) return mainStore.activeGroup.name;
	return userDisplayName.value || '个人空间';
});

const activeAvatar = computed(() => {
	if (mainStore.activeGroup) return mainStore.activeGroup.avatar || '';
	return userAvatarUrl.value;
});

function switchTo(groupId: string | null) {
	mainStore.switchGroup(groupId);
}
</script>

<template>
	<v-menu location="bottom start" :close-on-content-click="true">
		<template #activator="{ props }">
			<v-list-item
				v-bind="props"
				nav
				class="workspace-activator"
			>
				<template #prepend>
					<v-avatar size="28" :color="activeAvatar ? undefined : (mainStore.activeGroup ? 'secondary' : 'primary')" variant="tonal" class="mr-2">
						<v-img v-if="activeAvatar" :src="activeAvatar + '?x-oss-process=image/resize,w_80'" />
						<v-icon v-else size="16">{{ mainStore.activeGroup ? 'mdi-account-group' : 'mdi-account' }}</v-icon>
					</v-avatar>
				</template>
				<v-list-item-title class="text-body-2 font-weight-medium">
					{{ workspaceTitle }}
				</v-list-item-title>
				<template #append>
					<v-icon size="small">mdi-chevron-down</v-icon>
				</template>
			</v-list-item>
		</template>

		<v-list density="compact" min-width="200" max-height="400">
			<v-list-subheader>切换空间</v-list-subheader>

			<v-list-item
				:title="userDisplayName || '个人空间'"
				:active="!mainStore.activeGroupId"
				@click="switchTo(null)"
			>
				<template #prepend>
					<v-avatar size="24" :color="userAvatarUrl ? undefined : 'primary'" variant="tonal" class="mr-2">
						<v-img v-if="userAvatarUrl" :src="userAvatarUrl + '?x-oss-process=image/resize,w_80'" />
						<v-icon v-else size="14">mdi-account</v-icon>
					</v-avatar>
				</template>
			</v-list-item>

			<v-divider v-if="mainStore.groups.length > 0" class="my-1" />

			<v-list-item
				v-for="g in mainStore.groups"
				:key="g.id"
				:title="g.name"
				:subtitle="g.role"
				:active="mainStore.activeGroupId === g.id"
				@click="switchTo(g.id)"
			>
				<template #prepend>
					<v-avatar size="24" :color="g.avatar ? undefined : 'secondary'" variant="tonal" class="mr-2">
						<v-img v-if="g.avatar" :src="g.avatar + '?x-oss-process=image/resize,w_80'" />
						<v-icon v-else size="14">mdi-account-group</v-icon>
					</v-avatar>
				</template>
			</v-list-item>

			<v-divider class="my-1" />

			<v-list-item
				prepend-icon="mdi-plus"
				title="群组管理"
				to="/group"
			/>
		</v-list>
	</v-menu>
</template>

<style scoped>
.workspace-activator {
	border-radius: 8px;
	margin: 4px 8px;
}
</style>
