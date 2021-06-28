function Invoke-FileTransfer {
#.SYNOPSIS
# Python x PowerShell based file transfer via user-authentication based Flask web server.
# ARBITRARY VERSION NUMBER:  2.0.0
# AUTHOR:  Tyler McCann (@tyler.rar)
#
#.DESCRIPTION
# This script is designed to transfer files (upload, download, and read) to/from a custom Python-based flask web 
# server, supporting both HTTP and HTTPS protocols (essentially a rudimentary C2 server).  The Python web server
# should only accept files sent from this script due to a modified Content-Disposition header.  Communications
# will only work if the user inputs the authorized credentials for the web server.  If PowerShell Core is used, 
# file MIME types are determined based off of a hard-coded list of file extensions.  If Windows PowerShell is
# used, MIME types are automatically determined based off of file content.
#
# -- Alternate data streams (ADS) are NOT supported.
# -- Supports Windows PowerShell and PowerShell Core.
# -- Downloads have progress bars.
#
# Parameters:
#    -File          -->   File to upload/download/read
#
#    -Credentials   -->   Create credential file or use stored credentials
#    -URL           -->   URL of the web server [ http(s)://<ip>:<port> ]
#    -Username      -->   Username to authenticate with server
#    -Password      -->   Password of authenticated user
#
#    -Query         -->   Return list of all files currently being hosted
#    -Upload        -->   Upload a file to the web server
#    -Download      -->   Download a file from the web server
#    -Content       -->   Return raw text from file
#    
#    -Help          -->   Return help information
#    
# Example Usage:
#    []  PS C:\Users\Bobby> Invoke-FileTransfer -Query -URL https://192.168.2.69:54321
#        Input connection data or use credential file.
#
#    []  PS C:\Users\Bobby> p2ft -u SuperCoolScript.ps1 https://192.168.2.69:54321 root password1
#        File successfully uploaded.
#
#    []  PS C:\Users\Bobby> Invoke-FileTransfer -Credentials
#        ╔═════════════════╗
#        ║ Credential File ║
#        ╚═════════════════╝
#        -- URL: https://192.168.2.69:54321
#        -- Username: root
#        -- Password: password1
#
#        Save configuration? (yes/no): y
#        Credential file generated.
#
#    []  PS C:\Users\Bobby> p2ft -Credentials -Query
#        ╔═════════════════╗
#        ║ Available Files ║
#        ╚═════════════════╝     
#        -- coolkatz.zip
#        -- passwords.txt
#        -- ambiguous.png
#
#    []  PS C:\Users\Bobby> Invoke-FileTransfer -Download -File coolkatz.zip -Credentials
#        File successfully downloaded.
#
#.LINK
# https://github.com/tylerdotrar/P2.FileTransfer

    [Alias('p2ft')]

    Param (
        [string] $File,
        [switch] $Credentials,
        [string] $URL,
        [string] $Username,
        [string] $Password,
        [switch] $Upload,
        [switch] $Download,
        [switch] $Query,
        [switch] $Content,
        [switch] $Help
    )

    function Server-Credentials ([switch]$Generate,[switch]$Retrieve) {
        
        function Base64 ([switch]$Encode,[switch]$Decode,[string]$Message) {
    
            if ($Encode)     { $Output = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($Message))    }
            elseif ($Decode) { $Output = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($Message)) }

            return $Output
        }
        
        # Return Credentials Stored in 'Credentials.json'
        if ($Retrieve) {
        
                $EncodedCreds   = Get-Content $CredentialFile | ConvertFrom-Json

                $URL            = Base64 -Decode $EncodedCreds.url
                $Username       = Base64 -Decode $EncodedCreds.username
                $Password       = Base64 -Decode $EncodedCreds.password

                return @{url=$URL; username=$Username; password=$Password}
        }

        # Create Credentials File
        if ($Generate) {

            # URL Validation Regex
            $IPRegex     = '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}'
            $PortRegex   = '((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([0-5]{0,5})|([0-9]{1,4}))'
            $RegexString = '^http[s]?://' + $IPRegex + ':' + $PortRegex + '$'
    
            while ($TRUE) {
        
                Clear-Host
                Write-Host "PS $PWD>"

                Write-Host "╔═════════════════╗`n║" -NoNewline
                Write-Host ' Credential File ' -NoNewline -ForegroundColor Yellow
                Write-Host "║`n╚═════════════════╝"

                # Convoluted Logic to Allow for 'back' Functionality
                Write-Host '-- ' -NoNewline
                Write-Host 'URL: ' -NoNewline -ForegroundColor Yellow

                if ($URL)      {
                    Write-Host $URL
                    Write-Host '-- ' -NoNewline
                    Write-Host 'Username: ' -NoNewline -ForegroundColor Yellow
                }
                if ($Username) {
                    Write-Host $Username
                    Write-Host '-- ' -NoNewline
                    Write-Host 'Password: ' -NoNewline -ForegroundColor Yellow

                }
                if ($Password) {
                    Write-Host $Password
                    Write-Host "`nSave configuration? (yes/no): " -NoNewLine -ForegroundColor Yellow
                }

                # Save or Reset & Exit Loop
                if (($SaveConfig -eq 'no') -or ($SaveConfig -eq 'n')) {
                    $URL        = $NULL
                    $Username   = $NULL
                    $Password   = $NULL
                    $SaveConfig = $NULL
                    continue
                }
                elseif ($SaveConfig) { Write-Host $SaveConfig ; break }
                # End Convoluted Logic

                # User Input
                if (!$URL) {
                    
                    $URL = Read-host

                    if ($URL -eq 'BACK') { return }
                    elseif ($URL -match $RegexString) { continue }
                    else { Write-Host "`nInvalid URL." -ForegroundColor Red ; Start-Sleep -Seconds 1 ; $URL = $NULL }
                }
                elseif (!$Username) {
                    
                    $Username = Read-Host

                    if ($Username -eq 'BACK') { 
                        $URL      = $NULL
                        $Username = $NULL
                        continue
                    }
                    else { continue }
                }
                elseif (!$Password) {

                    $Password = Read-Host

                    if ($Password -eq 'BACK') {
                        $Username = $NULL
                        $Password = $NULL
                        continue
                    }
                    else { continue }
                }
                elseif (!$SaveConfig) {

                    $SaveConfig = Read-Host

                    $AcceptableInput = @('yes','y','no','n')

                    if ($AcceptableInput -contains $SaveConfig) { continue }
                    elseif ($SaveConfig -eq "BACK") {
                        $Password = $NULL
                        $SaveConfig   = $NULL
                        continue
                    }
                    else { Write-Host "`nInvalid input." -ForegroundColor Red ; Start-Sleep -Seconds 1 ; $SaveConfig = $NULL }
                }
            }

            # Encode Credentials
            $EncodedURL      = Base64 -Encode $URL
            $EncodedUsername = Base64 -Encode $Username
            $EncodedPassword = Base64 -Encode $Password

            # Create File with Saved Credentials
            $EncodedCredentials = @{url=$EncodedURL; username=$EncodedUsername; password=$EncodedPassword} | ConvertTo-Json
            New-Item -Path $CredentialFile -Value $EncodedCredentials -Force | Out-Null
            Write-Host 'Credential file generated.' -ForegroundColor Green
        }
    }
    function HTTPS-Bypass ([switch]$Undo) {
    
        ### Self-Signed Certificate / HTTPS Bypass ###

        # Remove Certificate Bypass at the end of Script
        if ($Undo) { [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $NULL }

        $CertBypass = @'
using System;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

namespace SelfSignedCerts
{
    public class UploadBypass
    {
         public static Func<HttpRequestMessage,X509Certificate2,X509Chain,SslPolicyErrors,Boolean> ValidationCallback = 
            (message, cert, chain, errors) => {
                return true; 
            };
    };

    public class PowerShellCertificates
    {
        public static void Bypass()
        {
            ServicePointManager.ServerCertificateValidationCallback = 
                delegate
                (
                    Object obj, 
                    X509Certificate certificate, 
                    X509Chain chain, 
                    SslPolicyErrors errors
                )
                {
                    return true;
                };
        }
    }
}
'@

        if ($PSEdition -eq 'Core') { Add-Type $CertBypass }
        else { Add-Type -AssemblyName System.Net.Http ; Add-Type $CertBypass -ReferencedAssemblies System.Net.Http }

        # Invoke certificate bypass for both Windows PowerShell and Core
        [SelfSignedCerts.PowerShellCertificates]::Bypass()
    }
    function User-Authentication ([switch]$Login,[switch]$Logout) {
        
        # Login & Acquire Cookies
        if ($Login) {

            Try {
                $Client   = [System.Net.WebClient]::new()
                $Client.Headers.Add('Content-Type',$ContentType)
                $Response = $Client.UploadString($LoginPage,$LoginCreds)

                if ($ErrorMessages -notcontains $Response) {
                    $Cookies = $Client.ResponseHeaders.Get("Set-Cookie").Split(';')[0]
                    return $Cookies
                }
                else { return (Write-Host 'Login was unsuccessful.' -ForegroundColor Red) }
            }

            Catch { return (Write-Host 'Connection could not be made.' -ForegroundColor Red) }  
        }

        # Logout & Nuke Cookies
        elseif ($Logout) {
            $Client  = [System.Net.WebClient]::new()
            $Client.Headers.Add('Content-Type',$ContentType)
            $Client.Headers.Add('Cookie',$Cookies)
            $Response = $Client.DownloadString($LogoutPage)
        }
    }
    
    function Invoke-Download {

        Try {
            # Download File Contents
            $Request = [System.Net.HttpWebRequest]::Create($DownloadPage)
            $Request.Headers.Add('Cookie',$Cookies)
            $Request.set_Timeout(10000) # 10 Seconds

            $Response        = $Request.GetResponse()
            $TotalKiloBytes  = [System.Math]::Floor($Response.get_ContentLength()/1024)

            $OutputStream    = [System.IO.FileStream]::new($FileOutput,'Create')
            $Buffer          = [byte[]]::new(32KB)

            $ResponseStream  = $Response.GetResponseStream()
            $Count           = $ResponseStream.Read($Buffer,0,$Buffer.length)
            $DownloadedBytes = $Count

            # Incrementing Progress Bar as the Stream is being Written to Disk
            while ($Count -gt 0) {
        
                $CurrentKiloBytes  = [System.Math]::Floor($DownloadedBytes/1024)
                $PercentComplete   = ([System.Math]::Floor($DownloadedBytes/1024) / $TotalKiloBytes) * 100

                if ($PercentComplete -isnot [Double]) {
                    Write-Progress -Activity "Downloading File: '$File'" -Status "Progress ($CurrentKiloBytes KB / $TotalKiloBytes KB):" -PercentComplete $PercentComplete
                }
                $OutputStream.Write($Buffer, 0, $Count)

                $Count             = $ResponseStream.Read($Buffer,0,$Buffer.length)
                $DownloadedBytes  += $Count
            }

            Write-Host 'File successfully downloaded.' -ForegroundColor Green
        }

        Catch { return (Write-Host 'File not found.' -ForegroundColor Red) }

        # Cleanup Hanging Processes
        $OutputStream.Flush()
        $OutputStream.Close()
        $OutputStream.Dispose()
        $ResponseStream.Dispose()
    }
    function Invoke-Upload {

        # MIME Type Detection (PowerShell Core)
        if ($PSEdition -eq 'Core') {

            # Extension-based MIME type / Content-Type (Hard-Coded)
            $MimeTypeMap = @{
               
                '.pdf'   =  'application/pdf';
                '.jpg'   =  'image/jpeg';
                '.jpeg'  =  'image/jpeg';
                '.png'   =  'image/png';
                '.gif'   =  'image/gif';
                '.zip'   =  'application/zip';
                '.rar'   =  'application/x-rar-compressed';
                '.7z'    =  'application/x-7z-compressed';
                '.gzip'  =  'application/x-gzip';
                '.csv'   =  'text/csv';
                '.txt'   =  'text/plain';
                '.json'  =  'application/json';
                '.xml'   =  'application/xml';
                '.dll'   =  'application/x-msdownload'
            }

            $Extension = (Get-Item $FullFilepath).Extension.ToLower()
            $ContentType = $MimeTypeMap[$Extension]
            if (!$ContentType) { $ContentType = 'application/octet-stream' }
        }

        # MIME Type Detection (Windows PowerShell)
        else {

            # Get file MIME type / Content-Type (.NET)
            Add-Type -AssemblyName System.Web
            $ContentType = [System.Web.MimeMapping]::GetMimeMapping($FullFilepath)
        }


        # Required for HttpClient / HttpClientHandler creation; originally called in HTTPS-Bypass
        if (($PSEdition -ne 'Core') -and ($Protocol -eq 'http')) { Add-Type -AssemblyName System.Net.Http }

        # Create HttpClient and  handler to store authorized cookies 
        $Handler = [System.Net.Http.HttpClientHandler]::new()
        $Handler.CookieContainer.SetCookies($URL,$Cookies)

        if ($Protocol -eq 'https') {
            $Handler.ServerCertificateCustomValidationCallback = [SelfSignedCerts.UploadBypass]::ValidationCallback
        }

        $httpClient        = [System.Net.Http.HttpClient]::new($Handler)

        ## Start Multipart Form Creation ##

        $FileStream        = [System.IO.FileStream]::new($FullFilepath,'Open')
        $DispositionHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new('form-data')

        # Custom Content-Disposition header name (Custom Python Server Specific)
        $DispositionHeader.Name     = 'TYLER.RAR'
        $DispositionHeader.FileName = $File

        $StreamContent                            = [System.Net.Http.StreamContent]::new($FileStream)
        $StreamContent.Headers.ContentType        = [System.Net.Http.Headers.MediaTypeHeaderValue]::new($ContentType)
        $StreamContent.Headers.ContentDisposition = $DispositionHeader
    
        $MultipartContent = [System.Net.Http.MultipartFormDataContent]::new()
        $MultipartContent.Add($StreamContent)

        ## End Multipart Form Creation ##

        # Attempt to upload file and return server response
        $Transmit      = $httpClient.PostAsync($UploadPage, $MultipartContent).Result
        $ServerMessage = $Transmit.Content.ReadAsStringAsync().Result

        if ($ErrorMessages -contains $ServerMessage) { Write-Host $ServerMessage -ForegroundColor Red }
        else { Write-Host 'File successfully uploaded.' -ForegroundColor Green }
        
        # Cleanup Hanging Processes
        $httpClient.Dispose()
        $Transmit.Dispose()
        $FileStream.Dispose()
    }
    function Invoke-FileQuery {
   
        # Query All Available Files on Server
        $Client   = [System.Net.WebClient]::new()
        $Client.Headers.Add('Content-Type',$ContentType)
        $Client.Headers.Add('Cookie',$Cookies)
        $Response = $Client.DownloadString($QueryPage)

        if (!$Response) { return (Write-Host 'No files currently available.' -ForegroundColor Red) }

        Write-Host "╔═════════════════╗`n║" -NoNewline
        Write-Host ' Available Files ' -NoNewline -ForegroundColor Yellow
        Write-Host "║`n╚═════════════════╝"

        $FileList = $Response.Split(' ')
        foreach ($Available in $FileList) { 
            Write-Host '-- ' -NoNewline
            Write-Host $Available -ForegroundColor Yellow
        }
    }
    function Invoke-FileContent {
        
        # Get Raw File Content of Hosted File
        $Client   = [System.Net.WebClient]::new()
        $Client.Headers.Add('Content-Type',$ContentType)
        $Client.Headers.Add('Cookie',$Cookies)
        $Response = $Client.DownloadString($ContentPage)

        # If file isn't human readable (e.g., .dll, .exe) or not present on server
        if ($ErrorMessages -contains $Response) { return (Write-Host $Response -ForegroundColor Red) }

        $Response
    }

 
    # Get-Help and Usage Correction
    if ($Help)                                              { return (Get-Help Invoke-FileTransfer)                           }
    if ($File -and !$Download -and !$Upload -and !$Content) { return (Write-Host 'No action specified.' -ForegroundColor Red) }
    if (!$File) {
        if ($Download -or $Upload -or $Content)             { return (Write-Host 'Input file.' -ForegroundColor Red)          }
        if (!$Credentials -and !$Query)                     { return (Write-Host 'Missing parameters.' -ForegroundColor Red)  }
    }
    

    # Create or Use Credential File
    if ($Credentials) {
       
        $CredentialFile = $PSScriptRoot + '\var\credentials.json'

        if (!$File -and !$Download -and !$Upload -and !$Content -and !$Query) { return (Server-Credentials -Generate) }

        elseif (Test-Path -LiteralPath $CredentialFile) {

            $ServerCredentials = Server-Credentials -Retrieve

            $URL      = $ServerCredentials.url
            $Username = $ServerCredentials.username
            $Password = $ServerCredentials.password
        }
    }
    elseif (!$Username -and !$URL -and !$Password) { return (Write-Host 'Input connection data.' -ForegroundColor Red) }


    # Establish Commonly Used Variables
    $DownloadPage = $URL + '/en-us/p2ft/download/' + $File
    $ContentPage  = $URL + '/en-us/p2ft/read/' + $File
    $UploadPage   = $URL + '/en-us/p2ft/upload'
    $QueryPage    = $URL + '/en-us/p2ft/master'

    $LoginPage    = $URL + '/login'
    $LogoutPage   = $URL + '/logout'

    $Protocol     = $URL.Split(':')[0]
    $ContentType  = 'application/x-www-form-urlencoded'
    $LoginCreds   = "username=$Username&password=$Password"

    $ErrorMessages  = @(
        'LOGIN REQUIRED',
        'UNSUCCESSFUL LOGIN',
        'FILE NOT FOUND',
        'NOT HUMAN READABLE',
        'FILE NOT ALLOWED',
        'NULL FILENAME'
    )


    # Login & Acquire Cookies
    if ($Protocol -eq 'https') { HTTPS-Bypass }
    $Cookies = User-Authentication -Login
    if (!$Cookies) { return }


    # Main Functionality
    if ($Query) { Invoke-FileQuery }
    else {
        $File = Split-Path -Leaf $File

        if ($Content) { Invoke-FileContent }

        elseif ($Download)   {
            $FileOutput  = $PWD.Path + "\$File"
            Invoke-Download
        }
        elseif ($Upload) { 
            $FullFilepath = (Get-Item -LiteralPath $File).FullName
            Invoke-Upload
        }
    }


    # Logout & Cleanup
    User-Authentication -Logout
    if ($Protocol -eq 'https') { HTTPS-Bypass -Undo }
}