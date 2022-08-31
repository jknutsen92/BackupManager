function Confirm-DeletedItems($Meta) {
    if ($deleting) {
        Remove-Item -Path $destPath
        Write-Log -Level INFO "Deleted file in backup $destPath that was deleted in the target"
    }
}