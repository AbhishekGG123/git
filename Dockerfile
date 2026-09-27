FROM node:24-bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends git nginx apache2-utils \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable \
    && corepack prepare pnpm@11.7.0 --activate

WORKDIR /app

# Build the current DeepSeek Harness source so we can apply the remote-Web fixes
# before compiling. This avoids the older published package behavior that causes
# remote Settings / Models / Agent Presets to return HTTP 403.
RUN git clone --depth 1 https://github.com/deepseek-ai/deepseek-harness.git .

# Apply the two remote-web compatibility fixes:
# 1) allow the configured trusted host to pass the API trust check
# 2) make the client treat the explicitly deployed web host as an operator-owned
#    privileged surface, so Settings / Agent Presets do not switch to memory mode.
RUN node --input-type=module <<'NODE'
import fs from "node:fs";
import path from "node:path";

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p));
    else if (entry.isFile() && p.endsWith(".ts")) out.push(p);
  }
  return out;
}

const connectionSrc = "/app/packages/client/connection/src";
let trustPatched = 0;
let originPatched = 0;

for (const file of walk(connectionSrc)) {
  let s = fs.readFileSync(file, "utf8");
  const old1 = "isTrustedApiRequest(request, [])";
  if (s.includes(old1)) {
    s = s.replaceAll(old1, "isTrustedApiRequest(request, trustedHosts)");
    trustPatched++;
  }

  const old2 = "new URL(origin).host === hostUrl.host";
  if (s.includes(old2)) {
    s = s.replaceAll(old2, "new URL(origin).hostname === hostUrl.hostname");
    originPatched++;
  }

  fs.writeFileSync(file, s);
}

// The remote UI currently derives the privileged Settings surface from
// ctx.connection.isLoopback. For this explicitly configured single-operator
// deployment, make that flag true in the browser bundle.
const clientIndex = "/app/packages/client/connection/src/client/index.ts";
let client = fs.readFileSync(clientIndex, "utf8");

const oldLoopback =
  "isLoopback: transport?.ownsHost === true || pageLocation === undefined || isLoopbackHostname(pageLocation.hostname),";
const newLoopback = "isLoopback: true,";

if (!client.includes(oldLoopback)) {
  throw new Error("Expected DeepSeek Harness client loopback expression was not found.");
}

client = client.replace(oldLoopback, newLoopback);
client = client.replace(
  "import { isLoopbackHostname } from '../loopback-hostname.ts'\n",
  ""
);
fs.writeFileSync(clientIndex, client);

// The current Settings UI also chooses host persistence only on loopback.
// Keep it on host persistence for this explicitly deployed operator UI.
const settingsIndex = "/app/packages/client/ui-settings/src/client/index.ts";
let settings = fs.readFileSync(settingsIndex, "utf8");

const oldPersistence =
  "const persistence = ctx.remote.$host.isLoopback ? 'host' : 'memory'";
const newPersistence = "const persistence = 'host'";

if (settings.includes(oldPersistence)) {
  settings = settings.replace(oldPersistence, newPersistence);
  fs.writeFileSync(settingsIndex, settings);
}

console.log({ trustPatched, originPatched, clientLoopbackPatched: true });
NODE

RUN pnpm install --frozen-lockfile
RUN pnpm run build

# Northflank exposes port 8080. Harness itself remains on loopback:3080.
RUN cat > /etc/nginx/conf.d/deepseek-harness.conf <<'NGINX'
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 8080;
    server_name _;

    auth_basic "DeepSeek Harness";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://127.0.0.1:3080;
        proxy_http_version 1.1;

        proxy_set_header Host $http_host;
        proxy_set_header Origin $http_origin;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Do not pass the proxy's Basic-Auth header into Harness.
        proxy_set_header Authorization "";

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
    }
}
NGINX

EXPOSE 8080

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
