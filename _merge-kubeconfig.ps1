# Quickly add a new Kubectl context

$kube_dir = Join-Path $HOME ".kube"
$kubeconfig_original = Join-Path $kube_dir "config"
$kubeconfig_tmp = [System.IO.Path]::GetTempFileName()
$kubeconfig_new = $args[0]

# Ensure script argument is not empty
if ([string]::IsNullOrWhiteSpace($kubeconfig_new)) {
    echo "Usage: $PSCommandPath <new_kubeconfig_file_path>"
    exit 1
}

# Ensure .kube dir exists
if (-not (Test-Path $kube_dir)) {
    New-Item -ItemType Directory -Path $kube_dir | Out-Null
}

if (-not (Test-Path $kubeconfig_new)) {
    echo "error: file '$kubeconfig_new' not found"
    exit 1
}

$cluster_name = kubectl config view --kubeconfig="$kubeconfig_new" -o jsonpath='{.clusters[0].name}'
echo "detected cluster name '$cluster_name' in $kubeconfig_new"

# Rename existing username & context to avoid conflicts between all the contexts due to defaults values
(Get-Content $kubeconfig_new) | ForEach-Object {
    $_ -replace '(user:).+', "`$1 $cluster_name" `
       -replace '(cluster:).+', "`$1 $cluster_name" `
       -replace '(name:).+', "`$1 $cluster_name"
} | Set-Content $kubeconfig_new

# Backup the current kubeconfig
if (Test-Path $kubeconfig_original) {
    $date_format = Get-Date -Format "yyyyMMddHHmmss"
    Copy-Item $kubeconfig_original "$kubeconfig_original.save.$date_format"
}

# Delete old context/cluster/user if it was already existing with same name
if ((kubectl config get-users) -eq $cluster_name) {
    kubectl config delete-user $cluster_name
}
if ((kubectl config get-clusters) -eq $cluster_name) {
    kubectl config delete-cluster $cluster_name
}
if ((kubectl config get-contexts -o name) -eq $cluster_name) {
    kubectl config delete-context $cluster_name
}

# Merge the 2 files
# KUBECONFIG accept a list of files separated with ';' on Windows
$env:KUBECONFIG = "$kubeconfig_original;$kubeconfig_new"
kubectl config view --flatten | Out-File -FilePath $kubeconfig_tmp -Encoding utf8

# Replace original file with the tmp file
Move-Item -Path $kubeconfig_tmp -Destination $kubeconfig_original -Force

$error_flag = $false

if (-not ((kubectl config get-contexts -o name) -eq $cluster_name)) {
    $error_flag = $true
    echo "error: context '$cluster_name' not added"
}

if (-not ((kubectl config get-users) -eq $cluster_name)) {
    $error_flag = $true
    echo "error: user '$cluster_name' not added"
}

if (-not ((kubectl config get-clusters) -eq $cluster_name)) {
    $error_flag = $true
    echo "error: cluster '$cluster_name' not added"
}

if ($error_flag -ne $true) {
    kubectl config use-context $cluster_name
    echo "successfully added context '$cluster_name' in $kubeconfig_original"
}

exit 0
