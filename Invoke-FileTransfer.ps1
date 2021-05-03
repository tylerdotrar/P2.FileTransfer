function Invoke-FileTransfer {
#.SYNOPSIS
# Python x PowerShell user-authentication based file transfer via Flask web server (client-side).
# ARBITRARY VERSION NUMBER:  1.0.0
# AUTHOR:  Tyler McCann (@tyler.rar)
#
#.DESCRIPTION
# This script is designed to transfer files (upload and download) to a custom Python-based flask web server, 
# supporting both HTTP and HTTPS protocols.  The Python web server should only accept files sent from this script 
# due to the modified HTTP Content-Disposition header name.  On top of that, communications will only work if the
# user inputs the authorized credentials configured on the web server.  If PowerShell Core is used, file MIME 
# types are determined based off of a hard-coded list of file extensions; whereas with Desktop Powershell, MIME 
# types are automatically determined based off of file contents.
#
# Alternate data streams (ADS) are NOT supported.
#
# Parameters:
#    -Upload        -->   Upload a file to the web server
#    -Download      -->   Download a file from the web server
#    -File          -->   File to upload/download
#    -URL           -->   URL of the web server
#    -Help          -->   (Optional) Return Get-Help information
#    
# Example Usage:
#    []  PS C:\Users\Bobby> Invoke-FileTransfer -Upload -File 'Passwords.txt' -URL 'http://192.168.1.24:17540'
#        [SERVER AUTHENTICATION]
#        - Username: admin
#        - Password: password
#
#        Server Response (HTTPS): SUCCESSFUL UPLOAD
#
#    []  PS C:\Users\Bobby> filetransfer -Download
#        [TRANSMISSION DATA]
#        - Filename: CoolPic.png 
#        - URL: http://192.168.0.69:54321
#
#        [SERVER AUTHENTICATION]
#        - Username: bobby
#        - Password: schmurda
#
#        Server Response (HTTP): SUCCESSFUL DOWNLOAD
#
#    []  PS C:\Users\Bobby> Invoke-FileUpload -Upload -File SuperCoolScript.ps1
#        [TRANSMISSION DATA]
#        - URL: https://192.168.0.10:12345
#
#        [SERVER AUTHENTICATION]
#        - Username: admin
#        - Password: notpass
#
#        Server Response (HTTPS): UNSUCCESSFUL LOGIN
#
#.LINK
# https://github.com/tylerdotrar/P2.FileTransfer


    [Alias('filetransfer')]

    Param (
        [switch] $Upload,
        [switch] $Download,
        [string] $File,
        [string] $URL = '<url>',
        [switch] $Help
    )

    # Internal Functions
    function HTTPS-Bypass ([switch]$Undo) {

        if ($Undo) { [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $NULL }

        else {

            # [!] Required by non-Core PowerShell for self-signed certificate bypass (HTTPS).
            $CertBypass = @'
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public class WindowsPowerShellCerts
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
'@
            Add-Type $CertBypass
            [WindowsPowerShellCerts]::Bypass()
        }
    }
    function Server-Upload {
        
        # Required by Windows PowerShell for HttpClient / HttpClientHandler creation and cert bypass
        if ($PSEdition -ne 'Core') { Add-Type -AssemblyName System.Net.Http }

        # Bypass HttpClientHandler certificate validation (self-signed certificates)
        if ($Protocol -eq 'HTTPS') {

            # .NET version independent C# code for bypass
            $CertBypass = @'
using System;
using System.Net.Http;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

namespace SelfSignedCerts
{
    public class Bypass
    {
         public static Func<HttpRequestMessage,X509Certificate2,X509Chain,SslPolicyErrors,Boolean> ValidationCallback = 
            (message, cert, chain, errors) => {
                return true; 
            };
    }
}
'@
        
            if ($PSEdition -eq 'Core') { Add-Type $CertBypass }
            else { Add-Type $CertBypass -ReferencedAssemblies System.Net.Http }
        }


        # MIME Type Detection (PowerShell Core)
        if ($PSEdition -eq 'Core') {

            # Extension-based MIME type / Content-Type (Hard-Coded)
            $MimeTypeMap = @{
                '.txt'   =  'text/plain';
                '.jpg'   =  'image/jpeg';
                '.jpeg'  =  'image/jpeg';
                '.png'   =  'image/png';
                '.gif'   =  'image/gif';
                '.zip'   =  'application/zip';
                '.rar'   =  'application/x-rar-compressed';
                '.gzip'  =  'application/x-gzip';
                '.json'  =  'application/json';
                '.xml'   =  'application/xml';
                '.ps1'   =  'application/octet-stream';
            }

            $Extension = (Get-Item $File).Extension.ToLower()
            $ContentType = $MimeTypeMap[$Extension]
        }


        # MIME Type Detection (Windows PowerShell)
        else {

            # Get file MIME type / Content-Type (.NET)
            Add-Type -AssemblyName System.Web
            $ContentType = [System.Web.MimeMapping]::GetMimeMapping($File)
        }


        # Create a message handler object for the HttpClient (.NET) and store authorized session cookies
        $Handler = [System.Net.Http.HttpClientHandler]::new()
        $Handler.CookieContainer = $SessionID.Cookies

        if ($Protocol -eq 'HTTPS') {
            $Handler.ServerCertificateCustomValidationCallback = [SelfSignedCerts.Bypass]::ValidationCallback
        }


        # Create an HttpClient object for sending / receiving HTTP(S) data (.NET)
        $httpClient = [System.Net.Http.HttpClient]::new($Handler)


        ## Start Multipart Form Creation ##

        $FileStream = New-Object System.IO.FileStream @($File, [System.IO.FileMode]::Open)
        $DispositionHeader = New-Object System.Net.Http.Headers.ContentDispositionHeaderValue 'form-data'

        # Custom Content-Disposition header name (Custom Python Server Specific)
        $DispositionHeader.Name = 'TYLER.RAR'
        $DispositionHeader.FileName = $TempFileName

        $StreamContent = New-Object System.Net.Http.StreamContent $FileStream
        $StreamContent.Headers.ContentDisposition = $DispositionHeader
        $StreamContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue $ContentType
        
        $MultipartContent = New-Object System.Net.Http.MultipartFormDataContent
        $MultipartContent.Add($StreamContent)

        ## End Multipart Form Creation ##


        # Attempt to upload file and return server response
        Try {

            $Transmit = $httpClient.PostAsync($UploadPage, $MultipartContent).Result
            $ServerMessage = $Transmit.Content.ReadAsStringAsync().Result

            Write-Host "`nServer Response ($Protocol): " -ForegroundColor Yellow -NoNewline
            Write-Host $ServerMessage
        }


        # This error will appear if you put in an incorrect URL (or other less obvious things)
        Catch { 
            Write-Host 'Failed to reach the server!' -ForegroundColor DarkRed
            return
        }


        # Cleanup Hanging Processes
        Finally {
            if ($NULL -ne $httpClient) { $httpClient.Dispose() }
            if ($NULL -ne $Transmit) { $Transmit.Dispose() }
            if ($NULL -ne $FileStream) { $FileStream.Dispose() }
        }
    }
    function Server-Download {

        # Attempt to download file from the server
        Try {

            if ($PSEdition -ne 'Core') { Invoke-WebRequest $DownloadPage -WebSession $SessionID -Outfile $File }
            else { Invoke-WebRequest $DownloadPage -SkipCertificateCheck -WebSession $SessionID -Outfile $File }

            Write-Host "`nServer Response ($Protocol): " -NoNewline -ForegroundColor Yellow
            Write-Host "SUCCESSFUL DOWNLOAD"
        }


        # File doesn't exist on the server
        Catch {
            Write-Host "`nServer Response ($Protocol): " -NoNewline -ForegroundColor Yellow
            Write-Host "FILE NOT FOUND"
        }
    }
    

    # Return Get-Help information
    if ($Help) { return Get-Help Invoke-FileTransfer }

    # Failed to specify whether to download from or upload to server
    elseif (!$Download -and !$Upload) { return (Write-Host 'No action specified.' -ForegroundColor Red) }


    # Prompt Header
    if (!$File -or $URL) { Write-Host "[TRANSMISSION DATA]" -ForegroundColor Green } 


    # Prompt for File
    if (!$File) {  Write-Host '- Filename: ' -NoNewLine -ForegroundColor Yellow ; $File = Read-Host }

    # Verify input file (UPLOAD ONLY)
    if ($Upload) { 
        
        if (Test-Path -LiteralPath $File) { $File = (Get-Item -LiteralPath $File).FullName }
    
        else {
            Write-Host 'File does not exist!' -ForegroundColor DarkRed
            return
        }
    }
    $TempFileName = Split-Path -Leaf $File


    # Prompt for Server URL
    if ($URL -eq '<url>') { Write-Host '- URL: ' -NoNewline -ForegroundColor Yellow ; $URL = Read-Host }

    # Verify protocol
    if ($URL -like "https://*") { $Protocol = 'HTTPS' }
    elseif ( $URL -like "http://*") { $Protocol = 'HTTP' }
    else {
        Write-Host 'URL neither HTTP nor HTTPS!' -ForegroundColor DarkRed
        return
    }


    # Server Pages
    $DownloadPage = $URL + "/en-us/p2ft/download/$TempFileName"
    $UploadPage   = $URL + "/en-us/p2ft/upload"
    $LoginPage    = $URL + '/login'
    $LogoutPage   = $URL + '/logout'
 
    
    # User Authentication
    Write-Host "`n[SERVER AUTHENTICATION]" -ForegroundColor Green
    Write-Host '- Username: ' -NoNewLine -ForegroundColor Yellow ; $ServerUsername = Read-Host
    Write-Host '- Password: ' -NoNewLine -ForegroundColor Yellow ; $ServerPassword = Read-Host


    # Windows PowerShell Self-Signed Certificate Bypass
    if ($PSEdition -ne 'Core') {
        HTTPS-Bypass
        $LoginResponse = (Invoke-WebRequest $LoginPage -Body @{username="$ServerUsername";password="$ServerPassword"} -Method POST -SessionVariable 'SessionID').content
    }
    else { $LoginResponse = (Invoke-WebRequest $LoginPage -SkipCertificateCheck -Body @{username="$ServerUsername";password="$ServerPassword"} -Method POST -SessionVariable 'SessionID').content }


    if ($LoginResponse -ne 'SUCCESSFUL LOGIN') {

        Write-Host "`nServer Response ($Protocol): " -NoNewline -ForegroundColor Yellow
        Write-Host $LoginResponse

        return
    }

    
    # Main
    if ($Download)   { Server-Download }
    elseif ($Upload) { Server-Upload }

    # Logout / Remove Self-Signed Certificate Bypass (Windows PowerShell)
    if ($PSEdition -eq 'Core') { Invoke-WebRequest $LogoutPage -SkipCertificateCheck -WebSession $SessionID | Out-Null }
    else {
        Invoke-WebRequest $LogoutPage -WebSession $SessionID | Out-Null
        HTTPS-Bypass -Undo
    }
}