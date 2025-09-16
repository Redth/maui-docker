function Set-ProvisionContext {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Context
    )

    $script:ProvisionContext = $Context
}

function Get-ProvisionContext {
    if (-not $script:ProvisionContext) {
        throw "Provision context has not been initialized."
    }

    return $script:ProvisionContext
}

function Test-DryRun {
    $context = Get-ProvisionContext
    return [bool]($context.DryRun)
}

function Set-ModuleRoot {
    param([string]$Path)
    $script:ModuleRoot = $Path
}

function Get-ModuleRoot {
    if (-not $script:ModuleRoot) {
        throw "Module root has not been initialized."
    }
    return $script:ModuleRoot
}
