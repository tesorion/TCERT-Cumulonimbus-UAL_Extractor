Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
install-module -name ExchangeOnlineManagement