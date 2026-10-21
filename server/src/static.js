import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { SERVER_DIR } from './env.js';
import { renderLanding } from './landing.js';

const DEFAULT_WEB_DIR = path.resolve(SERVER_DIR, '..', 'build', 'web');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.mp3': 'audio/mpeg',
  '.mp4': 'video/mp4',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.map': 'application/json; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
};

function webDir() {
  return path.resolve(process.env.WEB_DIR || DEFAULT_WEB_DIR);
}

function insideRoot(root, target) {
  const relative = path.relative(root, target);
  return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

function cacheControl(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.html') return 'no-cache';
  if (['.png', '.jpg', '.jpeg', '.webp', '.svg', '.ico', '.ttf', '.otf', '.woff', '.woff2', '.wasm'].includes(ext)) {
    return 'public, max-age=604800';
  }
  return 'public, max-age=300';
}

async function fileStats(filePath) {
  try {
    const info = await stat(filePath);
    return info.isFile() ? info : null;
  } catch {
    return null;
  }
}

export async function serveStatic(req, res, url, features) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD' });
    res.end('Method Not Allowed');
    return;
  }

  const root = webDir();
  let pathname;
  try {
    pathname = decodeURIComponent(url.pathname);
  } catch {
    pathname = url.pathname;
  }

  const target = path.resolve(root, `.${pathname}`);
  if (!insideRoot(root, target)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  let filePath = target;
  let info = await fileStats(filePath);

  // /foo → /foo/index.html
  if (!info && !path.extname(pathname)) {
    const indexPath = path.join(filePath, 'index.html');
    const indexInfo = await fileStats(indexPath);
    if (indexInfo) {
      filePath = indexPath;
      info = indexInfo;
    }
  }

  // SPA fallback: uzantısız bilinmeyen yollar index.html'e gider.
  if (!info && !path.extname(pathname)) {
    const fallback = path.join(root, 'index.html');
    const fallbackInfo = await fileStats(fallback);
    if (fallbackInfo) {
      filePath = fallback;
      info = fallbackInfo;
    }
  }

  if (!info) {
    if (pathname === '/' || pathname === '/index.html') {
      const html = renderLanding(features);
      res.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-cache',
      });
      res.end(req.method === 'HEAD' ? undefined : html);
      return;
    }
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Bulunamadı');
    return;
  }

  res.writeHead(200, {
    'Content-Type': MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
    'Content-Length': info.size,
    'Cache-Control': cacheControl(filePath),
    'Service-Worker-Allowed': '/',
  });
  if (req.method === 'HEAD') {
    res.end();
    return;
  }
  createReadStream(filePath).pipe(res);
}

export function webBuildExists() {
  return fileStats(path.join(webDir(), 'index.html')).then(Boolean);
}

export function resolvedWebDir() {
  return webDir();
}
