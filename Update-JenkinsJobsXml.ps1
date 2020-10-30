Import-Module eqDevOps

$dirs = Get-ChildItem -Path "C:\jobs_new" -Directory
foreach ($dir in $dirs) {
	if (Test-Path "$($dir.FullName)\config.xml") {
		try {
			[xml]$config = Get-XMLFile -xmlFile "$($dir.FullName)\config.xml"
			if ($config.'maven2-moduleset') {
				Write-Output "Maven Project Found: $($dir.FullName)\config.xml"
				if ($config.'maven2-moduleset'.properties.'hudson.model.ParametersDefinitionProperty') {
					Write-Output "hudson.model.ParametersDefinitionProperty already exists."
				}
				Write-Output "Adding Hudson Model Definition Property"
				$xPath = "/maven2-moduleset/properties"
				$Properties = (Select-Xml -Xml $config -XPath $xPath).get_node()
				$HudsonModel = $config.CreateElement('hudson.model.ParametersDefinitionProperty')
				$Properties.AppendChild($HudsonModel) | Out-Null
				$xPath = "/maven2-moduleset/properties/hudson.model.ParametersDefinitionProperty"
				$ParametersDefinitionProperty = (Select-Xml -Xml $config -XPath $xPath).get_node()
				$ParameterDefinitionsNode = $config.CreateElement('parameterDefinitions')
				$ParametersDefinitionProperty.AppendChild($ParameterDefinitionsNode) | Out-Null
				$xPath = "/maven2-moduleset/properties/hudson.model.ParametersDefinitionProperty/parameterDefinitions"
				$parameterDefinitions = (Select-Xml -Xml $config -XPath $xPath).get_node()
				$scriptNode = $config.CreateElement('org.jvnet.jenkins.plugins.nodelabelparameter.LabelParameterDefinition')
				$scriptNode.SetAttribute("plugin", "nodelabelparameter@1.7.1")
				$parameterDefinitions.AppendChild($scriptNode) | Out-Null
				$xPath = "/maven2-moduleset/properties/hudson.model.ParametersDefinitionProperty/parameterDefinitions/org.jvnet.jenkins.plugins.nodelabelparameter.LabelParameterDefinition"
				$LabelParameterDefinition = (Select-Xml -Xml $config -XPath $xPath).get_node()
				$nameNode = $config.CreateElement('name')
				$nameNode.InnerText = "Node"
				$LabelParameterDefinition.AppendChild($nameNode) | Out-Null
				$Description = $config.CreateElement('description')
				$LabelParameterDefinition.AppendChild($Description) | Out-Null
				$DefaultValue = $config.CreateElement('defaultValue')
				$DefaultValue.InnerText = "master"
				$LabelParameterDefinition.AppendChild($DefaultValue) | Out-Null
				$AllNodesMatchingLabel = $config.CreateElement('allNodesMatchingLabel')
				$AllNodesMatchingLabel.InnerText = "false"
				$LabelParameterDefinition.AppendChild($AllNodesMatchingLabel) | Out-Null
				$TriggerIfResult = $config.CreateElement('triggerIfResult')
				$TriggerIfResult.InnerText = "allCases"
				$LabelParameterDefinition.AppendChild($TriggerIfResult) | Out-Null
				$NodeEligibility = $config.CreateElement('nodeEligibility')
				$NodeEligibility.SetAttribute("class", "org.jvnet.jenkins.plugins.nodelabelparameter.node.AllNodeEligibility")
				$LabelParameterDefinition.AppendChild($NodeEligibility) | Out-Null
				Write-Output "Saving: $($dir.FullName)\config.xml"
				Set-XMLFile -xmlFile "$($dir.FullName)\config.xml" -xmlData $config
			}
		} catch {
			Write-Output "ERROR: $($dir.FullName)\config.xml"
		}
	}
}