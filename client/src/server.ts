import type{ AppRouter } from '@zkit/server';
import { createTRPCProxyClient, httpBatchLink } from '@trpc/client';
import { useMainStore } from './store/mainStore';

const server = createTRPCProxyClient<AppRouter>({
  links: [
    httpBatchLink({ 
      url: `http://localhost:${4000}`,
      headers: () => {
        const mainStore = useMainStore();
        return {
          token: mainStore.token
        };
      }
    }),
  ],
})

export {
    server,
}