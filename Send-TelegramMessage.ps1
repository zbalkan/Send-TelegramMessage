<#
.Synopsis
   Send text messages using Telegram API
.DESCRIPTION
   It's a helpful source for system administrators to create Telegram messages using PowerShell. It's a good tool 
   when monitoring solution does not provide integration or when there is not an advanced monitoring tool needed.
.RELATED LINKS
   https://github.com/zbalkan/Send-TelegramMessage
.EXAMPLE
   Send-TelegramMessage -Message "Hello World"
.EXAMPLE
   "Hello World" | Send-TelegramMessage
  #>
   function Send-TelegramMessage {
    [CmdletBinding()]
    [OutputType([psobject])]
    param (
    
        # Message text to send via Telegram API
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Message
        )
    begin {
    # Define functions

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
        function Write-Log() {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory=$true, Position = 0, ValueFromPipeline=$true)]
                [ValidateNotNull()]
                [ValidateNotNullOrEmpty()]
                [String]
                $Message,

                [Parameter(Mandatory=$false, Position = 1)]
                [ValidateNotNull()]
                [ValidateNotNullOrEmpty()]
                [ValidateSet("INFO", "WARNING", "ERROR")]
                [String]
                $Level = "INFO",

                [Parameter(Mandatory=$true, Position = 2)]
                [ValidateNotNull()]
                [ValidateNotNullOrEmpty()]
                [String]
                $LogPath
            )
            "$(Get-Date -Format o)`t|`t$Level`t|`t$Message" | Out-File $LogPath -Append
        }

        # Read configuration file
        try {
            $TLConfigfile = [XML](Get-Content -Path .\config.xml -ErrorAction Stop)
            Write-Verbose "Read configuration file"
        }
        catch {
            Throw "Could not found configuration file. Make sure config.xml exists in the current directory."
        }

        #Set API configuration values
        $TLConfig = $TLConfigfile.configuration
        $TLApiId = $TLConfig.telegram.apiId
        $TLApiHash = $TLConfig.telegram.apiHash
        $TLPhone = $TLConfig.telegram.phone
        Write-Verbose "Set Telegram API configuration values"

        # Read log file
        $TLLogPath = $TLConfig.log.path
        Write-Verbose "Read log file path"

        # Import Telegram API Module
        try {
            Import-Module PSTelegramAPI -ErrorAction Stop
            Write-Verbose "Imported PSTelegramAPI module"
        }
        catch {
            $TLLogMessage = "PSTelegramAPI module cannot be found."
            Write-Log -Message $TLLogMessage -Level ERROR -LogPath $TLLogPath
            Throw $TLLogMessage
        }

        # Establish connection to Telegram
        try {
            $TLClient = New-TLClient -apiId $TLApiId -apiHash $TLApiHash -phoneNumber $TLPhone -ErrorAction Stop
            Write-Verbose "Started Telegram Client"
        }
        catch {
            $TLLogMessage = "Could not connect to Telegram. Check your network connection and configuration."
            Write-Log -Message $TLLogMessage -Level ERROR -LogPath $TLLogPath
            Throw $TLLogMessage
        }
    }
    process {

        # Creating Result property
        $Result = @{
            PhoneNumber = $TLPhone
            ApiId = $TLApiId
            ApiHash = $TLApiHash
            LogPath = $TLLogPath
            Peers = $TLConfig.usernames
            SendReports = @()
        }
    
        # Get List of User Dialogs
        $TLUserDialogs = Get-TLUserDialogs -TLClient $TLClient
        Write-Verbose "Read usernames from file"

        # Send message to each user
        $TLConfig.usernames | ForEach-Object {
            $Username = $_.user

            # Find a specific User
            $TLPeer = $TLUserDialogs.Where({ $_.Peer.Username -eq $Username }).Peer

            # Send message to User
            if($null -eq $TLPeer) {

                # Modify output
                $Result.SendReports += "$Username : Failure"
            
                # Log the event
                $TLLogMessage = "Peer not found."
                Write-Log -Message $TLLogMessage -Level WARNING -LogPath $TLLogPath
                Write-Warning $TLLogMessage
            }
            else {
                $TelegramMessage = Invoke-TLSendMessage -TLClient $TLClient -TLPeer $TLPeer -Message $Message
                $SentDate = ((Get-Date 01.01.1970)+([System.TimeSpan]::fromseconds($TelegramMessage.date))).ToString("o")

                # Modify output
                $Result.SendReports += "$Username : Success"

                # Log the event
                $TLLogMessage = "Message sent to $Username at $SentDate."
                Write-Log -Message $TLLogMessage -Level INFO -LogPath $TLLogPath
                Write-Verbose $TLLogMessage
            }
        }
        
        # Return output
        return New-Object -Property $Result -TypeName psobject
    }
    end { }
}
