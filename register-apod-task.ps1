cargo install --git https://github.com/eta077/apod-analyzer --locked --force

$exePath = (where.exe apod-analyzer | Select-Object -First 1).Trim()
if (-not (Test-Path $exePath)) {
    Write-Error "apod-analyzer.exe not found."
    exit 1
}

# Create the Task Scheduler COM object and connect
$service = New-Object -ComObject "Schedule.Service"
$service.Connect()
$rootFolder = $service.GetFolder("\")

$task = $service.NewTask(0)
$task.RegistrationInfo.Description = "Downloads the current APOD and sets it as the desktop background"
$task.RegistrationInfo.Author      = "$env:USERDOMAIN\$env:USERNAME"

# Principal (run as current user, interactive, least privilege)
$principal = $task.Principal
$principal.Id = "Author"
$principal.UserId = "$env:USERDOMAIN\$env:USERNAME"
$principal.LogonType = 3          # InteractiveToken
$principal.RunLevel = 0           # LeastPrivilege

# Settings
$settings = $task.Settings
$settings.Enabled                    = $true
$settings.AllowDemandStart           = $true
$settings.DisallowStartIfOnBatteries = $false
$settings.StopIfGoingOnBatteries     = $true
$settings.ExecutionTimeLimit         = "PT1H"
$settings.MultipleInstances          = 2   # IgnoreNew

# Action
$action = $task.Actions.Create(0)  # 0 = Exec
$action.Path = $exePath

# Trigger (event-based)
$trigger = $task.Triggers.Create(0) # 0 = EventTrigger
$trigger.Enabled = $true
$trigger.Subscription = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
    <Select Path="Microsoft-Windows-NetworkProfile/Operational">
      *[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]
    </Select>
  </Query>
</QueryList>
"@

$rootFolder.RegisterTaskDefinition(
    "APOD Desktop",
    $task,
    6,                  # 6 = CreateOrUpdate
    $null,              # no explicit user (use Principal)
    $null,
    3,                  # 3 = LogonType.InteractiveToken
    $null
)

Write-Output "Task registered successfully."
