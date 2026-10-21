import './src/env.js'; // .env daima ilk okunmalı

import { createServer } from 'node:http';
import { handleApi, featureFlags } from './src/api.js';
import { resolvedWebDir, serveStatic, webBuildExists } from './src/static.js';

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';

const server = createServer(async (req, res) => {
  const started = Date.now();
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

  // CORS — Flutter web farklı porttan (flutter run) bağlanabilsin.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept');
  res.setHeader('Access-Control-Max-Age', '86400');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  try {
    if (url.pathname === '/api' || url.pathname.startsWith('/api/')) {
      await handleApi(req, res, url);
    } else {
      await serveStatic(req, res, url, featureFlags());
    }
  } catch (error) {
    console.error('[server]', error);
    if (!res.headersSent) {
      res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ error: 'Sunucu hatası' }));
    } else {
      res.end();
    }
  } finally {
    if (url.pathname.startsWith('/api/')) {
      console.log(
        `${req.method} ${url.pathname}${url.search ? '?' + url.searchParams.toString().slice(0, 60) : ''} ` +
          `→ ${res.statusCode} (${Date.now() - started}ms)`,
      );
    }
  }
});

server.listen(PORT, HOST, async () => {
  const flags = featureFlags();
  console.log(`\n🎵 Molly sunucusu → http://${HOST}:${PORT}`);
  console.log(`   Spotify arama : ${flags.spotifySearch ? 'açık' : 'kapalı (iTunes yedeği)'}`);
  console.log(`   Canvas        : ${flags.canvas}`);
  console.log(`   Web klasörü   : ${resolvedWebDir()}`);
  console.log(`   Web derlemesi : ${(await webBuildExists()) ? 'bulundu' : 'yok (landing sayfası)'}\n`);
});

function shutdown(signal) {
  console.log(`\n${signal} alındı, kapatılıyor...`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 3000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
