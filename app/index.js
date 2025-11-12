// app/index.js
const http = require('http');
const port = process.env.PORT || 3000;
const appVersion = process.env.APP_VERSION || 'v1.0.0';
const environment = process.env.ENVIRONMENT || 'unknown';

// prometheus client
const client = require('prom-client');
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ timeout: 5000 });

// custom counter example
const hits = new client.Counter({
  name: 'multi_env_app_hits_total',
  help: 'Total HTTP requests served by the multi-env app'
});

const server = http.createServer((req, res) => {
  if (req.url === '/metrics') {
    res.writeHead(200, { 'Content-Type': client.register.contentType });
    res.end(client.register.metrics());
    return;
  }

  // increment hits metric
  hits.inc();

  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end(`Hello from Multi-Environment App - ${appVersion}\nEnvironment: ${environment}\n`);
});

server.listen(port, () => {
  console.log(`Server running at port ${port}`);
});

