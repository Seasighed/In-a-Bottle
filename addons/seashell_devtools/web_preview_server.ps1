param(
    [Parameter(Mandatory = $true)][string]$RootPath,
    [Parameter(Mandatory = $true)][string]$HtmlFileName,
    [Parameter(Mandatory = $true)][string]$StateFilePath
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Web

$resolvedRoot = [System.IO.Path]::GetFullPath($RootPath)
$resolvedHtmlFile = [System.IO.Path]::GetFileName($HtmlFileName)
$resolvedStateFilePath = [System.IO.Path]::GetFullPath($StateFilePath)

if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
    throw "Preview root folder does not exist: $resolvedRoot"
}

$defaultDocumentPath = Join-Path $resolvedRoot $resolvedHtmlFile
if (-not (Test-Path -LiteralPath $defaultDocumentPath -PathType Leaf)) {
    throw "Preview HTML file does not exist: $defaultDocumentPath"
}

$stateParent = Split-Path -Parent $resolvedStateFilePath
if (-not [string]::IsNullOrWhiteSpace($stateParent)) {
    New-Item -ItemType Directory -Force -Path $stateParent | Out-Null
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Get-ContentType([string]$filePath) {
    switch ([System.IO.Path]::GetExtension($filePath).ToLowerInvariant()) {
        ".html" { return "text/html; charset=utf-8" }
        ".js" { return "application/javascript; charset=utf-8" }
        ".mjs" { return "application/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".css" { return "text/css; charset=utf-8" }
        ".wasm" { return "application/wasm" }
        ".pck" { return "application/octet-stream" }
        ".png" { return "image/png" }
        ".jpg" { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".gif" { return "image/gif" }
        ".svg" { return "image/svg+xml" }
        ".ico" { return "image/x-icon" }
        ".txt" { return "text/plain; charset=utf-8" }
        ".webmanifest" { return "application/manifest+json; charset=utf-8" }
        ".xml" { return "application/xml; charset=utf-8" }
        default { return "application/octet-stream" }
    }
}

function Write-PreviewResponse([System.Net.HttpListenerResponse]$response, [int]$statusCode, [string]$message) {
    $payload = [System.Text.Encoding]::UTF8.GetBytes($message)
    $response.StatusCode = $statusCode
    $response.ContentType = "text/plain; charset=utf-8"
    $response.ContentLength64 = $payload.LongLength
    $response.OutputStream.Write($payload, 0, $payload.Length)
    $response.OutputStream.Close()
}

$port = Get-FreeTcpPort
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

$defaultDocumentUrl = [System.Web.HttpUtility]::UrlPathEncode($resolvedHtmlFile)
$previewUrl = if ([string]::IsNullOrWhiteSpace($defaultDocumentUrl)) { "http://127.0.0.1:$port/" } else { "http://127.0.0.1:$port/$defaultDocumentUrl" }
$state = @{
    pid = $PID
    port = $port
    url = $previewUrl
    rootPath = $resolvedRoot
    htmlFileName = $resolvedHtmlFile
}
$state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resolvedStateFilePath -Encoding UTF8

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        try {
            $response.Headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
            $response.Headers["Pragma"] = "no-cache"
            $response.Headers["Expires"] = "0"
            $response.Headers["Cross-Origin-Opener-Policy"] = "same-origin"
            $response.Headers["Cross-Origin-Embedder-Policy"] = "require-corp"
            $response.Headers["Cross-Origin-Resource-Policy"] = "same-origin"
            $response.Headers["Access-Control-Allow-Origin"] = "*"

            $relativePath = [System.Web.HttpUtility]::UrlDecode($request.Url.AbsolutePath.TrimStart("/"))
            if ([string]::IsNullOrWhiteSpace($relativePath)) {
                $relativePath = $resolvedHtmlFile
            }

            $candidatePath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $relativePath))
            if (-not $candidatePath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-PreviewResponse $response 403 "Forbidden"
                continue
            }

            if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
                Write-PreviewResponse $response 404 "Not Found"
                continue
            }

            $response.StatusCode = 200
            $response.ContentType = Get-ContentType $candidatePath
            $bytes = [System.IO.File]::ReadAllBytes($candidatePath)
            $response.ContentLength64 = $bytes.LongLength
            if ($request.HttpMethod -ne "HEAD") {
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            $response.OutputStream.Close()
        }
        catch {
            if ($response.OutputStream.CanWrite) {
                Write-PreviewResponse $response 500 $_.Exception.Message
            }
        }
    }
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
