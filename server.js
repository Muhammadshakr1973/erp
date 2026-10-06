const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.map': 'application/json',
};

const SEARCH_DIRS = [
  path.join(__dirname, 'build', 'web'),
  path.join(__dirname, 'web'),
  __dirname
];

function findFile(relativePath) {
  for (const dir of SEARCH_DIRS) {
    const fullPath = path.join(dir, relativePath);
    if (fs.existsSync(fullPath) && fs.statSync(fullPath).isFile()) {
      return fullPath;
    }
  }
  return null;
}

const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');

  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    res.end();
    return;
  }

  // Parse URL
  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  let pathname = decodeURIComponent(parsedUrl.pathname);
  if (pathname.endsWith('/') && pathname.length > 1) {
    pathname = pathname.slice(0, -1);
  }

  const ext = path.extname(pathname).toLowerCase();

  // If the request is for a static asset with a non-HTML extension
  if (ext && ext !== '.html') {
    const foundPath = findFile(pathname);
    if (foundPath) {
      const contentType = MIME_TYPES[ext] || 'application/octet-stream';
      fs.readFile(foundPath, (err, data) => {
        if (err) {
          res.statusCode = 500;
          res.end('Error reading file');
          return;
        }
        res.statusCode = 200;
        res.setHeader('Content-Type', contentType);
        res.end(data);
      });
      return;
    }

    // Special fallback for flutter.js to avoid any SyntaxError
    if (pathname.endsWith('flutter.js')) {
      res.statusCode = 200;
      res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
      res.end('window._flutter = window._flutter || { loader: { load: function() {}, loadEntrypoint: function() {} } };');
      return;
    }

    // Static asset not found - NEVER return HTML for static assets!
    res.statusCode = 404;
    const fallbackMime = MIME_TYPES[ext] || 'text/plain';
    res.setHeader('Content-Type', fallbackMime);
    if (ext === '.js' || ext === '.mjs') {
      res.end('/* File not found: ' + pathname + ' */');
    } else {
      res.end('Not Found: ' + pathname);
    }
    return;
  }

  // For HTML pages or SPA routes (e.g. /, /orders, /customers, etc.)
  let htmlPath = findFile(pathname === '/' ? 'index.html' : (pathname.endsWith('.html') ? pathname : 'index.html'));
  if (!htmlPath) {
    htmlPath = findFile('index.html');
  }

  if (htmlPath) {
    fs.readFile(htmlPath, (err, content) => {
      if (err) {
        res.statusCode = 500;
        res.setHeader('Content-Type', 'text/plain');
        res.end('Error loading index.html');
        return;
      }
      res.statusCode = 200;
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
      res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
      res.end(content);
    });
    return;
  }

  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end('<!DOCTYPE html><html lang="ku" dir="rtl"><head><title>GARDI ERP</title></head><body><h1>GARDI ERP</h1></body></html>');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Dev server listening on http://0.0.0.0:${PORT}`);
});

