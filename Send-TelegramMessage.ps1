<#
.Synopsis
   Send text messages using Telegram API
.DESCRIPTION
   It's a helpful source for system administrators to create Telegram messages using Powershell. It's good to 
.RELATED LINKS
    https://github.com/zbalkan/Send-TelegramMessage
.EXAMPLE
   Send-TelegramMessage -Message "Hello World"
.EXAMPLE
   "Hello World" | Send-TelegramMessage
   #>
   function Send-TelegramMessage
   {
    [CmdletBinding()]
    Param
    (
        # Message text to send via Telegram API
        [Parameter(Mandatory=$true,
         ValueFromPipeline=$true,
         Position=0)]
        [string]$Message
        )

    Begin
    {
        # Read configuration file
        $TLConfigFile = [XML](Get-Content -Path .\config.xml)
        $TLConfig = $TLConfigFile.configuration

        #Set API configuration values
        $TLApiId = $TLConfig.telegram.apiId
        $TLApiHash = $TLConfig.telegram.apiHash
        $TLPhone = $TLConfig.telegram.phone

        # Read log file
        $TLLogPath = $TLConfig.log.path

        # Import Telegram API Module
        Import-Module PSTelegramAPI

        # Establish connection to Telegram
        $TLClient = New-TLClient -apiId $TLApiId -apiHash $TLApiHash -phoneNumber $TLPhone

    }
    Process
    {
        # Get List of User Dialogs
        $TLUserDialogs = Get-TLUserDialogs -TLClient $TLClient

        # Send message to each user
        $TLConfig.usernames | ForEach-Object { 
            
            $Username = $_.user

            # Find a specific User
            $TLPeer = $TLUserDialogs.Where({ $_.Peer.Username -eq $Username }).Peer

            # Send message to User
            If($TLPeer -eq $null)
            {
                # Log the event
                $TLLogMessage = "$(Get-Date -Format o)`t|`tWARNING`t|`tPeer not found."
                $TLLogMessage | Out-File $TLLogPath -Append
            }
            else
            {
                $TelegramMessage = Invoke-TLSendMessage -TLClient $TLClient -TLPeer $TLPeer -Message $Message

                $SentDate = ((Get-Date 01.01.1970)+([System.TimeSpan]::fromseconds($TelegramMessage.date))).ToString("o");
                
                # Log the event
                $TLLogMessage = "$(Get-Date -Format o)`t|`tINFO`t|`tMessage sent to $Username at $SentDate"
                $TLLogMessage | Out-File $TLLogPath -Append
            }
        }
    }
    End
    {
        $TLConfigFile = $null;
        $TLUserDialogs = $null;
        $TLPeer = $null;
    }
}