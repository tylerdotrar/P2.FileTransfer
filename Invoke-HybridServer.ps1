function Invoke-HybridServer {
#.SYNOPSIS
# Python x PowerShell user-authentication based file transfer via Flask web server (server-side).
# ARBITRARY VERSION NUMBER:  1.0.0
# AUTHOR:  Tyler McCann (@tyler.rar)
#
#.DESCRIPTION
# This script is designed to automate server usage -- starting, stopping, user credentials, port, protocol, etc.
# This server is meant to only communicate with the corresponding file transfer script (Invoke-FileTransfer),
# ignoring communications via a web browser.  This server will host files to be downloaded from the '/downloads'
# directory, and post uploaded files to the '/uploads' directory.
#
# It creates an entirely new PowerShell window for the server (supporting both Windows PowerShell and PowerShell 
# Core), allowing you to continue usage of your current terminal.  The script even has Windows Terminal support -- 
# meaning it detects if the terminal you are using is being used inside of Windows Terminal, and will create a new 
# tab, start the server, rename the tab to useful server information, and tab back to the previously used Window 
# (unless -Focus is used). Note: this functionality only works if PowerShell is your default Windows Terminal profile.
#
# Parameters:
#    [Script Configuration]
#    -Config        -->    Generate new 'hybrid_server.py' in $PSScriptRoot with desired user credentials
#    -Start         -->    Start the upload server (ONLY works if NO Python instance is open)
#    -Stop          -->    Stop the upload server (unreliable if more than one Python instance is open)
#    -Focus         -->    (Optional) Give new server window focus (instead of returning to current terminal)
#    -Help          -->    (Optional) Return Get-Help information
#
#    [Server Configuration]
#    -SSL           -->    (Optional) Use HTTPS
#    -IP            -->    (Optional) Change IP address (NOT recommended; only change to 127.0.0.1)
#    -Port          -->    (Optional) Change port (default is 54321)
#    -Debug         -->    (Optional) Enable debugger
#    -Server        -->    (Optional) Absolute path to 'hybrid_server.py'
#    
# Example Usage:
#    []  PS C:\Users\Bobby> Invoke-HybridServer -Config
#        [SERVER AUTHENTICATION
#        - Username: admin
#        - Password: password
#
#        'hybrid_server.py' generated.
#
#    []  PS C:\Users\Bobby> Hybrid-Server -SSL -Port 4444 -Start
#        Server started.
#
#.LINK
# https://github.com/tylerdotrar/P2.FileTransfer
    

    [Alias('Hybrid-Server')]

    Param (
        # Script
        [switch] $Config,
        [switch] $Start,
        [switch] $Stop,
        [switch] $Focus,
        [switch] $Help,
        
        # Server
        [switch] $SSL,
        [switch] $Debug,
        [string] $IP,
        [int]    $Port,

        [string] $Server = "$PSScriptRoot\hybrid_server.py"
    )


    function Server-Generation {
        
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

        Write-Host "[SERVER AUTHENTICATION]" -ForegroundColor Green
        Write-Host '- Username: ' -NoNewLine -ForegroundColor Yellow ; $ServerUsername = Read-Host
        Write-Host '- Password: ' -NoNewLine -ForegroundColor Yellow ; $ServerPassword = Read-Host


        $SessionKey = Server-RandomKeyGen
        [string]$ServerConfiguration = @"
import os, flask, argparse
from flask import request, send_from_directory, session
from werkzeug.utils import secure_filename
from functools import wraps

app = flask.Flask(__name__, static_url_path='')

app.secret_key = '$SessionKey'
app.config['SERVER_USERNAME'] = '$ServerUsername'
app.config['SERVER_PASSWORD'] = '$ServerPassword'

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
"@
        

        [System.IO.File]::WriteAllLines($Server, $ServerConfiguration)
        Write-Host "`n'hybrid_server.py' generated." -ForegroundColor Green
    }

    # Return Get-Help information
    if ($Help) { return Get-Help Invoke-HybridServer }

    # Create / Update 'hybrid_server.py'
    elseif ($Config) { Server-Generation ; return }

    # Failed to specify whether to start or stop server
    elseif (!$Start -and !$Stop) { return (Write-Host 'No action specified.' -ForegroundColor Red) }


    # Skip unnecessary code for stopping the server.
    if (!$Stop) {

        # Server location not properly specified
        if ( !(Test-Path -LiteralPath $Server) ) { 
            return (Write-Host 'Server does not exist.' -ForegroundColor Red)
        }


        # Determine if current PowerShell terminal is inside Windows Terminal
        if ( (((Get-Process -Name 'OpenConsole').StartTime) | ForEach-Object { [string]$_ } ) -Contains [string](Get-Process -ID $PID).StartTime 2>$NULL ) {

            # Create an ordered hashtable of Windows Terminal tabs (Main:PID or Arbitrary:PID)
            $WindowContext = [ordered]@{}
            $OpenWindows = (Get-Process -Name 'OpenConsole') | Sort-Object -Property StartTime
            $Inc = 1
        
            foreach ($WinTerm in $OpenWindows) {

                if ( ($WinTerm).StartTime -match (Get-Process -ID $PID).StartTime ) {
                    $WindowContext += @{'Main' = $WinTerm.ID}
                }
                else { $WindowContext += @{"Arbitrary$Inc" = $WinTerm.ID} ; $Inc++ }

            }


            # Get Index Number of Current Windows Terminal Session
            if ($WindowContext.count -eq 1) { $MainWindow = 1 }
            else { $MainWindow = $($WindowContext.Keys).IndexOf('Main') + 1 }

            $UsingWindowsTerminal = $TRUE
        }


        # Determine PowerShell Version to use for the server
        else {
            
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
            if ($SSL) { $Title = 'HTTPS Server' }
            else { $Title = 'HTTP Server' }


            if ($Port) { $Title += " : $Port" }
            else { $Title += ' : 54321' }


            $Commands = "`$Host.UI.RawUI.WindowTitle = '$Title'; Set-Location -LiteralPath $ServerFolder; Clear-Host; python $Server"

            if ($SSL)   { $Commands += " --ssl" }
            if ($Debug) { $Commands += " --debug" }
            if ($IP)    { $Commands += " --ip $IP" }
            if ($Port)  { $Commands += " --port $Port" }

            $Commands += "; exit"
        }

        # Configure Optional Server Parameters (Windows PowerShell)
        else {
        
            # Determine server WindowStyle
            if ($Focus) { $Window = 'Normal' }
            else { $Window = 'Minimized' }

            $Commands = "-WindowStyle $Window", "-Command Set-Location -LiteralPath $ServerFolder ; python $Server"

            if ($SSL) { $Commands[-1] += " --ssl" }
            if ($Debug) { $Commands[-1] += " --debug" }
            if ($IP) { $Commands[-1] += " --ip $IP" }
            if ($Port) { $Commands[-1] += " --port $Port" }
        }
    }
  

    # Determine if server is already running (NOT ACCURATE)
    $Running = Get-Process -Name python* 2>$NULL


    # Start server
    if ($Start) {

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
                if (!$Focus) {
                    $WindowsTerminalHack.SendKeys("^%$MainWindow")
                }
            }

            # Open new PowerShell session
            else { Start-Process -FilePath $PowerShell -ArgumentList $Commands }

            Write-Host 'Server started.' -ForegroundColor Green
        }

        else { Write-Host 'Server is already running.' -ForegroundColor Green }
    }


    # Stop server
    elseif ($Stop) {

        if ($Running) {
            Stop-Process -Name python*
            Write-Host 'Server stopped.' -ForegroundColor Red
        }

        else { Write-Host 'Server is already stopped.' -ForegroundColor Red }
    }
}