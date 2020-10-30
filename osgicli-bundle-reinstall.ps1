param
(
	[string]$FuseHome = "C:\jboss-fuse-6.3.0.redhat-283",
	[string]$FuseUser = 'admin',
	[string]$FusePass = 'admin',
	[string]$FuseIP = "10.158.45.51",
	[string]$FeatureRepoLoc = "mvn:com.equator.sm.ng.fuse.vi/VendorIntegrationFeatures/1.0.0/xml/features",
	[string]$FeatureName = "vi-framework-core"
)

Write-Output "****** Feature Repository Verification:"
& cmd.exe /c $FuseHome\bin\client.bat -a 8101 -h $FuseIP -u $FuseUser -p $FusePass "features:listurl | grep $FeatureRepoLoc"
Write-Output "****** Deploying Feature Repository (one-off step, run just once if feature repository is not present yet, based on previous validation): $FeatureRepoLoc"
& cmd.exe /c $FuseHome\bin\client.bat -a 8101 -h $FuseIP -u $FuseUser -p $FusePass "features:addUrl $FeatureRepoLoc"
Write-Output "****** Refreshing Feature URLs (recommended prior to feature installation)"
& cmd.exe /c $FuseHome\bin\client.bat -a 8101 -h $FuseIP -u $FuseUser -p $FusePass "features:refreshUrl"
Write-Output "****** Uninstalling Feature: $FeatureName"
& cmd.exe /c $FuseHome\bin\client.bat -a 8101 -h $FuseIP -u $FuseUser -p $FusePass "features:uninstall $FeatureName"
Write-Output "****** Feature: $FeatureName has been uninstalled..."
Write-Output "****** Installing Feature: $FeatureName"
& cmd.exe /c $FuseHome\bin\client.bat -a 8101 -h $FuseIP -u $FuseUser -p $FusePass "features:install $FeatureName"
Write-Output "****** Deployment Verification:"
& cmd.exe /c $FuseHome\bin\client.bat -a 8101 -h $FuseIP -u $FuseUser -p $FusePass "features:list | grep $FeatureName"