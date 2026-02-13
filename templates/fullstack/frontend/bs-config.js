// Browser-sync configuration with API proxy
const http = require("http");

function createProxy(route) {
  return {
    route: route,
    handle: function (req, res) {
      // browser-sync strips the route prefix, so we need to add it back
      const fullPath = route + req.url;
      const options = {
        hostname: "localhost",
        port: 3000,
        path: fullPath,
        method: req.method,
        headers: req.headers,
      };
      const proxy = http.request(options, (proxyRes) => {
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(res);
      });
      proxy.on("error", (err) => {
        res.writeHead(502);
        res.end("Proxy error: " + err.message);
      });
      req.pipe(proxy);
    },
  };
}

module.exports = {
  server: {
    baseDir: "dist",
    middleware: [
      createProxy("/api"),
    ],
  },
  files: ["dist/**/*"],
  port: 3001,
  open: false,
};
