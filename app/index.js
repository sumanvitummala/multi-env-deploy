const http = require('http');
const port = process.env.PORT || 3000;
const appVersion = process.env.APP_VERSION || 'v1.0.0';
const environment = process.env.ENVIRONMENT || 'unknown';

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end(`Hello from Multi-Environment App - ${appVersion}\nEnvironment: ${environment}\n`);
});

server.listen(port, () => {
  console.log(`Server running at port ${port}`);
});

