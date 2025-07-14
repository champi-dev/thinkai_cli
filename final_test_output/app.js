// Importing the required modules
const http = require('http');

// Setting up the server
const hostname = '127.0.0.1';
const port = 3000;

// Create an HTTP server that listens on a specified address and port.
const server = http.createServer((req, res) => {
    // Send a response to the client's request
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain');
    res.end('Hello World
');
});

// Listening for requests on the specified hostname and port
server.listen(port, hostname, () => {
    console.log(`Server running at http://${hostname}:${port}/`);
});
