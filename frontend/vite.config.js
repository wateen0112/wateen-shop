import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import basicSsl from '@vitejs/plugin-basic-ssl';
import { VitePWA } from 'vite-plugin-pwa';

// HTTPS is required during development to allow camera access
// through getUserMedia.
// Requests go through /api and Vite proxies them to the backend.
const target = process.env.VITE_API_TARGET || 'https://abo-wateen.algoria-wt.com';
const proxy = { '/api': { target, changeOrigin: true } };

export default defineConfig({
  plugins: [
    react(),
    basicSsl(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'favicon-16x16.png', 'favicon-32x32.png', 'apple-touch-icon.png', 'android-chrome-192x192.png', 'android-chrome-512x512.png', 'config.js'],
      manifest: false,
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg,woff,woff2,json}'],
        navigateFallback: '/index.html',
        navigateFallbackDenylist: [/^\/api\//],
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.startsWith('/api/'),
            handler: 'NetworkOnly',
            method: 'GET',
            options: { cacheName: 'api-network-only' }
          },
          {
            urlPattern: ({ url }) => url.pathname.startsWith('/api/'),
            handler: 'NetworkOnly',
            method: 'POST',
            options: { cacheName: 'api-network-only' }
          },
          {
            urlPattern: ({ url }) => url.pathname.startsWith('/api/'),
            handler: 'NetworkOnly',
            method: 'PUT',
            options: { cacheName: 'api-network-only' }
          },
          {
            urlPattern: ({ url }) => url.pathname.startsWith('/api/'),
            handler: 'NetworkOnly',
            method: 'PATCH',
            options: { cacheName: 'api-network-only' }
          },
          {
            urlPattern: ({ url }) => url.pathname.startsWith('/api/'),
            handler: 'NetworkOnly',
            method: 'DELETE',
            options: { cacheName: 'api-network-only' }
          },
          {
            urlPattern: /\.(?:png|jpg|jpeg|svg|gif|webp|ico)$/i,
            handler: 'StaleWhileRevalidate',
            options: { cacheName: 'images-cache', expiration: { maxEntries: 100, maxAgeSeconds: 60 * 60 * 24 * 30 } }
          },
          {
            urlPattern: /\.(?:css|js)$/i,
            handler: 'StaleWhileRevalidate',
            options: { cacheName: 'static-resources', expiration: { maxEntries: 200, maxAgeSeconds: 60 * 60 * 24 * 7 } }
          },
          {
            urlPattern: /\.(?:woff|woff2|ttf|eot)$/i,
            handler: 'CacheFirst',
            options: { cacheName: 'fonts-cache', expiration: { maxEntries: 20, maxAgeSeconds: 60 * 60 * 24 * 365 } }
          }
        ],
        cleanupOutdatedCaches: true,
        skipWaiting: true,
        clientsClaim: true
      },
      devOptions: {
        enabled: false,
        type: 'module'
      }
    })
  ],
  server: { host: true, proxy },
  preview: { host: true, proxy },
});
