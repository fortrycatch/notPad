<script setup lang="ts">
import { useMainStore } from '../../store/mainStore';

const mainStore = useMainStore();

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
				:prepend-icon="mainStore.activeGroup ? 'mdi-account-group' : 'mdi-account'"
			>
				<v-list-item-title class="text-body-2 font-weight-medium">
					{{ mainStore.activeGroup?.name ?? '个人空间' }}
				</v-list-item-title>
				<template #append>
					<v-icon size="small">mdi-chevron-down</v-icon>
				</template>
			</v-list-item>
		</template>

		<v-list density="compact" min-width="200" max-height="400">
			<v-list-subheader>切换空间</v-list-subheader>

			<v-list-item
				prepend-icon="mdi-account"
				title="个人空间"
				:active="!mainStore.activeGroupId"
				@click="switchTo(null)"
			/>

			<v-divider v-if="mainStore.groups.length > 0" class="my-1" />

			<v-list-item
				v-for="g in mainStore.groups"
				:key="g.id"
				prepend-icon="mdi-account-group"
				:title="g.name"
				:subtitle="g.role"
				:active="mainStore.activeGroupId === g.id"
				@click="switchTo(g.id)"
			/>

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
