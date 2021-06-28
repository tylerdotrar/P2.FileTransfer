import os, flask, argparse, configparser
from os import listdir
from flask import request, send_from_directory, session
from werkzeug.utils import secure_filename
from functools import wraps

config = configparser.ConfigParser()
config.read('./var/config.ini')
app = flask.Flask(__name__, static_url_path='')


# CONFIG.INI
app.secret_key = config.get('server','secret_key')
UPLOAD_EXTENSIONS = config.get('server','allowed_extensions')
CLIENT_DOWNLOADS = config.get('directories','download')
CLIENT_UPLOADS = config.get('directories','upload')
SERVER_USERNAME = config.get('credentials','username')
SERVER_PASSWORD = config.get('credentials','password')


# LOGIN FUNCTION
def login_required(f):
    @wraps(f)
    def wrap(*args, **kwargs):
        if 'logged_in' in session:
            return f(*args, **kwargs)
        else:
            return 'LOGIN REQUIRED'
    return wrap


# RAW CONTENT FUNCTION
def GetFileContents(path):
    with open(path, 'r', encoding='utf-8-sig') as f:
        clear = ''.join([line for line in f])
        return clear


# LOGIN PAGE
@app.route('/login', methods=['POST'])
def Login():
    if request.form['username'] == SERVER_USERNAME and request.form['password'] == SERVER_PASSWORD:
        session['logged_in'] = True
        return 'SUCCESSFUL LOGIN'
    else:
        return 'UNSUCCESSFUL LOGIN'


# LOGOUT PAGE
@app.route('/logout', methods=['GET'])
@login_required
def Logout():
    session.pop('logged_in', None)
    return 'SUCCESSFUL LOGOUT'


# AVAILABLE FILES
@app.route('/en-us/p2ft/master', methods=['GET'])
@login_required
def QueryFiles():
    return ' '.join(os.listdir(CLIENT_DOWNLOADS))


# FILE CONTENT
@app.route('/en-us/p2ft/read/<string:file_name>', methods=['GET'])
@login_required
def ShowContent(file_name):
    path = CLIENT_DOWNLOADS + '/' + file_name
    isFile = os.path.isfile(path)
    if isFile:
        try:
            file_content = GetFileContents(path)
            return file_content
        except:
            errormsg = 'NOT HUMAN READABLE'
            return errormsg
    return 'FILE NOT FOUND'


# FILE DOWNLOAD
@app.route('/en-us/p2ft/download/<string:file_name>', methods=['GET'])
@login_required
def DownloadFile(file_name):
    try:
        return send_from_directory(CLIENT_DOWNLOADS, filename=file_name, as_attachment=True)
    except FileNotFoundError:
        abort(404)


# FILE UPLOAD
@app.route('/en-us/p2ft/upload', methods=['POST'])
@login_required
def UploadFile():
    uploaded_file = request.files['TYLER.RAR']
    file_name = secure_filename(uploaded_file.filename)
    if file_name != '':
        file_ext = os.path.splitext(file_name)[1]
        if file_ext not in UPLOAD_EXTENSIONS:
            return 'FILE NOT ALLOWED'
        uploaded_file.save(os.path.join(CLIENT_UPLOADS, file_name))
        return 'SUCCESSFUL UPLOAD'
    return 'NULL FILENAME'


# PARAMETERS
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', default=54321, type=int)
    parser.add_argument('--ssl', action='store_const', const='adhoc', default=None)
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()

    app.run(host='0.0.0.0', port=args.port, ssl_context=args.ssl, debug=args.debug)
