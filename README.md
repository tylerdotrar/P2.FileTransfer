# P2.FileTransfer
Python x PowerShell user-authentication based file transfer via Flask web server.

![Download](https://cdn.discordapp.com/attachments/855920119292362802/858977325164134420/unknown.png)

# Overview & Syntax
### Invoke-FileTransfer /-/ p2ft
```powershell
Description:
   This script is designed to transfer files (upload, download, and read) to/from a custom Python-based flask web 
   server, supporting both HTTP and HTTPS protocols (essentially a rudimentary C2 server).  The Python web server
   should only accept files sent from this script due to a modified Content-Disposition header.  Communications
   will only work if the user inputs the authorized credentials for the web server.  If PowerShell Core is used, 
   file MIME types are determined based off of a hard-coded list of file extensions.  If Windows PowerShell is
   used, MIME types are automatically determined based off of file content.

   -- Alternate data streams (ADS) are NOT supported.
   -- Supports Windows PowerShell and PowerShell Core.
   -- Downloads have progress bars.
   -- Credential file supports 'back' input.

Parameters:
   -File          -->   File to upload/download/read

   -Credentials   -->   Create credential file or use stored credentials
   -URL           -->   URL of the web server [ http(s)://<ip>:<port> ]
   -Username      -->   Username to authenticate with server
   -Password      -->   Password of authenticated user

   -Query         -->   Return list of all files currently being hosted
   -Upload        -->   Upload a file to the web server
   -Download      -->   Download a file from the web server
   -Content       -->   Return raw text from file
    
   -Help          -->   Return help information
    
Example Usage:
   []  PS C:\Users\Bobby> Invoke-FileTransfer -Query -URL https://192.168.2.69:54321
       Input connection data.

   []  PS C:\Users\Bobby> p2ft -u SuperCoolScript.ps1 https://192.168.2.69:54321 root password123
       File successfully uploaded.

   []  PS C:\Users\Bobby> Invoke-FileTransfer -Credentials
       ╔═════════════════╗
       ║ Credential File ║
       ╚═════════════════╝
       -- URL: https://192.168.2.69:54321
       -- Username: root
       -- Password: password123

       Save configuration? (yes/no): y
       Credential file generated.

   []  PS C:\Users\Bobby> p2ft -Query -Credentials 
       ╔═════════════════╗
       ║ Available Files ║
       ╚═════════════════╝     
       -- coolkatz.zip
       -- passwords.txt
       -- ambiguous.png

   []  PS C:\Users\Bobby> Invoke-FileTransfer -Download -File coolkatz.zip -Credentials
       File successfully downloaded.
```
### Invoke-HybridServer /-/ hybridserver
```powershell
Description:
   This script is designed to automate flask server usage -- starting, stopping, modification, arguments, etc.
   The server is only meant to communicate with the corresponding file transfer script (Invoke-FileTransfer),
   ignoring communications via a web browser.  The server is ran in an entirely new terminal, allowing the user
   to remain in their current session.  This script also supports Windows Terminal -- launching the server in 
   new tabs and renaming the tab to the protocol and port being used for said server, before tabbing back to
   the previously used window (unless -Focus is used).

   -- Windows Terminal support only works if PowerShell is the default profile.
   -- Supports Windows PowerShell and PowerShell Core.
   -- Supports file-less 'portable' execution.

Parameters:
   -Config        -->    Configure and generate new server settings
   -Start         -->    Start server instance
   -Stop          -->    Stop currently running server instance
   -Portable      -->    Run server entirely from memory in current directory; no file required
   -Server        -->    Path to 'hybrid_server.py' (default: $PSScriptRoot\hybrid_server.py)

   -SSL           -->    Use HTTPS
   -Port          -->    Change port (default: 54321)
   -Debug         -->    Enable debugger (not supported in portable mode)
   -Focus         -->    Give new server window focus (instead of returning to current terminal)

   -Help          -->    Return help information
    
Example Usage:
   []  PS C:\Users\Bobby> Invoke-HybridServer -Config
       ╔══════════════════════╗
       ║ Server Configuration ║
       ╚══════════════════════╝
       -- Username: admin
       -- Password: password
       -- Upload Folder: ./uploads
       -- Download Folder: ./downloads

       Save configuration? (yes/no): y
       Server configuration updated.

   []  PS C:\Users\Bobby> hybridserver -SSL -Port 4444 -Start
       Server started.
```

# Screenshots
### Querying List of Available Files
![Query](https://cdn.discordapp.com/attachments/855920119292362802/858975665662590986/unknown.png)
### Running Server Entirely in Memory
![Memory](https://cdn.discordapp.com/attachments/855920119292362802/858978537644883985/unknown.png)
### Returning Raw File Content
![Read](https://cdn.discordapp.com/attachments/855920119292362802/858980280873385994/unknown.png)

