const CACHE = 'kanni-mol-chat-v1'
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(['/','/manifest.webmanifest','/icon.svg']))))
self.addEventListener('fetch', event => event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request))))
