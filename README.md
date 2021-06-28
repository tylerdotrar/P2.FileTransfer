# P2.FileTransfer
Python x PowerShell user-authentication based file transfer via Flask web server.

![Download](https://cdn.discordapp.com/attachments/855920119292362802/858977325164134420/unknown.png)

# Syntax
### Invoke-FileTransfer // p2ft
```powershell
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
        Input connection data or use credential file.

    []  PS C:\Users\Bobby> p2ft -u SuperCoolScript.ps1 https://192.168.2.69:54321 root password1
        File successfully uploaded.

    []  PS C:\Users\Bobby> Invoke-FileTransfer -Credentials
        ╔═════════════════╗
        ║ Credential File ║
        ╚═════════════════╝
        -- URL: https://192.168.2.69:54321
        -- Username: root
        -- Password: password1

        Save configuration? (yes/no): y
        Credential file generated.

    []  PS C:\Users\Bobby> p2ft -Credentials -Query
        ╔═════════════════╗
        ║ Available Files ║
        ╚═════════════════╝     
        -- coolkatz.zip
        -- passwords.txt
        -- ambiguous.png

    []  PS C:\Users\Bobby> Invoke-FileTransfer -Download -File coolkatz.zip -Credentials
        File successfully downloaded.
```
### Invoke-HybridServer // hybridserver
```powershell
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
### Downloading Files
### Running Server Entirely in Memory
![Memory](https://cdn.discordapp.com/attachments/855920119292362802/858978537644883985/unknown.png)
### Returning Raw File Content
![Read](https://cdn.discordapp.com/attachments/855920119292362802/858980280873385994/unknown.png)

