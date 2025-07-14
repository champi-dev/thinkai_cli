const express = require('express');
const app = express();
const path = require('path');

// Serve static files from /public directory
app.use(express.static(path.join(__dirname, 'public')));

// Serve a "Hello World" message at /
app.get('/', (req, res) => {
  res.send('<h1>Hello World</h1>');
});

// Serve an HTML file with CSS at /index.html
const htmlPath = path.resolve(__dirname, 'public', 'index.html');
app.get('/index.html', (req, res) => {
  res.sendFile(htmlPath);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
