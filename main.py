import http.server
import socketserver

class MyHttpRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Use the parent class's method to handle GET requests, which serves files based on self.path.
        return http.server.SimpleHTTPRequestHandler.do_GET(self)

def run_server(port=8000):
    with socketserver.TCPServer(("", port), MyHttpRequestHandler) as server:
        print(f"Serving at port {port}")
        server.serve_forever()

if __name__ == "__main__":
    run_server()
