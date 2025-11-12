const http = require('http');
const port = process.env.PORT || 3000;
const appVersion = process.env.APP_VERSION || 'v1.0.0';
const environment = process.env.ENVIRONMENT || 'unknown';

// Try loading prom-client safely
let promClient;
try {
  promClient = require('prom-client');
} catch (err) {
  console.log('⚠️ Prometheus metrics module not installed. Skipping metrics setup.');
}

// Optional metrics setup
let collectDefaultMetrics;
if (promClient) {
  collectDefaultMetrics = promClient.collectDefaultMetrics;
  collectDefaultMetrics();
}

const server = http.createServer((req, res) => {
  if (promClient && req.url === '/metrics') {
    res.writeHead(200, { 'Content-Type': promClient.register.contentType });
    res.end(promClient.register.metrics());
  } else {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(`Hello from Multi-Environment App - ${appVersion}\nEnvironment: ${environment}\n`);
  }
});

server.listen(port, () => {
  console.log(`Server running at port ${port}`);
});

