param(
    [Parameter(
        HelpMessage="Path to file on which to modify LastWriteTime",
        Mandatory=$true,
        Position=1
    )]
    [string]$Path,

    [Parameter(
        ParameterSetName="Relative",
        HelpMessage="Sets the LastWriteTime relative to the file's current LastWriteTime",
        Mandatory=$true
    )]
    [switch]$Relative,

    [Parameter(
        ParameterSetName="Relative",
        HelpMessage="Set the LastWriteTime to before the current LastWriteTime if set to true"
    )]
    [Boolean]$Before = $false,

    [Parameter(
        ParameterSetName="Absolute",
        HelpMessage="Sets the LastWriteTime to a datetime",
        Mandatory=$true
    )]
    [switch]$Absolute,

    [Parameter(
        ParameterSetName="Relative",
        HelpMessage="A timespan that indicates the amount of time relative to the file's current LastWriteTime to update to",
        Mandatory=$true
    )]
    [TimeSpan]$TimeSpan,

    [Parameter(
        ParameterSetName="Absolute",
        HelpMessage="A datetime to set the file's LastWriteTime to",
        Mandatory=$true
    )]
    [DateTime]$DateTime
)

try {
    $file = Get-Item -Path $Path -ErrorAction Stop
}
catch {
    Write-Error "$Path is not a valid file or directory"
}

if ($Absolute) {
    $file.LastWriteTime = $DateTime
    Write-Output $file
}
elseif ($Relative) {
    if ($Before) {
        $file.LastWriteTime = $file.LastWriteTime - $TimeSpan
    }
    else {
        $file.LastWriteTime = $file.LastWriteTime + $TimeSpan
    }
    Write-Output $file
}