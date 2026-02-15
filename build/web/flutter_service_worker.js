'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"splash/img/light-3x.png": "5dc143761a17aff022f091928f74cbd2",
"splash/img/dark-1x.png": "6d9db5e825214a550feb0e92171b5fb1",
"splash/img/light-4x.png": "2f310e8055d167ce255cbe4482927ff8",
"splash/img/dark-3x.png": "5dc143761a17aff022f091928f74cbd2",
"splash/img/dark-2x.png": "142353006d6b831e6c8bfdfe3cae830e",
"splash/img/light-1x.png": "6d9db5e825214a550feb0e92171b5fb1",
"splash/img/light-2x.png": "142353006d6b831e6c8bfdfe3cae830e",
"splash/img/dark-4x.png": "2f310e8055d167ce255cbe4482927ff8",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "5137be518675a5cc3fb86c14c6a8a4a2",
"index.html": "bfcadef2b9110603babdc13c737c8352",
"/": "bfcadef2b9110603babdc13c737c8352",
"icons/Icon-512.png": "f72d7ab2cb5476de3511dc073b1e559b",
"icons/Icon-maskable-512.png": "f72d7ab2cb5476de3511dc073b1e559b",
"icons/Icon-192.png": "f72d7ab2cb5476de3511dc073b1e559b",
"icons/Icon-maskable-192.png": "f72d7ab2cb5476de3511dc073b1e559b",
"manifest.json": "b2c093231b46cf1f05f40802e58c322f",
"version.json": "b0641702319f6538077c8c45dd0124d3",
"assets/fonts/MaterialIcons-Regular.otf": "666c9afdac9a836236e1bfd513386b53",
"assets/NOTICES": "f8f467a9248e6c9fc1b92e72d0de2785",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.css": "5a8d0222407e388155d7d1395a75d5b9",
"assets/packages/flutter_inappwebview/assets/t_rex_runner/t-rex.html": "16911fcc170c8af1c5457940bd0bf055",
"assets/packages/flutter_inappwebview_web/assets/web/web_support.js": "509ae636cfdd93e49b5a6eaf0f06d79f",
"assets/packages/fluttertoast/assets/toastify.js": "56e2c9cedd97f10e7e5f1cebd85d53e3",
"assets/packages/fluttertoast/assets/toastify.css": "a85675050054f179444bc5ad70ffc635",
"assets/AssetManifest.json": "632148e5a74591cc5c5a863be27db115",
"assets/AssetManifest.bin.json": "1b5326a5b132eac5ada2f7f1df6f772d",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/FontManifest.json": "6ffc18ed2e52e80ec95fd6a61ae4fcb7",
"assets/assets/notification_templates.json": "00da94108152ee4c940b4991aac4ad66",
"assets/assets/fonts/Poppins-Bold.ttf": "46c307f0d9662c8a65904dd5a8229fd8",
"assets/assets/fonts/Poppins-Regular.ttf": "20cf72019e7de1a051dfe47a13524bb5",
"assets/assets/fonts/Inter-Regular.ttf": "b11ff813a86091a7538d1eea56075581",
"assets/assets/fonts/Inter-Bold.ttf": "b11ff813a86091a7538d1eea56075581",
"assets/assets/icons/google_logo.svg": "877c6452f27e30044f90d56396e7d457",
"assets/assets/images/onboarding_rocket.svg": "c6f84372d91a6686316efc01296f741d",
"assets/assets/images/onboarding_learn.svg": "ed123ccc510a53726c2c82e05c984f4c",
"assets/assets/images/onboarding_background.png": "ff5bdc9da184418144a06f6c77e98add",
"assets/assets/images/onboarding_notes.svg": "ad2abdea9a0bb696f6f10d13d80d28fc",
"assets/assets/images/web/avatar_3.png": "42afb5e05e147003d78bb5c51eb23279",
"assets/assets/images/web/study_illustration.png": "77346714f5cfdd96cf969f5823caefa4",
"assets/assets/images/web/upload_illustration.png": "ee6bd558bb79f4c373b3afa036c17ac0",
"assets/assets/images/web/success_illustration.png": "66e6ea9b615963163625704a248e4ff0",
"assets/assets/images/web/avatar_2.png": "409c7bcdba6921e8f6d34408891d894d",
"assets/assets/images/web/achievement_illustration.png": "05ebf0f1f8cbb5c41b9588395e48e8db",
"assets/assets/images/web/hero_illustration.png": "2038e78502181da85e1c9dcaa950cd60",
"assets/assets/images/web/creator_hero.png": "105f7061678cbe0e37300dcf33aec14c",
"assets/assets/images/web/empty_library.png": "7aad71ece8c3bd9513dd473235a1c735",
"assets/assets/images/web/avatar_1.png": "0a814f08144a91c8d4bf4ce2a45e0568",
"assets/assets/images/sumquiz_logo.png": "f72d7ab2cb5476de3511dc073b1e559b",
"assets/AssetManifest.bin": "66035156884f02bcfd3eab8a2eb0dc9a",
"main.dart.js": "cc3612967e4242095c211724fedfa006",
"favicon.png": "f72d7ab2cb5476de3511dc073b1e559b"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
