<#
.SYNOPSIS
    Management-account procedure: open regions for a member account and make it
    the delegated administrator for the organization's security services.

.DESCRIPTION
    Runs with MANAGEMENT ACCOUNT credentials (named AWS CLI profile). Two tasks:

    1. Region SCP. Finds every Service Control Policy attached to the member
       account, or to any OU above it, that denies by aws:RequestedRegion, and
       adds the requested regions to its allow list. A policy that is not
       editable (AWS managed) is replaced by an extended copy: the copy is
       attached first, the original detached afterwards.

    2. Delegated administration. Enables Organizations trusted access and
       registers the member account as delegated administrator for CloudTrail,
       AWS Config, IAM Access Analyzer, IAM Identity Center (organization-wide,
       one call each) and GuardDuty, Security Hub, Inspector (regional, one call
       per allowed region). Already-registered services are skipped.

    Everything is idempotent. -WhatIf prints the plan without changing anything.
    Compatible with Windows PowerShell 5.1 and PowerShell 7.

.PARAMETER Profile
    AWS CLI profile holding management-account credentials.

.PARAMETER MemberAccountId
    12-digit account ID of the member account (the Security Tooling account).

.PARAMETER AllowedRegions
    Regions the member account must be able to use. Existing allowed regions are kept.

.PARAMETER SkipRegionScp
    Do not touch SCPs.

.PARAMETER SkipDelegatedAdmin
    Do not register delegated administrators.

.EXAMPLE
    .\Configure-MemberAccount.ps1 -Profile mgmt -MemberAccountId 111111111111 -WhatIf

.EXAMPLE
    .\Configure-MemberAccount.ps1 -Profile mgmt -MemberAccountId 111111111111 -AllowedRegions eu-north-1,us-east-1

.NOTES
    NIST 800-53: SC-7 (boundary via SCP), CM-7 (least functionality), AC-6 (delegation
    instead of working in the management account), CM-3 (change is scripted and reviewable).
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [string]$Profile,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{12}$')]
    [string]$MemberAccountId,

    [string[]]$AllowedRegions = @('eu-north-1', 'us-east-1'),

    [switch]$SkipRegionScp,

    [switch]$SkipDelegatedAdmin
)

Set-StrictMode -Version 2.0
$script:Summary = @()

# Helpers

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "== $Text ==" -ForegroundColor Cyan
}

function Write-Ok   { param([string]$Text) Write-Host "  [ok]   $Text" -ForegroundColor Green }
function Write-Skip { param([string]$Text) Write-Host "  [skip] $Text" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Text) Write-Host "  [warn] $Text" -ForegroundColor Yellow }
function Write-Fail { param([string]$Text) Write-Host "  [fail] $Text" -ForegroundColor Red }

function Add-Summary {
    param([string]$Area, [string]$Item, [string]$Result)
    $script:Summary += [pscustomobject]@{ Area = $Area; Item = $Item; Result = $Result }
}

# Runs the AWS CLI, merges stderr into the text result, never throws.
# Returns an object with ExitCode, Text and Json (parsed when the output is JSON).
function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $ErrorActionPreference = 'Continue'
    $all = @($Arguments) + @('--profile', $Profile, '--output', 'json')
    $raw = & aws @all 2>&1
    $code = $LASTEXITCODE

    $lines = foreach ($item in @($raw)) {
        if ($item -is [System.Management.Automation.ErrorRecord]) { $item.Exception.Message } else { [string]$item }
    }
    $text = ($lines -join "`n").Trim()

    $json = $null
    if ($code -eq 0 -and $text.Length -gt 0) {
        try { $json = $text | ConvertFrom-Json } catch { $json = $null }
    }

    return [pscustomobject]@{ ExitCode = $code; Text = $text; Json = $json }
}

function Test-AlreadyDone {
    param([string]$Text)
    return ($Text -match 'already|AlreadyExists|AccountAlreadyRegistered|DuplicatePolicyAttachment|ConflictException|is already the delegated')
}

function Write-TempJson {
    param([object]$Object)
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("scp-" + [guid]::NewGuid().ToString("N") + ".json")
    $json = $Object | ConvertTo-Json -Depth 32 -Compress
    [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
    return $path
}

# Preconditions

Write-Step "Preconditions"

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Fail "AWS CLI not found in PATH. Open a new terminal or install AWS CLI v2."
    exit 1
}

$profiles = @((& aws configure list-profiles) 2>$null)
if ($profiles -notcontains $Profile) {
    Write-Fail "Profile '$Profile' does not exist. Create it with: aws configure --profile $Profile"
    exit 1
}

$who = Invoke-Aws @('sts', 'get-caller-identity')
if ($who.ExitCode -ne 0) { Write-Fail "Cannot authenticate with profile '$Profile': $($who.Text)"; exit 1 }
$callerAccount = $who.Json.Account
Write-Ok "caller $($who.Json.Arn)"

$org = Invoke-Aws @('organizations', 'describe-organization')
if ($org.ExitCode -ne 0) { Write-Fail "describe-organization failed: $($org.Text)"; exit 1 }
$managementAccount = $org.Json.Organization.MasterAccountId
$orgId = $org.Json.Organization.Id

if ($callerAccount -ne $managementAccount) {
    Write-Fail "Profile '$Profile' is account $callerAccount, but the management account of $orgId is $managementAccount."
    Write-Fail "SCPs and delegated administration can only be changed from the management account."
    exit 1
}
Write-Ok "management account $managementAccount of organization $orgId"

if ($org.Json.Organization.FeatureSet -ne 'ALL') {
    Write-Fail "Organization feature set is $($org.Json.Organization.FeatureSet). SCPs and delegated admin require ALL features."
    exit 1
}

$member = Invoke-Aws @('organizations', 'describe-account', '--account-id', $MemberAccountId)
if ($member.ExitCode -ne 0) { Write-Fail "Account $MemberAccountId is not in this organization: $($member.Text)"; exit 1 }
Write-Ok "member account $MemberAccountId ($($member.Json.Account.Name), $($member.Json.Account.Status))"

# Task 1: region SCPs

function Get-TargetChain {
    # The account itself, then each parent OU up to the root.
    param([string]$AccountId)
    $chain = New-Object System.Collections.Generic.List[object]
    $chain.Add([pscustomobject]@{ Id = $AccountId; Type = 'ACCOUNT' })
    $childId = $AccountId
    for ($i = 0; $i -lt 10; $i++) {
        $parents = Invoke-Aws @('organizations', 'list-parents', '--child-id', $childId)
        if ($parents.ExitCode -ne 0 -or -not $parents.Json.Parents) { break }
        $parent = $parents.Json.Parents[0]
        $chain.Add([pscustomobject]@{ Id = $parent.Id; Type = $parent.Type })
        if ($parent.Type -eq 'ROOT') { break }
        $childId = $parent.Id
    }
    return $chain
}

function Get-RegionConditionValues {
    # Returns the region list of a Deny statement conditioned on aws:RequestedRegion, or $null.
    param([object]$Statement)
    if ($Statement.Effect -ne 'Deny') { return $null }
    if (-not ($Statement.PSObject.Properties.Name -contains 'Condition')) { return $null }
    foreach ($operator in @('StringNotEquals', 'StringNotEqualsIfExists', 'StringNotEqualsIgnoreCase')) {
        if ($Statement.Condition.PSObject.Properties.Name -contains $operator) {
            $cond = $Statement.Condition.$operator
            if ($cond.PSObject.Properties.Name -contains 'aws:RequestedRegion') {
                return [pscustomobject]@{ Operator = $operator; Regions = @($cond.'aws:RequestedRegion') }
            }
        }
    }
    return $null
}

function Get-RegionSpecificDeny {
    # Returns the region list of a Deny statement that applies only when
    # aws:RequestedRegion EQUALS a region (a per-region service allow list), or $null.
    param([object]$Statement)
    if ($Statement.Effect -ne 'Deny') { return $null }
    if (-not ($Statement.PSObject.Properties.Name -contains 'Condition')) { return $null }
    foreach ($operator in @('StringEquals', 'StringEqualsIfExists', 'StringEqualsIgnoreCase')) {
        if ($Statement.Condition.PSObject.Properties.Name -contains $operator) {
            $cond = $Statement.Condition.$operator
            if ($cond.PSObject.Properties.Name -contains 'aws:RequestedRegion') {
                return @($cond.'aws:RequestedRegion')
            }
        }
    }
    return $null
}

if (-not $SkipRegionScp) {
    Write-Step "Task 1: region SCPs for account $MemberAccountId"

    $chain = Get-TargetChain -AccountId $MemberAccountId
    Write-Ok ("target chain: " + (($chain | ForEach-Object { "$($_.Type) $($_.Id)" }) -join ' -> '))

    $found = 0
    foreach ($target in $chain) {
        $attached = Invoke-Aws @('organizations', 'list-policies-for-target', '--target-id', $target.Id, '--filter', 'SERVICE_CONTROL_POLICY')
        if ($attached.ExitCode -ne 0) { Write-Warn "list-policies-for-target $($target.Id): $($attached.Text)"; continue }

        foreach ($policySummary in @($attached.Json.Policies)) {
            $detail = Invoke-Aws @('organizations', 'describe-policy', '--policy-id', $policySummary.Id)
            if ($detail.ExitCode -ne 0) { Write-Warn "describe-policy $($policySummary.Id): $($detail.Text)"; continue }

            $content = $detail.Json.Policy.Content | ConvertFrom-Json
            $statements = @($content.Statement)
            $changed = $false
            $relevant = 0
            $keep = @()

            for ($i = 0; $i -lt $statements.Count; $i++) {
                $stmt = $statements[$i]
                $sid = if ($stmt.PSObject.Properties.Name -contains 'Sid') { $stmt.Sid } else { "statement $i" }

                # Per-region restriction: "Deny everything except this service list when
                # the region is X". Removing it makes X fully usable.
                $specific = Get-RegionSpecificDeny -Statement $stmt
                if ($null -ne $specific) {
                    $hit = @($specific | Where-Object { $AllowedRegions -contains $_ })
                    if ($hit.Count -gt 0) {
                        $found++; $relevant++
                        Write-Ok "policy $($policySummary.Id) '$($policySummary.Name)' on $($target.Type) $($target.Id): '$sid' limits [$($specific -join ', ')] to a service allow list"
                        Write-Ok "will remove '$sid' so [$($hit -join ', ')] is fully usable"
                        $changed = $true
                        continue
                    }
                    $keep += $stmt
                    continue
                }

                $keep += $stmt

                # Region floor: "Deny everything unless the region is in this list".
                $cond = Get-RegionConditionValues -Statement $stmt
                if ($null -eq $cond) { continue }

                $found++; $relevant++
                $current = @($cond.Regions)
                $missing = @($AllowedRegions | Where-Object { $current -notcontains $_ })
                Write-Ok "policy $($policySummary.Id) '$($policySummary.Name)' on $($target.Type) $($target.Id): '$sid' allows [$($current -join ', ')]"

                if ($missing.Count -eq 0) {
                    Write-Skip "'$sid' already lists all requested regions"
                    continue
                }

                $stmt.Condition.($cond.Operator).'aws:RequestedRegion' = [string[]](@($current) + @($missing))
                $changed = $true
                Write-Ok "will add [$($missing -join ', ')] to '$sid'"
            }

            if (-not $changed) {
                if ($relevant -gt 0) { Add-Summary 'Region SCP' "$($policySummary.Id) $($policySummary.Name)" 'unchanged' }
                continue
            }
            $content.Statement = [object[]]$keep

            # Other accounts under the same OU inherit the change. Say so.
            if ($target.Type -ne 'ACCOUNT') {
                $siblings = Invoke-Aws @('organizations', 'list-accounts-for-parent', '--parent-id', $target.Id)
                if ($siblings.ExitCode -eq 0) {
                    $others = @($siblings.Json.Accounts | Where-Object { $_.Id -ne $MemberAccountId })
                    if ($others.Count -gt 0) {
                        Write-Warn "this policy is attached to $($target.Type) $($target.Id); $($others.Count) other account(s) will also gain the regions: $(($others | ForEach-Object { $_.Id }) -join ', ')"
                    }
                }
            }

            $tmp = Write-TempJson -Object $content
            $newBytes = (Get-Item $tmp).Length
            if ($newBytes -gt 5120) {
                Write-Fail "new policy would be $newBytes bytes; SCP limit is 5120. Not applied."
                Add-Summary 'Region SCP' "$($policySummary.Id) $($policySummary.Name)" 'too large'
                Remove-Item $tmp -Force -WhatIf:$false
                continue
            }

            if ($policySummary.AwsManaged) {
                # Cannot edit an AWS managed policy: create an extended copy, attach it, detach the original.
                $newName = "$($policySummary.Name)-extended"
                if ($PSCmdlet.ShouldProcess("$($target.Type) $($target.Id)", "replace AWS managed SCP $($policySummary.Id) with '$newName' allowing [$($AllowedRegions -join ', ')]")) {
                    $create = Invoke-Aws @('organizations', 'create-policy', '--name', $newName, '--type', 'SERVICE_CONTROL_POLICY', '--description', "Region allow list extended by Configure-MemberAccount.ps1", '--content', "file://$tmp")
                    if ($create.ExitCode -ne 0) { Write-Fail "create-policy: $($create.Text)"; Add-Summary 'Region SCP' $newName 'create failed'; Remove-Item $tmp -Force -WhatIf:$false; continue }
                    $newId = $create.Json.Policy.PolicySummary.Id
                    $attach = Invoke-Aws @('organizations', 'attach-policy', '--policy-id', $newId, '--target-id', $target.Id)
                    if ($attach.ExitCode -ne 0 -and -not (Test-AlreadyDone $attach.Text)) { Write-Fail "attach-policy: $($attach.Text)"; Add-Summary 'Region SCP' $newName 'attach failed'; Remove-Item $tmp -Force -WhatIf:$false; continue }
                    $detach = Invoke-Aws @('organizations', 'detach-policy', '--policy-id', $policySummary.Id, '--target-id', $target.Id)
                    if ($detach.ExitCode -ne 0) { Write-Warn "detach-policy $($policySummary.Id): $($detach.Text) (new policy is attached; detach the old one manually)" }
                    Write-Ok "replaced $($policySummary.Id) with $newId"
                    Add-Summary 'Region SCP' "$newId $newName" 'created and attached'
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess("SCP $($policySummary.Id) '$($policySummary.Name)'", "update allow list to [$($AllowedRegions -join ', ')]")) {
                    $update = Invoke-Aws @('organizations', 'update-policy', '--policy-id', $policySummary.Id, '--content', "file://$tmp")
                    if ($update.ExitCode -ne 0) {
                        Write-Fail "update-policy: $($update.Text)"
                        Add-Summary 'Region SCP' "$($policySummary.Id) $($policySummary.Name)" 'update failed'
                    }
                    else {
                        Write-Ok "updated $($policySummary.Id)"
                        Add-Summary 'Region SCP' "$($policySummary.Id) $($policySummary.Name)" 'updated'
                    }
                }
            }
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }

    if ($found -eq 0) {
        Write-Warn "no SCP with an aws:RequestedRegion condition is attached to the account or its OUs. Nothing to change."
        Add-Summary 'Region SCP' 'none found' 'no region restriction in effect'
    }
}

# Task 2: delegated administration

if (-not $SkipDelegatedAdmin) {
    Write-Step "Task 2: trusted access"

    $principals = @(
        'cloudtrail.amazonaws.com',
        'config.amazonaws.com',
        'config-multiaccountsetup.amazonaws.com',
        'guardduty.amazonaws.com',
        'securityhub.amazonaws.com',
        'inspector2.amazonaws.com',
        'access-analyzer.amazonaws.com',
        'sso.amazonaws.com'
    )

    $enabled = Invoke-Aws @('organizations', 'list-aws-service-access-for-organization')
    $enabledPrincipals = @()
    if ($enabled.ExitCode -eq 0) { $enabledPrincipals = @($enabled.Json.EnabledServicePrincipals | ForEach-Object { $_.ServicePrincipal }) }

    foreach ($p in $principals) {
        if ($enabledPrincipals -contains $p) { Write-Skip "trusted access already enabled: $p"; continue }
        if ($PSCmdlet.ShouldProcess($p, "enable trusted access")) {
            $r = Invoke-Aws @('organizations', 'enable-aws-service-access', '--service-principal', $p)
            if ($r.ExitCode -eq 0 -or (Test-AlreadyDone $r.Text)) { Write-Ok "trusted access enabled: $p" } else { Write-Fail "enable-aws-service-access ${p}: $($r.Text)" }
        }
    }

    Write-Step "Task 2: organization-wide delegated administrators"

    # Services registered through the Organizations API.
    foreach ($p in @('config.amazonaws.com', 'config-multiaccountsetup.amazonaws.com', 'access-analyzer.amazonaws.com', 'sso.amazonaws.com')) {
        $existing = Invoke-Aws @('organizations', 'list-delegated-administrators', '--service-principal', $p)
        $ids = @()
        if ($existing.ExitCode -eq 0) { $ids = @($existing.Json.DelegatedAdministrators | ForEach-Object { $_.Id }) }
        if ($ids -contains $MemberAccountId) { Write-Skip "$p already delegated to $MemberAccountId"; Add-Summary 'Delegated admin' $p 'already'; continue }
        if ($ids.Count -gt 0) {
            Write-Warn "$p is already delegated to $($ids -join ', '). Most services allow one delegated administrator; deregister it first if you want $MemberAccountId instead."
            Add-Summary 'Delegated admin' $p "skipped, held by $($ids -join ', ')"
            continue
        }
        if ($PSCmdlet.ShouldProcess($p, "register delegated administrator $MemberAccountId")) {
            $r = Invoke-Aws @('organizations', 'register-delegated-administrator', '--account-id', $MemberAccountId, '--service-principal', $p)
            if ($r.ExitCode -eq 0 -or (Test-AlreadyDone $r.Text)) { Write-Ok "$p delegated"; Add-Summary 'Delegated admin' $p 'registered' }
            else { Write-Fail "register-delegated-administrator ${p}: $($r.Text)"; Add-Summary 'Delegated admin' $p 'failed' }
        }
    }

    # CloudTrail has its own API (organization trails from the delegated account).
    $ctExisting = Invoke-Aws @('organizations', 'list-delegated-administrators', '--service-principal', 'cloudtrail.amazonaws.com')
    $ctIds = @()
    if ($ctExisting.ExitCode -eq 0) { $ctIds = @($ctExisting.Json.DelegatedAdministrators | ForEach-Object { $_.Id }) }
    if ($ctIds -contains $MemberAccountId) { Write-Skip "cloudtrail.amazonaws.com already delegated to $MemberAccountId"; Add-Summary 'Delegated admin' 'cloudtrail.amazonaws.com' 'already' }
    elseif ($ctIds.Count -gt 0) { Write-Warn "cloudtrail.amazonaws.com is already delegated to $($ctIds -join ', '); skipping."; Add-Summary 'Delegated admin' 'cloudtrail.amazonaws.com' "skipped, held by $($ctIds -join ', ')" }
    elseif ($PSCmdlet.ShouldProcess('cloudtrail.amazonaws.com', "register delegated administrator $MemberAccountId")) {
        $r = Invoke-Aws @('cloudtrail', 'register-organization-delegated-admin', '--member-account-id', $MemberAccountId, '--region', 'us-east-1')
        if ($r.ExitCode -eq 0 -or (Test-AlreadyDone $r.Text)) { Write-Ok "cloudtrail delegated"; Add-Summary 'Delegated admin' 'cloudtrail.amazonaws.com' 'registered' }
        else { Write-Fail "cloudtrail register-organization-delegated-admin: $($r.Text)"; Add-Summary 'Delegated admin' 'cloudtrail.amazonaws.com' 'failed' }
    }

    Write-Step "Task 2: regional delegated administrators ($($AllowedRegions -join ', '))"

    foreach ($region in $AllowedRegions) {
        # GuardDuty
        $gd = Invoke-Aws @('guardduty', 'list-organization-admin-accounts', '--region', $region)
        $gdIds = @()
        if ($gd.ExitCode -eq 0) { $gdIds = @($gd.Json.AdminAccounts | ForEach-Object { $_.AdminAccountId }) }
        if ($gdIds -contains $MemberAccountId) { Write-Skip "GuardDuty $region already delegated"; Add-Summary "GuardDuty $region" $MemberAccountId 'already' }
        elseif ($gdIds.Count -gt 0) { Write-Warn "GuardDuty $region is already delegated to $($gdIds -join ', '); skipping."; Add-Summary "GuardDuty $region" $MemberAccountId "skipped, held by $($gdIds -join ', ')" }
        elseif ($PSCmdlet.ShouldProcess("GuardDuty $region", "enable organization admin account $MemberAccountId")) {
            $r = Invoke-Aws @('guardduty', 'enable-organization-admin-account', '--admin-account-id', $MemberAccountId, '--region', $region)
            if ($r.ExitCode -eq 0 -or (Test-AlreadyDone $r.Text)) { Write-Ok "GuardDuty $region delegated"; Add-Summary "GuardDuty $region" $MemberAccountId 'registered' }
            else { Write-Fail "GuardDuty ${region}: $($r.Text)"; Add-Summary "GuardDuty $region" $MemberAccountId 'failed' }
        }

        # Security Hub
        $sh = Invoke-Aws @('securityhub', 'list-organization-admin-accounts', '--region', $region)
        $shIds = @()
        if ($sh.ExitCode -eq 0) { $shIds = @($sh.Json.AdminAccounts | ForEach-Object { $_.AccountId }) }
        if ($shIds -contains $MemberAccountId) { Write-Skip "Security Hub $region already delegated"; Add-Summary "Security Hub $region" $MemberAccountId 'already' }
        elseif ($shIds.Count -gt 0) { Write-Warn "Security Hub $region is already delegated to $($shIds -join ', '); skipping."; Add-Summary "Security Hub $region" $MemberAccountId "skipped, held by $($shIds -join ', ')" }
        elseif ($PSCmdlet.ShouldProcess("Security Hub $region", "enable organization admin account $MemberAccountId")) {
            $r = Invoke-Aws @('securityhub', 'enable-organization-admin-account', '--admin-account-id', $MemberAccountId, '--region', $region)
            if ($r.ExitCode -eq 0 -or (Test-AlreadyDone $r.Text)) { Write-Ok "Security Hub $region delegated"; Add-Summary "Security Hub $region" $MemberAccountId 'registered' }
            else { Write-Fail "Security Hub ${region}: $($r.Text)"; Add-Summary "Security Hub $region" $MemberAccountId 'failed' }
        }

        # Inspector
        $insp = Invoke-Aws @('inspector2', 'get-delegated-admin-account', '--region', $region)
        $inspId = $null
        if ($insp.ExitCode -eq 0 -and $insp.Json.delegatedAdmin) { $inspId = $insp.Json.delegatedAdmin.accountId }
        if ($inspId -eq $MemberAccountId) { Write-Skip "Inspector $region already delegated"; Add-Summary "Inspector $region" $MemberAccountId 'already' }
        elseif ($null -ne $inspId) { Write-Warn "Inspector $region is already delegated to $inspId; skipping."; Add-Summary "Inspector $region" $MemberAccountId "skipped, held by $inspId" }
        elseif ($PSCmdlet.ShouldProcess("Inspector $region", "enable delegated admin account $MemberAccountId")) {
            $r = Invoke-Aws @('inspector2', 'enable-delegated-admin-account', '--delegated-admin-account-id', $MemberAccountId, '--region', $region)
            if ($r.ExitCode -eq 0 -or (Test-AlreadyDone $r.Text)) { Write-Ok "Inspector $region delegated"; Add-Summary "Inspector $region" $MemberAccountId 'registered' }
            else { Write-Fail "Inspector ${region}: $($r.Text)"; Add-Summary "Inspector $region" $MemberAccountId 'failed' }
        }
    }
}

# Summary

Write-Step "Summary"
if (@($script:Summary).Count -gt 0) { $script:Summary | Format-Table -AutoSize | Out-String | Write-Host }

if ($WhatIfPreference) {
    Write-Host "WhatIf run: nothing was changed." -ForegroundColor Yellow
}
else {
    Write-Host "Next steps in the member account:" -ForegroundColor Cyan
    Write-Host "  1. Verify:  aws cloudtrail list-trails --region us-east-1   (should no longer be denied)"
    Write-Host "  2. terraform.tfvars: set region as desired; with delegation you may now use"
    Write-Host "     is_organization_trail / enable_identity_center from the member account."
    Write-Host "  3. SCPs themselves still live in the management account (modules/org stays code-only"
    Write-Host "     unless applied with the management profile)."
}
