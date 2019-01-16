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
        [string]
        $Message
        )
    begin {
    
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
            Throw "PSTelegramAPI module cannot be found"
        }

        # Establish connection to Telegram
        try {
            $TLClient = New-TLClient -apiId $TLApiId -apiHash $TLApiHash -phoneNumber $TLPhone -ErrorAction Stop
            Write-Verbose "Started Telegram Client"
        }
        catch {
            Throw "Could not connect to Telegram. Check your network connection and configuration."
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
                $TLLogMessage = "$(Get-Date -Format o)`t|`tWARNING`t|`tPeer not found."
                Write-Warning "Peer not found."
            }
            else {
                $TelegramMessage = Invoke-TLSendMessage -TLClient $TLClient -TLPeer $TLPeer -Message $Message
                $SentDate = ((Get-Date 01.01.1970)+([System.TimeSpan]::fromseconds($TelegramMessage.date))).ToString("o")

                # Modify output
                $Result.SendReports += "$Username : Success"

                # Log the event
                $TLLogMessage = "$(Get-Date -Format o)`t|`tINFO`t|`tMessage sent to $Username at $SentDate."
                Write-Verbose "Message sent to $Username at $SentDate."
            }
        }
        
        # Return output
        return New-Object -Property $Result -TypeName psobject
    }
    end {
        if($null -ne $TLLogMessage) { $TLLogMessage | Out-File $TLLogPath -Append }
        Write-Verbose "Returning successfully."
    }
}
