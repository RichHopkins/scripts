$serverXmls = Get-ChildItem -Path "D:\ServerBox\Servers\ColdFusion\cfusion?\runtime\conf\server.xml"

ForEach ($serverXml in $serverXmls) {
	$bakName = $serverXml.FullName -replace ".xml", ".bak"
	Copy-Item $serverXml.FullName $bakName -Force
	[xml]$xmlData = Get-Content $serverXml
	$nodenames = @("jdbc/Reotrans", "jdbc/Activiti", "jdbc/Environments")
	foreach ($nodename in $nodenames) {
		$xPath = "/Server/GlobalNamingResources/Resource[@name=""$nodename""]"
		$node = (Select-Xml -Xml $xmlData -XPath $xPath).get_node()
		$node.SetAttribute("testWhileIdle", "true")
		$node.SetAttribute("testOnBorrow", "true")
		$node.SetAttribute("testOnReturn", "false")
		$node.SetAttribute("validationQuery", "select 1")
		$node.SetAttribute("validationInterval", "30000")
		$node.SetAttribute("minEvictableIdleTimeMillis", "30000")
	}
	$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
	$textWriter = New-Object System.Xml.XmlTextWriter($serverXml, $Utf8NoBomEncoding)
	$textWriter.Formatting = "indented"
	$textWriter.Indentation = 2
	$xmlData.save($textWriter)
	$textWriter.close()
}