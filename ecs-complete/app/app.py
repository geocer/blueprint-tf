# app.py
from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Hello, Buildpacks!'

if __name__ == '__main__':
    # O Gunicorn (que o Buildpack configura) irá iniciar o aplicativo.
    # Esta linha é mais para testar localmente ou como fallback.
    app.run(debug=True, host='0.0.0.0', port=8080)