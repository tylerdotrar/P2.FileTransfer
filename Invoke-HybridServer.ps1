function Invoke-HybridServer {
#.SYNOPSIS
# Python x PowerShell based file transfer via user-authentication based Flask web server.
# ARBITRARY VERSION NUMBER:  2.0.0
# AUTHOR:  Tyler McCann (@tyler.rar)
#
#.DESCRIPTION
# This script is designed to automate flask server usage -- starting, stopping, modification, arguments, etc.
# The server is only meant to communicate with the corresponding file transfer script (Invoke-FileTransfer),
# ignoring communications via a web browser.  The server is ran in an entirely new terminal, allowing the user
# to remain in their current session.  This script also supports Windows Terminal -- launching the server in 
# new tabs and renaming the tab to the protocol and port being used for said server, before tabbing back to
# the previously used window (unless -Focus is used).
#
# -- Windows Terminal support only works if PowerShell is the default profile.
# -- Supports Windows PowerShell and PowerShell Core.
# -- Supports file-less 'portable' execution.
#
# Parameters:
#    -Config        -->    Configure and generate new server settings
#    -Start         -->    Start server instance
#    -Stop          -->    Stop currently running server instance
#    -Portable      -->    Run server entirely from memory in current directory; no file required
#    -Server        -->    Path to 'hybrid_server.py' (default: $PSScriptRoot\hybrid_server.py)
#
#    -SSL           -->    Use HTTPS
#    -Port          -->    Change port (default: 54321)
#    -Debug         -->    Enable debugger (not supported in portable mode)
#    -Focus         -->    Give new server window focus (instead of returning to current terminal)
#
#    -Help          -->    Return help information
#    
# Example Usage:
#    []  PS C:\Users\Bobby> Invoke-HybridServer -Config
#        ╔══════════════════════╗
#        ║ Server Configuration ║
#        ╚══════════════════════╝
#        -- Username: admin
#        -- Password: password
#        -- Upload Folder: ./uploads
#        -- Download Folder: ./downloads
#
#        Save configuration? (yes/no): y
#        Server configuration updated.
#
#    []  PS C:\Users\Bobby> hybridserver -SSL -Port 4444 -Start
#        Server started.
#
#.LINK
# https://github.com/tylerdotrar/P2.FileTransfer
    
    [Alias('hybridserver')]

    Param (
        [switch] $Config,
        [switch] $Portable,
        [switch] $Start,
        [switch] $Stop,
        [switch] $Focus,
        [switch] $SSL,
        [int]    $Port,
        [switch] $Debug,
        [switch] $Help,
        [string] $Server = "$PSScriptRoot\hybrid_server.py"
    )


    function Server-Generation ([switch]$Portable) {
        
        function Server-RandomKeyGen ([int]$Length = 20) {

            #Characters and their corresponding ASCII values
            $Numbers = 48..57
            $Uppercase = 65..90
            $Lowercase = 97..122
            $SpecialCharacters = 60..64 + 91 + 93..94 + 123..125
            $CharArray = $Numbers + $Uppercase + $Lowercase + $SpecialCharacters

            $SessionKey = $NULL
            for ($i=0; $i -lt $Length; $i++) {
                $Num = Get-Random $CharArray
                $Char = [char]$Num
                $SessionKey += $Char
            }

            return $SessionKey
        }

        # Prompt User for Configuration Settings
        while ($True) {
            
            Write-Host "╔══════════════════════╗`n║" -NoNewline
            Write-Host ' Server Configuration ' -NoNewline -ForegroundColor Yellow
            Write-Host "║`n╚══════════════════════╝"
            Write-Host '-- ' -NoNewLine ; Write-Host 'Username: ' -NoNewLine -ForegroundColor Yellow        ; $ServerUsername = Read-Host
            Write-Host '-- ' -NoNewLine ; Write-Host 'Password: ' -NoNewLine -ForegroundColor Yellow        ; $ServerPassword = Read-Host
            Write-Host '-- ' -NoNewLine ; Write-Host 'Upload Folder: ' -NoNewline -ForegroundColor Yellow   ; $UploadFolder   = Read-Host
            Write-Host '-- ' -NoNewLine ; Write-Host 'Download Folder: ' -NoNewline -ForegroundColor Yellow ; $DownloadFolder = Read-Host
            Write-Host "`nSave configuration? (yes/no): " -NoNewLine -ForegroundColor Yellow                ; $SaveConfig     = Read-Host

            if (($SaveConfig -eq 'y') -or ($SaveConfig -eq 'yes')) { break }
            else { Clear-Host ; Write-Host "PS $PWD>" }
        }

        $SessionKey = Server-RandomKeyGen
        

        # Added functionality to run a flask server entirely from memory
        if ($Portable) {
            
            if ($SSL)  { $SSLarg   = " ssl_context='adhoc'," }
            if ($Port) { $PortArg  = $Port   }
            else       { $PortArg  = '54321' }

            $ServerContents = @"
def hybrid_server():
  import os, flask
  from os import listdir
  from flask import request, send_from_directory, session
  from werkzeug.utils import secure_filename
  from functools import wraps
  app = flask.Flask(__name__, static_url_path='')
  app.secret_key = '$SessionKey'
  SERVER_USERNAME = '$ServerUsername'
  SERVER_PASSWORD = '$ServerPassword'
  CLIENT_DOWNLOADS = '$DownloadFolder'
  CLIENT_UPLOADS = '$UploadFolder'
  UPLOAD_EXTENSIONS = [
      '.jpg', '.jpeg', '.png', '.gif', '.zip', '.rar',
      '.7z', '.gzip', '.csv', '.txt', '.json', '.xml',
      '.pdf', '.mp4', '.mkv', '.ps1', '.psm1', '.py'
  ]
  def login_required(f):
      @wraps(f)
      def wrap(*args, **kwargs):
          if 'logged_in' in session:
              return f(*args, **kwargs)
          else:
              return 'LOGIN REQUIRED'
      return wrap
  def getFileContents(path):
      with open(path, 'r', encoding='utf-8-sig') as f:
          clear = ''.join([line for line in f])
          return clear
  @app.route('/login', methods=['POST'])
  def Login():
      if request.form['username'] == SERVER_USERNAME and request.form['password'] == SERVER_PASSWORD:
          session['logged_in'] = True
          return 'SUCCESSFUL LOGIN'
      else:
          return 'UNSUCCESSFUL LOGIN'
  @app.route('/logout', methods=['GET'])
  @login_required
  def Logout():
      session.pop('logged_in', None)
      return 'SUCCESSFUL LOGOUT'
  @app.route('/en-us/p2ft/master', methods=['GET'])
  @login_required
  def QueryFiles():
      return ' '.join(os.listdir(CLIENT_DOWNLOADS))
  @app.route('/en-us/p2ft/read/<string:file_name>', methods=['GET'])
  @login_required
  def ShowContent(file_name):
      path = CLIENT_DOWNLOADS + '/' + file_name
      isFile = os.path.isfile(path)
      if isFile:
          try:
              file_content = getFileContents(path)
              return file_content
          except:
              errormsg = 'NOT HUMAN READABLE'
              return errormsg
      return 'FILE NOT FOUND'
  @app.route('/en-us/p2ft/download/<string:file_name>', methods=['GET'])
  @login_required
  def DownloadFile(file_name):
      try:
          return send_from_directory(CLIENT_DOWNLOADS, filename=file_name, as_attachment=True)
      except FileNotFoundError:
          abort(404)
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
  if __name__ == '__main__':
      app.run(host='0.0.0.0', port=$PortArg,$SSLarg debug=False)
	  
hybrid_server()
"@
            
            $Line = '───────────────────────────────────'
            Write-Host "`n$Line Flask Server $Line" -ForegroundColor Yellow

            $ServerContents | python
            return
        }
        
        # Create Server File if it Doesn't Exist
        if (!(Test-Path -LiteralPath $Server)) {
            
            $ServerContent = @"
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
"@

            [System.IO.File]::WriteAllLines($Server, $ServerContent)
            Write-Host "New 'hybrid_server.py' generated." -ForegroundColor Green
        }

        # Update / Create Config File
        $ConfigContent = @"
[server]
secret_key = $SessionKey
allowed_extensions = [
	".jpg",
	".jpeg",
	".png",
	".gif",
	".zip",
	".rar",
	".7z",
	".gzip",
	".csv",
	".txt",
	".json",
	".xml",
	".pdf",
	".mp4",
	".mkv",
	".ps1",
	".psm1"
	".py",
	".iso",
	".dll",
	".exe"
	]

[directories]
upload = $UploadFolder
download = $DownloadFolder

[credentials]
username = $ServerUsername
password = $ServerPassword
"@
        
        $ConfigFile = $Server.Replace($Server.Split('\')[-1],'var\config.ini')
        New-Item -Path $ConfigFile -Value $ConfigContent -Force | Out-Null
        Write-Host 'Server configuration updated.' -ForegroundColor Green 
    }
    function Start-Server {
        
        function WindowsTerminal-Detection {

            # Determine if current PowerShell terminal is inside Windows Terminal
            if ( (((Get-Process -Name 'OpenConsole').StartTime) | ForEach-Object { [string]$_ } ) -Contains [string](Get-Process -ID $PID).StartTime 2>$NULL ) {

                # Create an ordered hashtable of Windows Terminal tabs (Main:PID or Arbitrary:PID)
                $WindowContext = [ordered]@{}
                $OpenWindows = (Get-Process -Name 'OpenConsole') | Sort-Object -Property StartTime
                $Inc = 1
        
                foreach ($WinTerm in $OpenWindows) {

                    if ( ($WinTerm).StartTime -match (Get-Process -ID $PID).StartTime ) { $WindowContext += @{'Main' = $WinTerm.ID} }
                    else { $WindowContext += @{"Arbitrary$Inc" = $WinTerm.ID} ; $Inc++ }
                }

                # Get Index Number of Current Windows Terminal Session
                if ($WindowContext.count -eq 1) { $MainWindow = 1 }
                else { $MainWindow = $($WindowContext.Keys).IndexOf('Main') + 1 }

                return $TRUE, $MainWindow
            }
        }

        # Server location not properly specified
        if ( !(Test-Path -LiteralPath $Server) ) { return (Write-Host 'Server does not exist.' -ForegroundColor Red) }

        # Determine if current PowerShell terminal is inside Windows Terminal & Create Terminal Array
        $UsingWindowsTerminal, $MainWindow = WindowsTerminal-Detection

        if (!$UsingWindowsTerminal) {
            if ($PSEdition -eq 'Core') { $PowerShell = 'pwsh' }
            else { $PowerShell = 'powershell' }    
        }
        
        # Create 'uploads' / 'downloads' directories if they don't already exist
        $ServerFolder    = $Server.Replace($Server.Split('\')[-1],$NULL)

        $UploadsFolder   = $ServerFolder + 'uploads'
        $DownloadsFolder = $ServerFolder + 'downloads'

        if (!(Test-Path -LiteralPath $UploadsFolder))   { New-Item -ItemType Directory -Path $UploadsFolder   | Out-Null }
        if (!(Test-Path -LiteralPath $DownloadsFolder)) { New-Item -ItemType Directory -Path $DownloadsFolder | Out-Null }
        

    
        # Configure Optional Server Parameters (Windows Terminal)
        if ($UsingWindowsTerminal) {

            # Windows Terminal server tab title
            if ($SSL)  { $Title = 'HTTPS Server' }
            else       { $Title = 'HTTP Server'  }

            if ($Port) { $Title += " : $Port" }
            else       { $Title += ' : 54321' }

            $Commands = "`$Host.UI.RawUI.WindowTitle = '$Title'; Set-Location -LiteralPath $ServerFolder; Get-Date | Export-Clixml -LiteralPath $InstanceFile; Clear-Host; python $Server"

            if ($SSL)   { $Commands += ' --ssl'        }
            if ($Port)  { $Commands += " --port $Port" }
            if ($Debug) { $Commands += ' --debug'      }

            $Commands += '; exit'
        }

        # Configure Optional Server Parameters (Windows PowerShell)
        else {
        
            # Determine server WindowStyle
            if ($Focus) { $Window = 'Normal'    }
            else        { $Window = 'Minimized' }

            $Commands = "-WindowStyle $Window", "-Command Set-Location -LiteralPath $ServerFolder ; python $Server"

            if ($SSL)   { $Commands[-1] += ' --ssl'        }
            if ($Port)  { $Commands[-1] += " --port $Port" }
            if ($Debug) { $Commands[-1] += ' --debug'      }
        }


        if (!$Running) {
            
            # Create a new Windows Terminal window
            if ($UsingWindowsTerminal) {
                
                # Initialize Wscript ComObject to send Keystrokes to Applications
                $WindowsTerminalHack = New-Object -ComObject Wscript.Shell

                # Create new tab (Send CTRL + SHIFT + T to current window)
                $WindowsTerminalHack.SendKeys('^+t')
                Start-Sleep -Milliseconds 250

                # Send commands to title the Window and start the server
                $WindowsTerminalHack.SendKeys("$Commands{ENTER}")

                # Return to original tab (Send CTRL + ALT + Index Number to current window)
                if (!$Focus) { $WindowsTerminalHack.SendKeys("^%$MainWindow") }
            }

            # Open new PowerShell session, export process instance to 'server_instance.xml'
            else { Start-Process -FilePath $PowerShell -ArgumentList $Commands -PassThru | Export-Clixml -LiteralPath $InstanceFile }

            Write-Host 'Server started.' -ForegroundColor Green
        }

        else { Write-Host 'Server is already running.' -ForegroundColor Green }
    }
    function Stop-Server {

        if ($Running) {
            Stop-Process $ServerInstance
            Remove-Item -LiteralPath $InstanceFile -Force
            Write-Host 'Server stopped.' -ForegroundColor Red
        }

        else { Write-Host 'Server is already stopped.' -ForegroundColor Red }
    }


    # Get-Help, Server Creation, and Usage Correction
    if ($Config)                                          { return Server-Generation            }
    elseif ($Help)                                        { return Get-Help Invoke-HybridServer }
    elseif (!$Start -and !$Stop -and !$Portable)          { return (Write-Host 'No action specified.' -ForegroundColor Red)      }
    if ($Port -and (($Port -le 0) -or ($Port -gt 65535))) { return (Write-Host 'Port number out of range.' -ForegroundColor Red) }
  

    # Determine if server is already running via the 'server_instance.xml' file
    $Server = (Get-Item -LiteralPath $Server).FullName
    $InstanceFile = $Server.Replace($Server.Split('\')[-1],'var\server_instance.xml')

    if (Test-Path -LiteralPath $InstanceFile) {
            
        $RunningObject = Import-Clixml -LiteralPath $InstanceFile

        if ($RunningObject -is [DateTime]) { $ServerInstance = Get-Process -Name python* | ? { $_.StartTime -match $RunningObject } }
        else                               { $ServerInstance = ($RunningObject | Get-Process) }
        
        if ($ServerInstance) { $Running = $TRUE }
        else                 { Remove-Item -LiteralPath $InstanceFile }
    }


    # Main Functionality
    if ($Start)        { Start-Server }
    elseif ($Stop)     { Stop-Server  }
    elseif ($Portable) { Server-Generation -Portable }
}