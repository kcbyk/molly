#!/usr/bin/env node
// Render REST API ile Molly API servisini kurar / günceller.
// Gerekli: RENDER_API_KEY (GitHub secret). Diğer sırlar opsiyoneldir.
//
// Kullanım: node .github/scripts/render-deploy.mjs

const API = 'https://api.render.com/v1';
const KEY = (process.env.RENDER_API_KEY || '').trim();
const NAME = process.env.RENDER_SERVICE_NAME || 'molly-api';
const REPO = process.env.REPO_URL || 'https://github.com/kcbyk/molly';
const BRANCH = process.env.DEPLOY_BRANCH || 'main';
const PLAN = process.env.RENDER_PLAN || 'free';
const REGION = process.env.RENDER_REGION || 'frankfurt';
const ROOT_DIR = 'server';

if (!KEY) {
  console.error(
    '✖ RENDER_API_KEY yok. GitHub > Settings > Secrets and variables > Actions > New repository secret',
  );
  process.exit(1);
}

async function api(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${KEY}`,
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const text = await res.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  if (!res.ok) {
    const err = new Error(
      `Render API ${options.method || 'GET'} ${path} → ${res.status}: ${
        typeof body === 'string' ? body : JSON.stringify(body)
      }`,
    );
    err.status = res.status;
    err.body = body;
    throw err;
  }
  return body;
}

/** Toplanacak ortam değişkenleri (boş olanlar atlanır). */
function envVars() {
  const pairs = [
    ['SPOTIFY_CLIENT_ID', process.env.SPOTIFY_CLIENT_ID],
    ['SPOTIFY_CLIENT_SECRET', process.env.SPOTIFY_CLIENT_SECRET],
    ['SPOTIFY_REFRESH_TOKEN', process.env.SPOTIFY_REFRESH_TOKEN],
    ['SPOTIFY_SP_DC', process.env.SPOTIFY_SP_DC],
    ['RAPIDAPI_KEYS', process.env.RAPIDAPI_KEYS],
    ['RAPIDAPI_HOST', process.env.RAPIDAPI_HOST || 'youtube-mp36.p.rapidapi.com'],
    ['MP3_API_KEY', process.env.MP3_API_KEY],
    ['MP3_API_BASE', process.env.MP3_API_BASE || 'https://mp3-apisi.onrender.com'],
    ['NODE_ENV', 'production'],
  ];
  return pairs
    .filter(([, value]) => value && String(value).trim())
    .map(([key, value]) => ({ key, value: String(value).trim() }));
}

function serviceUrl(service) {
  return (
    service?.serviceDetails?.url ||
    (service?.serviceDetails?.urls || [])[0]?.url ||
    null
  );
}

async function main() {
  // 1) Hesap sahibi
  const owners = await api('/owners?limit=20');
  const owner = Array.isArray(owners) ? owners[0]?.owner : owners;
  if (!owner?.id) throw new Error('Render hesabında owner bulunamadı.');
  console.log(`→ Hesap: ${owner.name || owner.email} (${owner.id})`);

  // 2) Servis var mı?
  const raw = await api('/services?limit=100');
  const services = (Array.isArray(raw) ? raw : []).map((entry) => entry.service || entry);
  let service = services.find((s) => s?.name === NAME) || null;

  if (!service) {
    console.log(`→ "${NAME}" yok, oluşturuluyor (${PLAN}/${REGION})…`);
    const created = await api('/services', {
      method: 'POST',
      body: JSON.stringify({
        type: 'web_service',
        name: NAME,
        ownerId: owner.id,
        repo: REPO,
        branch: BRANCH,
        autoDeploy: 'yes',
        rootDir: ROOT_DIR,
        serviceDetails: {
          env: 'node',
          plan: PLAN,
          region: REGION,
          healthCheckPath: '/api/health',
          envSpecificDetails: {
            buildCommand: 'npm install',
            startCommand: 'npm start',
          },
        },
      }),
    });
    service = created.service || created;
    console.log(`✓ Servis oluşturuldu: ${service.id}`);
  } else {
    console.log(`→ Servis mevcut: ${service.id} (${service.name})`);
    try {
      await api(`/services/${service.id}`, {
        method: 'PUT',
        body: JSON.stringify({
          name: service.name,
          branch: BRANCH,
          rootDir: ROOT_DIR,
          autoDeploy: 'yes',
          serviceDetails: {
            ...(service.serviceDetails || {}),
            healthCheckPath: '/api/health',
            envSpecificDetails: {
              buildCommand: 'npm install',
              startCommand: 'npm start',
            },
          },
        }),
      });
      console.log('✓ Build/start komutları güncellendi');
    } catch (error) {
      // Eski plan/şema farkı yüzünden güncelleme tutmazsa kritik değil.
      console.warn(`! Güncelleme atlandı: ${error.message}`);
    }
  }

  // 3) Ortam değişkenleri (tam liste gönderilir, eskiler korunur)
  const vars = envVars();
  if (vars.length) {
    await api(`/services/${service.id}/env-vars`, {
      method: 'PUT',
      body: JSON.stringify(vars),
    });
    console.log(`✓ ${vars.length} ortam değişkeni yazıldı: ${vars.map((v) => v.key).join(', ')}`);
  } else {
    console.warn('! Yazılacak ortam değişkeni yok');
  }

  // 4) Dağıtımı tetikle
  try {
    await api(`/services/${service.id}/deploys`, {
      method: 'POST',
      body: JSON.stringify({ clearCache: 'do_not_clear' }),
    });
    console.log('✓ Dağıtım tetiklendi');
  } catch (error) {
    console.warn(`! Dağıtım tetiklenemedi (autoDeploy zaten çalışacak): ${error.message}`);
  }

  const url = serviceUrl(service);
  console.log('');
  console.log('──────────────────────────────────────────');
  console.log(`  Servis : ${service.name}`);
  console.log(`  URL    : ${url || '(dağıtım bitince belli olur)'}`);
  console.log(`  Panel  : https://dashboard.render.com/web/${service.id}`);
  if (url) {
    console.log(`  Sağlık : ${url}/api/health`);
    console.log('');
    console.log(`  ► mobil için: API_BASE=${url}`);
  }
  console.log('──────────────────────────────────────────');

  if (process.env.GITHUB_STEP_SUMMARY) {
    const file = process.env.GITHUB_STEP_SUMMARY;
    const { appendFileSync } = await import('node:fs');
    appendFileSync(
      file,
      [
        '## Render dağıtımı',
        '',
        `- **Servis:** ${service.name} (\`${service.id}\`)`,
        `- **Adres:** ${url || 'dağıtım sürüyor'}`,
        url ? `- **Sağlık:** ${url}/api/health` : '',
        '',
      ].join('\n'),
    );
  }
}

main().catch((error) => {
  console.error('✖', error.message);
  if (error.status === 402) {
    console.error('  → Ücretsiz plan bu hesapta kapalı olabilir. RENDER_PLAN=starter dene.');
  }
  process.exit(1);
});
