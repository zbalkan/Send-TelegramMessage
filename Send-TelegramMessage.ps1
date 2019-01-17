function Send-TelegramMessage {
    <#
    .SYNOPSIS
    Send text messages using Telegram API

    .DESCRIPTION
    It's a helpful source for system administrators to create Telegram messages using PowerShell. It's a good tool 
    when monitoring solution does not provide integration or when there is not an advanced monitoring tool needed.

    .PARAMETER Message
    Message text to send via Telegram API. Plain text string for now.

    .INPUTS
    Message parameter can be pipelined.

    .OUTPUTS
    Most of the output reports are in configuration files. Others are results of message sending attempts.
    Configuration : PS Object containing configuration data
    SendReports : Results of message sending attempts

    .EXAMPLE
    Send-TelegramMessage -Message "Hello World"

    .EXAMPLE
    "Hello World" | Send-TelegramMessage
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param (

    # Message text to send via Telegram API
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Message
    )
    begin {
        # Define functions

        function Write-Log() {
            <#
            .Synopsis
            Writes message to log file
            .DESCRIPTION
            Log file path, log message and severity level shall be given as parameters.
            Log rotation or any other advanced log solution is not defined.
            Log time is defined as ISO8186 standard.
            .EXAMPLE
            # First argument is implicitly defined Message parameter. Level is INFO by default.
            Write-Log "An event occured" -LogPath "telegram.log"
            .EXAMPLE
            Write-Log "An alert occured" -Level WARNING -LogPath "telegram.log"
            .EXAMPLE
            Write-Log "An error occured" -Level ERROR -LogPath "telegram.log"
            .INPUTS
            Message: Message to log as string
            Level: INFO, WARNING and ERROR. INFO is default.
            LogPath: Any text file path to append log message.
            .OUTPUTS
            No output.
            .NOTES
            Log format: ISO8186 DateTime | Severity Level | Message
            .COMPONENT
            The component this cmdlet belongs to Send-TelegramMessage cmdlet
            #>
            [CmdletBinding()]
            param(
            [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
            [ValidateNotNull()]
            [ValidateNotNullOrEmpty()]
            [String]
            $Message,
  
            [Parameter(Mandatory = $false, Position = 1)]
            [ValidateNotNull()]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("INFO", "WARNING", "ERROR")]
            [String]
            $Level = "INFO",

            [Parameter(Mandatory = $true, Position = 2)]
            [ValidateNotNull()]
            [ValidateNotNullOrEmpty()]
            [String]
            $LogPath
            )
            "$(Get-Date -Format o)`t|`t$Level`t|`t$Message" | Out-File $LogPath -Append
        }

        function Get-TLConfiguration(){
            <#
            .Synopsis
            Reads configuration file and returns an object
            .DESCRIPTION
            The configuration file is config.xml by default. It reads the file and returns a PS object.
            It throws exception when file is not found. It does not validate the content of data.
            .EXAMPLE
            Get-TLConfiguration
            .INPUTS
            No input
            .OUTPUTS
            ApiId
            ApiHash
            Phone
            LogPath
            Peers 
            .COMPONENT
            The component this cmdlet belongs to Send-TelegramMessage cmdlet
            #>
            [CmdletBinding()]
            [OutputType([psobject])]
            param()
            process{
                try {
                    $Content =  ([XML](Get-Content (Join-Path -Path $PSScriptRoot -ChildPath config.xml) -ErrorAction Stop)).configuration
                    $Config = @{
                        ApiId = $Content.telegram.apiId
                        ApiHash = $Content.telegram.apiHash
                        Phone = $Content.telegram.phone
                        LogPath = Join-Path -Path $PSScriptRoot -ChildPath $Content.log.path
                        Peers = $Content.usernames 
                    }
                    return New-Object -Property $Config -TypeName psobject
                }
                catch {
                    throw "Could not found configuration file. Make sure config.xml exists in the current directory."
                }
            }
        }

        function Import-TLModule() {
            <#
            .Synopsis
            Imports PsTelegramAPI module
            .DESCRIPTION
            Imports PsTelegramAPI module and throws exception if it cannot find
            .EXAMPLE
            Import-TLModule
            .INPUTS
            No inputs
            .OUTPUTS
            No output.
            .COMPONENT
            The component this cmdlet belongs to Send-TelegramMessage cmdlet
            #>
            [CmdletBinding()]
            param()
            try {
                Import-Module PSTelegramAPI -ErrorAction Stop      
            }
            catch {
                throw "PSTelegramAPI module cannot be found."
            }
        }

        $TLConfig = Get-TLConfiguration
        Write-Verbose "Read configuration file"

        Import-TLModule
        Write-Verbose "Imported PSTelegramAPI module"

        try {
            $TLClient = New-TLClient -apiId $TLConfig.ApiId -apiHash $TLConfig.ApiHash -phoneNumber $TLConfig.Phone -ErrorAction Stop
            Write-Verbose "Started Telegram Client"
        }
        catch {
            $TLLogMessage = "Could not connect to Telegram. Check your network connection and configuration."
            Write-Log -Message $TLLogMessage -Level ERROR -LogPath $TLConfig.LogPath
            throw $TLLogMessage
        }
    }
    process {

        $Result = @{
            Configuration = $TLConfig
            SendReports = @()
        }

        # Getting List of User Dialogs because peers (usernames) are required to be in contact list
        $TLUserDialogs = Get-TLUserDialogs -TLClient $TLClient
        Write-Verbose "Read usernames from file"

        $TLConfig.usernames | ForEach-Object {
            $Username = $_.user

            $TLPeer = $TLUserDialogs.Where( { $_.Peer.Username -eq $Username }).Peer

            if ($null -eq $TLPeer) {
                $Result.SendReports += "$Username : Failure"
                $TLLogMessage = "Peer not found."
                Write-Log -Message $TLLogMessage -Level WARNING -LogPath $TLLogPath
                Write-Warning $TLLogMessage
            }
            else {
                $TelegramMessage = Invoke-TLSendMessage -TLClient $TLClient -TLPeer $TLPeer -Message $Message
                $SentDate = ((Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($TelegramMessage.date))).ToString("o")

                $Result.SendReports += "$Username : Success"
                $TLLogMessage = "Message sent to $Username at $SentDate."
                Write-Log -Message $TLLogMessage -Level INFO -LogPath $TLLogPath
                Write-Verbose $TLLogMessage
            }
        }
        return New-Object -Property $Result -TypeName psobject
    }
    end { }
}
