const express = require('express');
const client = require('prom-client');

const app = express();
const register = new client.Registry();
client.collectDefaultMetrics({ register });

app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/health', (req, res) => {
  res.json({
    status: "healthy",
    pod: process.env.POD_NAME || "",
    greeting: process.env.GREETING || "Default Greeting"
  });
});

app.listen(8080, () => console.log('App listening on port 8080'));