// Importing required modules
const express = require('express');
const app = express();
const hostname = '127.0.0.1';
const port = 3000;

// Middleware to handle requests and responses
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Define a route that responds with "Hello World"
app.get('/', (req, res) => {
    res.send('Hello World
');
});

// Start the server
const server = app.listen(port, hostname, () => {
    console.log(`Server running at http://${hostname}:${port}/`);
});
