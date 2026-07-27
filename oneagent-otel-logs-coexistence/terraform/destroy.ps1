# --------------------------------------------------------------------------
# KILLSWITCH - destroys ALL Lab 2 AWS infrastructure
# --------------------------------------------------------------------------

Write-Host ""
Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
Write-Host "!!               LAB 2 KILLSWITCH                         !!" -ForegroundColor Red
Write-Host "!!  This will PERMANENTLY DESTROY all Lab 2 infra         !!" -ForegroundColor Red
Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "Type DESTROY to confirm"

if ($confirm -ne "DESTROY") {
    Write-Host "Aborted. No changes made." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Running terraform destroy..." -ForegroundColor Yellow
terraform destroy -auto-approve

Write-Host ""
Write-Host "Done. All Lab 2 infrastructure has been destroyed." -ForegroundColor Green
Write-Host "No further AWS costs will be incurred for this lab." -ForegroundColor Green
