import type { AppRouter } from '@zkit/server';
import { createTRPCProxyClient, httpBatchLink } from '@trpc/client';
import { useMainStore } from './store/mainStore';

let serverURL = "/trpc"
if(import.meta.env.MODE == "development"){
  serverURL = `http://localhost:${4000}/trpc`
}

const server = createTRPCProxyClient<AppRouter>({
  links: [
    httpBatchLink({ 
      url: serverURL,
      headers: () => {
        const mainStore = useMainStore();
        const h: Record<string, string> = { token: mainStore.token };
        if (mainStore.activeGroupId) h['x-group-id'] = mainStore.activeGroupId;
        return h;
      }
    }),
  ],
})

export {
    server,
}