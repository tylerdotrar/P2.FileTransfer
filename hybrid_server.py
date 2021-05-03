import os, flask, argparse
from flask import request, send_from_directory, session
from werkzeug.utils import secure_filename
from functools import wraps

app = flask.Flask(__name__, static_url_path='')

app.secret_key = '<example>'
app.config['SERVER_USERNAME'] = '<admin>'
app.config['SERVER_PASSWORD'] = '<password>'

app.config['CLIENT_DOWNLOADS'] = './downloads'
app.config['CLIENT_UPLOADS'] = './uploads'
app.config['UPLOAD_EXTENSIONS'] = ['.jpg','.png','.pdf','.txt','.zip','.ps1']


# REQUIRE LOGIN
def login_required(f):
    @wraps(f)
    def wrap(*args, **kwargs):
        if 'logged_in' in session:
            return f(*args, **kwargs)
        else:
            return 'LOGIN REQUIRED'
    return wrap


# FILE DOWNLOAD
@app.route('/en-us/p2ft/download/<string:file_name>', methods=['GET'])
@login_required
def download_file(file_name):
    try:
        return send_from_directory(app.config['CLIENT_DOWNLOADS'], filename=file_name, as_attachment=True)
    except FileNotFoundError:
        abort(404)


# FILE UPLOAD
@app.route('/en-us/p2ft/upload', methods=['GET','POST'])
@login_required
def upload_file():
    if request.method == 'POST':
        uploaded_file = request.files['TYLER.RAR']
        file_name = secure_filename(uploaded_file.filename)
        if file_name != '':
            file_ext = os.path.splitext(file_name)[1]
            if file_ext not in app.config['UPLOAD_EXTENSIONS']:
                return 'FILETYPE NOT ALLOWED'
            uploaded_file.save(os.path.join(app.config['CLIENT_UPLOADS'], file_name))
            return 'SUCCESSFUL UPLOAD'
        return 'FILENAME NULL'
    return 'UPLOAD ONLY'


# LOGIN PAGE
@app.route('/login', methods=['GET','POST'])
def login():
    if request.method == 'POST': #LoginPost
        if request.form['username'] == app.config['SERVER_USERNAME'] and request.form['password'] == app.config['SERVER_PASSWORD']:
            session['logged_in'] = True
            return 'SUCCESSFUL LOGIN'
        else:
            return 'UNSUCCESSFUL LOGIN'
    return 'LOGIN ONLY'


# LOGOUT PAGE
@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return 'SUCCESSFUL LOGOUT'


# PARAMETERS
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--ip', default='0.0.0.0')
    parser.add_argument('--port', default=54321, type=int)
    parser.add_argument('--debug', action='store_true')
    parser.add_argument('--ssl', action='store_const', const='adhoc', default=None)
    args = parser.parse_args()

    app.run(host=args.ip, port=args.port, ssl_context=args.ssl, debug=args.debug)
