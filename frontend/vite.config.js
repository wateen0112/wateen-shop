import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import basicSsl from '@vitejs/plugin-basic-ssl';

// HTTPS مطلوب حتى يسمح المتصفح على الموبايل باستخدام الكاميرا (getUserMedia).
// الطلبات تذهب إلى /api ثم يعيدها Vite إلى الباك-إند، لذا تعمل من الهاتف أيضاً.
const target = process.env.VITE_API_TARGET || 'https://abo-wateen.algoria-wt.com';
const proxy = { '/api': { target, changeOrigin: true } };

export default defineConfig({
  plugins: [react(), basicSsl()],
  server: { host: true, proxy },
  preview: { host: true, proxy },
});
