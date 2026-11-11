@echo off
set ENV=%2
if "%ENV%"=="" set ENV=dev

if "%1"=="apply" (
    .\terraform apply -var-file=%ENV%.tfvars -var-file=secrets.tfvars
) else if "%1"=="plan" (
    .\terraform plan -var-file=%ENV%.tfvars -var-file=secrets.tfvars
) else if "%1"=="destroy" (
    .\terraform destroy -var-file=%ENV%.tfvars -var-file=secrets.tfvars
) else if "%1"=="init" (
    .\terraform init
) else (
    echo Usage: tf [apply^|plan^|destroy^|init] [dev^|prod]
    echo Default environment is dev
)
