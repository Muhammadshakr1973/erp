const http = require('http');
const port = 3000;
const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end(`
    <!DOCTYPE html>
    <html lang="ku" dir="rtl">
    <head>
      <meta charset="UTF-8">
      <title>Gardi POS - Flutter/Laravel</title>
      <style>
        body { font-family: Tahoma, Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f7f9fd; color: #122d5a; text-align: center; }
        .card { background: white; padding: 2rem; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>ئەمە پڕۆژەیەکی فڵەتەر و لاراڤێلە</h1>
        <p>بۆ بینینی ئەپەکە تکایە کۆدەکان لە کۆمپیوتەرەکەی خۆت ڕەن بکە.</p>
        <p>دەتوانیت لە ڕێگەی GitHub ەوە کۆدەکان وەربگریت.</p>
      </div>
    </body>
    </html>
  `);
});
server.listen(port, () => {
  console.log(`Server running at port ${port}`);
});
