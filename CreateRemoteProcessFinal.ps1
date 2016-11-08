<#
This script is used to run a command on remote computers that are provided in a text file. 
It creates the processes using WMI, and monitors for its completion by subscribing to WMIEvents
Once the Remote Process is finished, the return code is gathered and reported on screen and in the log file.
The script will not finish until all background jobs are complete (or times out)
The timeout can be set on line 71
All other Variables can be set at the top of the script.
#>


#text file with a list of remote computers to start processes on
$serverlist = get-content "C:\temp\serverlist.txt"
#Path to logfile
$logfile = "C:\temp\mylogfile.txt"
#Command to run on remote computer
$command = "robocopy C:\temp\test1\ C:\temp\test2 *.*"








$list = New-Object -TypeName "System.Text.StringBuilder"
$list.AppendLine("ServerName"+ "`t" + "ProcessID" + "`t" + "ReturnCode" +[system.environment]::NewLine) 

ForEach ($server in $serverlist)
    {
    $commandobj = $null
    $commandobj = $server + "`t" + $command
    $job = Start-Job -Name $server{ 
         
        [string]$srvinfo = $input
        [string]$servername = ($srvinfo.split("`t"))[0]
        [string]$cmd = ($srvinfo.split("`t"))[1]



        Function Monitor-Process ([string]$computername, [int]$Id, [int]$timeout = "-1")
            {
            $query = "SELECT * FROM Win32_ProcessStopTrace WHERE ProcessID='$($Id)'"
       
            $srcId = [guid]::NewGuid()
                Try
                {
                Register-WmiEvent -ComputerName $computerName -Query $query  -SourceIdentifier $srcID -ErrorAction stop
                Wait-Event -SourceIdentifier $srcID -Timeout $timeout -ErrorAction stop
                Unregister-Event -SourceIdentifier $srcID -ErrorAction stop
                }
                Catch
                {
                Return "Error Registering WMIEvent(Not Able to Monitor Process: " + $_.Exception.message
                }
            }
        

        Function StartRProcess($strcomputer, $strcommand)
            {
                Try
                {
                $Return = ((Invoke-WmiMethod -ComputerName $strcomputer -Name Create -Class Win32_Process -ArgumentList $strcommand -ErrorAction stop))
                }
                Catch
                {
                Return $strcomputer + "`t" + "?" + "`t" + "Error creating process: " + $_.Exception.Message
                }
                
                If ($return.ReturnValue -eq 0)
                    {
                    $Returnobj = monitor-process -computername $strcomputer -id $return.ProcessId -deletion -timeout 60
                    If ($Returnobj.gettype().Name -eq "String")
                        {
                            If ($Returnobj.contains("Error"))
                                {
                                return $strcomputer + "`t" + $return.ProcessId + "`t" + $Returnobj
                                }    
                       }
                    Else
                        {
                        Return ($strcomputer + "`t" + $return.ProcessId + "`t" + $Returnobj.SourceEventArgs.NewEvent.ExitStatus + "`t" + $error[0].exception.Message)
                        }
                                      
                Else
                    {
                    Return ($strcomputer + "`t" + $return.ProcessId + "`t" + "Error creating process: " + "`t" + $error[0].exception.Message)
                    }
                }
            Else
                {
                Return $strcomputer + "`t" + "?" + "`t" + "Error Creating Process" + "`t" + $return.ReturnValue
                }
            }

            write-host $input.command
    StartRPRocess -strcomputer $servername -strcommand $cmd

        } -InputObject $commandobj
    }
       


Do{
start-sleep 2
$tempjobs = $null
$tempjobs = get-job | Where-Object -Property State -eq "Completed" 
Write-Host "Current Number of Running Jobs: " (get-job | Where-Object -Property State -eq "Running").count
    If ($tempjobs.count -gt 0) 
    {ForEach ($tmpjob in $tempjobs) 
        {
        $list.AppendLine(($tmpjob | receive-job))
        remove-job $tmpjob
        }
    }
    

}Until(((get-job | Where-Object -Property State -eq "Running").count -eq 0))

$tempjobs = $null
$tempjobs = get-job | Where-Object -Property State -eq "Completed"
$list.appendline(($tempjobs | receive-job))
get-job | Where-Object -Property State -eq "Completed" | remove-job
$list.tostring()
If ( -not [system.string]::IsNullOrEmpty($logfile)) {$list.tostring() | out-file $logfile -Append}