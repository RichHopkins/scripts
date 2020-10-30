# ==============================================================================================
# 
# Microsoft PowerShell Source File -- Created with SAPIEN Technologies PrimalScript 2007
# 
# NAME: wmiwizard.ps1
# 
# AUTHOR: Jeffery Hicks , SAPIEN Technologies, Inc.
# DATE  : 12/11/2008
# 
# COMMENT: Use this Powershell script to create a WMI expression using
# Get-WMIObject.  Connect to a computer, browse the classes, select properties.
# When finished, click the Create Command button to generate Powershell code.  You
# can edit the command further.  
# If you don't select any properties, using the Create Command button will generate
# a Select * query. You can copy the code using Ctrl-C or you can 
# execute it.  The command will be saved as a global script block called $wmiwiz.
# 
# ==============================================================================================


#Generated Form Function
function GenerateForm {
########################################################################
# Code Generated By: SAPIEN Technologies PrimalForms 2009 v1.0.0.0
# Generated On: 12/11/2008 10:05 AM
# Generated By: Jeffery Hicks
########################################################################

#region Import the Assembles
[reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null
[reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
#endregion

#region Generated Form Objects
$form1 = New-Object System.Windows.Forms.Form
$rtbPropertyValues = New-Object System.Windows.Forms.RichTextBox
$label6 = New-Object System.Windows.Forms.Label
$lblType = New-Object System.Windows.Forms.Label
$label4 = New-Object System.Windows.Forms.Label
$label3 = New-Object System.Windows.Forms.Label
$rtbPropertyHelp = New-Object System.Windows.Forms.RichTextBox
$rtbClassHelp = New-Object System.Windows.Forms.RichTextBox
$rtbCode = New-Object System.Windows.Forms.RichTextBox
$btnRun = New-Object System.Windows.Forms.Button
$btnQuit = New-Object System.Windows.Forms.Button
$btnCreate = New-Object System.Windows.Forms.Button
$btnGetClasses = New-Object System.Windows.Forms.Button
$chkProperties = New-Object System.Windows.Forms.CheckedListBox
$label1 = New-Object System.Windows.Forms.Label
$comboClass = New-Object System.Windows.Forms.ComboBox
$statusBar1 = New-Object System.Windows.Forms.StatusBar
$txtComputer = New-Object System.Windows.Forms.TextBox
#endregion Generated Form Objects

#----------------------------------------------
#Generated Event Script Blocks
#----------------------------------------------
#Provide Custom Code for events specified in PrimalForms.
#continue on any errors
$errorActionPreference="SilentlyContinue"

$RunIt= 
{
#save commdand in global scriptblock $wmiwiz    
    $global:wmiwiz=$executioncontext.InvokeCommand.NewScriptBlock($rtbcode.text)
    $form1.DialogResult="OK"
    $form1.close()
} #end RunIT

$Quit= 
{
    $form1.close()
}


$GetClasses= 
{

    #clear leftovers
    $comboClass.Items.Clear()
    $rtbClassHelp.Clear()
    $rtbPropertyHelp.Clear()
    $rtbPropertyValues.Clear()
    $rtbCode.Clear()
    $chkProperties.Items.Clear()
    
$form1.Refresh()

    $computer=$txtComputer.text
    $statusBar1.text="Getting WMI Classes from $computer"
    
    $ms=New-Object system.management.ManagementObjectSearcher
    $ms.Scope.path="\\$computer\root\cimv2"
    
    $ms.query="select * from meta_class where __CLASS like 'Win32_%'"
    $ms.get() |  foreach {
        $statusBar1.text="Adding $($_.name)"
        $comboClass.Items.Add($_.name)
     }
     
     $comboClass.text="Please select a WMI class"
   
     
     $statusBar1.text=("Ready. Found {0} classes." -f $comboClass.items.count)

} #end Get-Classes

$GetProperties=
{

    $rtbClassHelp.clear()
    $rtbPropertyHelp.clear()
    $rtbPropertyValues.Clear()
    $lblType.text=""
    $chkProperties.Items.Clear()
    $rtbCode.Clear()
    

    [wmiclass]$wmi=$comboClass.SelectedItem
    # Write-Host $wmi
    $wmi.psbase.properties | foreach {
    	$ChkProperties.Items.add($_.name)
    }
    
    #show qualifier help description for the class
    $opt = New-Object system.management.ObjectGetOptions
    $opt.UseAmendedQualifiers = $true
    $mpath="\\{0}\Root\Cimv2:{1}" -f $txtComputer.text,$comboClass.SelectedItem
    $mc=New-Object system.Management.ManagementClass($mpath,$opt)
    
    $classHelp=$mc.psbase.qualifiers["description"].value
    if ($classHelp) {
        $rtbClassHelp.text=$classHelp
     }
     else {
        $rtbClassHelp.text="No description available for this class."
     }
     
     Clear-Variable classHelp   
    
     
} #end GetProperties

$GetPropertyHelp= 
{

    $rtbPropertyValues.Clear()
    $lblType.Text=""
   

    # Write-Host $chkProperties.SelectedItem
    $propertyhelp=$mc.psbase.properties[$chkProperties.SelectedItem].qualifiers["description"].value
    
    if ($propertyhelp) {
      $rtbPropertyHelp.text=$propertyhelp
      }
      else {
      $rtbPropertyHelp.text=("No property help available for {0}" -f $chkProperties.selectedItem)
      }
      
      Clear-Variable propertyhelp
      
      $propertyType=$mc.psbase.properties[$chkProperties.SelectedItem].type
      $lblType.text=$propertyType
      
      $values=$mc.psbase.properties[$chkProperties.SelectedItem].qualifiers["values"].value
      
      $valuedata=@()
      for ($j=0;$j -lt $values.count;$j++) {
         $valuedata+="$j = $($values[$j])" 
      }
      
      $rtbPropertyValues.text=($valuedata | Out-String)
      
      Clear-Variable v
      Clear-Variable ValueData
      Clear-Variable values
      
      
} #end GetpropertyHelp


$CreateCommand= 
{
    #clear any leftovers
    $rtbCode.clear()
    
    $chkProperties.CheckedItems | foreach {
    # Write-Host $_
    	if ($properties) {
     	$properties+=",$_"
     	}
     	else {
     		$properties=$_
     	}
     }
     
     #if no properties are selected then do a wildcard query for all
     if ($properties.length -lt 1) {
        $properties="*"
     }
     	
    $query="""Select {0} from {1}""" -f $properties,$comboClass.SelectedItem
    $rtbCode.Text="Get-Wmiobject -query {0} -computername {1}" -f $query,$txtComputer.text
    Clear-Variable properties
    
} #end CreateCommand


#----------------------------------------------

#region Generated Form Code
$form1.Name = 'form1'
$form1.Text = 'PowerShell WMI Wizard'
$form1.BackColor = [System.Drawing.Color]::FromArgb(255,255,248,220)
$form1.DataBindings.DefaultDataSourceUpdateMode = 0
$form1.Font = New-Object System.Drawing.Font("Microsoft Sans Serif",8.25,0,3,0)
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 359
$System_Drawing_Size.Height = 601
$form1.ClientSize = $System_Drawing_Size
$form1.add_Shown($GetClasses)

$rtbPropertyValues.Text = ''
$rtbPropertyValues.TabIndex = 17
$rtbPropertyValues.Name = 'rtbPropertyValues'
$rtbPropertyValues.ForeColor = [System.Drawing.Color]::FromArgb(255,65,105,225)
$rtbPropertyValues.BackColor = [System.Drawing.Color]::FromArgb(255,255,248,220)
$rtbPropertyValues.BorderStyle = 0
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 134
$System_Drawing_Size.Height = 108
$rtbPropertyValues.Size = $System_Drawing_Size
$rtbPropertyValues.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 213
$System_Drawing_Point.Y = 182
$rtbPropertyValues.Location = $System_Drawing_Point

$form1.Controls.Add($rtbPropertyValues)

$label6.Text = 'Property Values'

$label6.DataBindings.DefaultDataSourceUpdateMode = 0
$label6.TabIndex = 16
$label6.TextAlign = 256
$label6.Name = 'label6'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 100
$System_Drawing_Size.Height = 23
$label6.Size = $System_Drawing_Size
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 205
$System_Drawing_Point.Y = 155
$label6.Location = $System_Drawing_Point

$form1.Controls.Add($label6)

$lblType.Text = 'PropertyType'

$lblType.DataBindings.DefaultDataSourceUpdateMode = 0
$lblType.TabIndex = 15
$lblType.Name = 'lblType'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 134
$System_Drawing_Size.Height = 23
$lblType.Size = $System_Drawing_Size
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 11
$System_Drawing_Point.Y = 293
$lblType.Location = $System_Drawing_Point

$form1.Controls.Add($lblType)

$label4.Text = 'Select properties'

$label4.DataBindings.DefaultDataSourceUpdateMode = 0
$label4.TabIndex = 14
$label4.TextAlign = 256
$label4.Name = 'label4'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 128
$System_Drawing_Size.Height = 23
$label4.Size = $System_Drawing_Size
$label4.ImageAlign = 256
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 11
$System_Drawing_Point.Y = 155
$label4.Location = $System_Drawing_Point

$form1.Controls.Add($label4)

$label3.Text = 'WMI Expression'

$label3.DataBindings.DefaultDataSourceUpdateMode = 0
$label3.ForeColor = [System.Drawing.Color]::FromArgb(255,205,92,92)
$label3.TabIndex = 13
$label3.TextAlign = 256
$label3.Name = 'label3'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 100
$System_Drawing_Size.Height = 23
$label3.Size = $System_Drawing_Size
$label3.Font = New-Object System.Drawing.Font("Consolas",8.25,1,3,1)
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 11
$System_Drawing_Point.Y = 419
$label3.Location = $System_Drawing_Point

$form1.Controls.Add($label3)

$rtbPropertyHelp.Text = ''
$rtbPropertyHelp.TabIndex = 12
$rtbPropertyHelp.Name = 'rtbPropertyHelp'
$rtbPropertyHelp.ForeColor = [System.Drawing.Color]::FromArgb(255,65,105,225)
$rtbPropertyHelp.BackColor = [System.Drawing.Color]::FromArgb(255,255,248,220)
$rtbPropertyHelp.BorderStyle = 0
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 336
$System_Drawing_Size.Height = 97
$rtbPropertyHelp.Size = $System_Drawing_Size
$rtbPropertyHelp.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 11
$System_Drawing_Point.Y = 319
$rtbPropertyHelp.Location = $System_Drawing_Point

$form1.Controls.Add($rtbPropertyHelp)

$rtbClassHelp.Text = ''
$rtbClassHelp.TabIndex = 11
$rtbClassHelp.Name = 'rtbClassHelp'
$rtbClassHelp.ForeColor = [System.Drawing.Color]::FromArgb(255,65,105,225)
$rtbClassHelp.BackColor = [System.Drawing.Color]::FromArgb(255,255,248,220)
$rtbClassHelp.BorderStyle = 0
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 335
$System_Drawing_Size.Height = 65
$rtbClassHelp.Size = $System_Drawing_Size
$rtbClassHelp.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 12
$System_Drawing_Point.Y = 85
$rtbClassHelp.Location = $System_Drawing_Point

$form1.Controls.Add($rtbClassHelp)

$rtbCode.Text = ''
$rtbCode.TabIndex = 10
$rtbCode.Name = 'rtbCode'
$rtbCode.BackColor = [System.Drawing.Color]::FromArgb(255,255,255,255)
$rtbCode.BorderStyle = 1
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 335
$System_Drawing_Size.Height = 81
$rtbCode.Size = $System_Drawing_Size
$rtbCode.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 12
$System_Drawing_Point.Y = 452
$rtbCode.Location = $System_Drawing_Point

$form1.Controls.Add($rtbCode)


$btnRun.UseVisualStyleBackColor = $False
$btnRun.Text = 'Run It!'
$btnRun.backcolor=[System.Drawing.Color]::FromArgb(255,240,240,240)
$btnRun.DataBindings.DefaultDataSourceUpdateMode = 0
$btnRun.TabIndex = 8
$btnRun.Name = 'btnRun'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 75
$System_Drawing_Size.Height = 23
$btnRun.Size = $System_Drawing_Size
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 152
$System_Drawing_Point.Y = 539
$btnRun.Location = $System_Drawing_Point
$btnRun.add_Click($RunIt)

$form1.Controls.Add($btnRun)


$btnQuit.UseVisualStyleBackColor = $False
$btnQuit.Text = 'Cancel'
$btnQuit.backcolor=[System.Drawing.Color]::FromArgb(255,240,240,240)
$btnQuit.DataBindings.DefaultDataSourceUpdateMode = 0
$btnQuit.TabIndex = 7
$btnQuit.Name = 'btnQuit'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 75
$System_Drawing_Size.Height = 23
$btnQuit.Size = $System_Drawing_Size
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 246
$System_Drawing_Point.Y = 539
$btnQuit.Location = $System_Drawing_Point
$btnQuit.add_Click($Quit)

$form1.Controls.Add($btnQuit)


$btnCreate.UseVisualStyleBackColor = $False
$btnCreate.Text = 'Create Command'
$btnCreate.backcolor=[System.Drawing.Color]::FromArgb(255,240,240,240)
$btnCreate.DataBindings.DefaultDataSourceUpdateMode = 0
$btnCreate.TabIndex = 6
$btnCreate.Name = 'btnCreate'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 110
$System_Drawing_Size.Height = 23
$btnCreate.Size = $System_Drawing_Size
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 37
$System_Drawing_Point.Y = 539
$btnCreate.Location = $System_Drawing_Point
$btnCreate.add_Click($CreateCommand)

$form1.Controls.Add($btnCreate)


$btnGetClasses.UseVisualStyleBackColor = $False
$btnGetClasses.Text = 'Get WMI'
$btnGetClasses.backcolor=[System.Drawing.Color]::FromArgb(255,240,240,240)
$btnGetClasses.DataBindings.DefaultDataSourceUpdateMode = 0
$btnGetClasses.TabIndex = 5
$btnGetClasses.Name = 'btnGetClasses'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 75
$System_Drawing_Size.Height = 23
$btnGetClasses.Size = $System_Drawing_Size
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 256
$System_Drawing_Point.Y = 18
$btnGetClasses.Location = $System_Drawing_Point
$btnGetClasses.add_Click($GetClasses)

$form1.Controls.Add($btnGetClasses)

$chkProperties.DataBindings.DefaultDataSourceUpdateMode = 0
$chkProperties.Name = 'chkProperties'
$chkProperties.FormattingEnabled = $True
$chkProperties.Sorted = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 195
$System_Drawing_Size.Height = 109
$chkProperties.Size = $System_Drawing_Size
$chkProperties.TabIndex = 4
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 11
$System_Drawing_Point.Y = 181
$chkProperties.Location = $System_Drawing_Point
$chkProperties.add_SelectedIndexChanged($GetPropertyHelp)

$form1.Controls.Add($chkProperties)

$label1.Text = 'Computer'

$label1.DataBindings.DefaultDataSourceUpdateMode = 0
$label1.TabIndex = 3
$label1.TextAlign = 16
$label1.Name = 'label1'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 58
$System_Drawing_Size.Height = 23
$label1.Size = $System_Drawing_Size
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 11
$System_Drawing_Point.Y = 19
$label1.Location = $System_Drawing_Point

$form1.Controls.Add($label1)

$comboClass.Text = 'Select a class'
$comboClass.Name = 'comboClass'
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 336
$System_Drawing_Size.Height = 21
$comboClass.Size = $System_Drawing_Size
$comboClass.FormattingEnabled = $True
$comboClass.Sorted = $True
$comboClass.TabIndex = 2
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 11
$System_Drawing_Point.Y = 58
$comboClass.Location = $System_Drawing_Point
$comboClass.DataBindings.DefaultDataSourceUpdateMode = 0
$comboClass.add_SelectedIndexChanged($GetProperties)

$form1.Controls.Add($comboClass)

$statusBar1.Name = 'statusBar1'
$statusBar1.DataBindings.DefaultDataSourceUpdateMode = 0
$statusBar1.TabIndex = 1
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 359
$System_Drawing_Size.Height = 22
$statusBar1.Size = $System_Drawing_Size
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 0
$System_Drawing_Point.Y = 579
$statusBar1.Location = $System_Drawing_Point
$statusBar1.Text = 'statusBar1'

$form1.Controls.Add($statusBar1)

$txtComputer.Text = $env:computername
$txtComputer.Name = 'txtComputer'
$txtComputer.TabIndex = 0
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 165
$System_Drawing_Size.Height = 20
$txtComputer.Size = $System_Drawing_Size
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 75
$System_Drawing_Point.Y = 21
$txtComputer.Location = $System_Drawing_Point
$txtComputer.DataBindings.DefaultDataSourceUpdateMode = 0

$form1.Controls.Add($txtComputer)
#endregion Generated Form Code


#Show the Form
If ($form1.ShowDialog() -eq "OK") {
Write-Host "Executing: $wmiWiz" -ForegroundColor cyan
 &$wmiwiz

}
} #End Function

#Call the Function
GenerateForm

# SIG # Begin signature block
# MIIUSwYJKoZIhvcNAQcCoIIUPDCCFDgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUwa2NhxxZUjfyZMenzX+So/uQ
# 5vaggg8OMIIEGjCCAwKgAwIBAgILBAAAAAABIBnBkGYwDQYJKoZIhvcNAQEFBQAw
# VzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNV
# BAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw0wOTAz
# MTgxMTAwMDBaFw0yODAxMjgxMjAwMDBaMFQxGDAWBgNVBAsTD1RpbWVzdGFtcGlu
# ZyBDQTETMBEGA1UEChMKR2xvYmFsU2lnbjEjMCEGA1UEAxMaR2xvYmFsU2lnbiBU
# aW1lc3RhbXBpbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDD
# DLcSDU1oijPeNgXwPLr12s0OU3tGn4LyYhPXwXetu4E3fk8ek4HBBiLaHVCExpeV
# kqmTtj2rhnkZVH0OFgRMxIiXLMahqF8VOtJkK8w+DHropFaxHrvPhM6NNTo0nGwt
# wHe1MKkfZ+Y6CUQ6Q3JBopHDRpoftrmnD68cdRtkJecIbBRH9Uca3o7qomOVffWo
# rVWiZJtyb7kCcz85ijlcxP6P+xGcvRAZSWPQQyKL1quSmXQUzzAHvk+9/YqPnlrf
# bTzMWplQkLmtwpdDwl/tzTM9h8zBoFupYjt4fWSjrE0fK9cDEWxxVIqwq7Ec1n0j
# 20AHNybbUK84PaYHdW+XAgMBAAGjgekwgeYwDgYDVR0PAQH/BAQDAgEGMBIGA1Ud
# EwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFOjC8cQy3DM1N7xldvWcFy4XRSz+MEsG
# A1UdIAREMEIwQAYJKwYBBAGgMgEeMDMwMQYIKwYBBQUHAgEWJWh0dHA6Ly93d3cu
# Z2xvYmFsc2lnbi5uZXQvcmVwb3NpdG9yeS8wMwYDVR0fBCwwKjAooCagJIYiaHR0
# cDovL2NybC5nbG9iYWxzaWduLm5ldC9yb290LmNybDAfBgNVHSMEGDAWgBRge2Ya
# RQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEAXfbLKw0BQISfhXpD
# cGrgxeeqBgDXZxPJCJExZU8UqKkF3DieaqAwCr2Nx4Ao7kJFypTz3lhFqYAyBPVZ
# XGpwADknlE31tEY06BxTMbKzVBbpzEKr1dlZMBz7RicluIcjseh1iCSDHsh2N3sB
# SUVIpO3iXdJ8nKLcLboQWhJiZauuAMcQNDvLcr0UJAzcw3YntKf+4Vgp8g4Wn5E5
# HYmm5g8ch4ziWKySfiQ+quwU5zozNIvGO6yDqw8UYnq6Gi1NSxvFMPALknl9PHjg
# +ObSFZZZmTkrMGHouPjAoekiFBF4fcTcib7Au5Thcq7rtUBAT+8XHlhe0KiJlqyS
# KOm6vzCCBC4wggMWoAMCAQICCwEAAAAAASWwtMwBMA0GCSqGSIb3DQEBBQUAMFQx
# GDAWBgNVBAsTD1RpbWVzdGFtcGluZyBDQTETMBEGA1UEChMKR2xvYmFsU2lnbjEj
# MCEGA1UEAxMaR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EwHhcNMDkxMjIxMDkz
# MjU2WhcNMjAxMjIyMDkzMjU2WjBSMQswCQYDVQQGEwJCRTEWMBQGA1UEChMNR2xv
# YmFsU2lnbiBOVjErMCkGA1UEAxMiR2xvYmFsU2lnbiBUaW1lIFN0YW1waW5nIEF1
# dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM3CPV13ItDC
# fTgywxWDH0JqO1Nm3Wo2RA1pz2iNiUWffi/uQjozfD4A05dq2FrVw02SCl8GUP2/
# bMQDooJg2O1SLhN03pfGRSF7VfbqsWQD/HRrsl/HbGxDFIokEDdJlYHSSBKlonZJ
# UCF/yoVzCjxdtS6tkKpeTTLLF5PZf5bAwIllVtnFsT+YGyf6Se4dG8sGjDAcO8Wn
# cFuoqxha/sj2jr8BXY9hmDQPWFH/3zLqVGUcFCts/AyQGWftm9naY5vWWiSjdI4I
# IwChkrUeC9EIoGZ/khuj7YBkAkmPtoTv0VWOXqmXWsUIAoiUVr+S6yotBjWStTc2
# MezD/no7woUCAwEAAaOCAQEwgf4wHwYDVR0jBBgwFoAU6MLxxDLcMzU3vGV29ZwX
# LhdFLP4wPAYDVR0fBDUwMzAxoC+gLYYraHR0cDovL2NybC5nbG9iYWxzaWduLm5l
# dC9UaW1lc3RhbXBpbmcxLmNybDAdBgNVHQ4EFgQUqqqmiu+kZHPWleJ5yI/qz6Vg
# KcowCQYDVR0TBAIwADAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYB
# BQUHAwgwSwYDVR0gBEQwQjBABgkrBgEEAaAyAR4wMzAxBggrBgEFBQcCARYlaHR0
# cDovL3d3dy5nbG9iYWxzaWduLm5ldC9yZXBvc2l0b3J5LzANBgkqhkiG9w0BAQUF
# AAOCAQEAvIns/uY2VZNcedQReoaAjxe2k7Jtm5GhVhgRxlXq9gjtrZue9SuByLvd
# YHsbR5kebUA+HYDCE9WOBAUv2+euUp5ohHKh5UpgPPib1S9G2MOyt5NTrJtsQyQk
# 0fH86VYuNBFYGEPq7/80dGygwGx/rQMZaYgelWDKu70Mu3bvxySwgcY4Mc82rQw4
# uJAghJsujyi5n/bKlCfNrDlhV+DjlVqcdpIw9d6mlz1yHCpgMqgzTYY1M4pc86T9
# 9wYs4WtLMPXL00Ni+EG53n0gywWMjiz2XzX9M41CiWUINiyjifRahYuwuXvbbMuh
# +NIOG7uXfNEneb6dfDvmp1Y02MmRqTCCBrowggWioAMCAQICCjJROQQAAAABh9ww
# DQYJKoZIhvcNAQEFBQAwXTETMBEGCgmSJomT8ixkARkWA2NvbTEYMBYGCgmSJomT
# 8ixkARkWCFJFT1RyYW5zMRIwEAYKCZImiZPyLGQBGRYCSFExGDAWBgNVBAMTD0Nv
# cnBvcmF0ZUVudENBMTAeFw0xMjEwMTEyMzEzMDlaFw0xNDEwMTEyMzEzMDlaMIGA
# MRMwEQYKCZImiZPyLGQBGRYDY29tMRgwFgYKCZImiZPyLGQBGRYIUkVPVHJhbnMx
# EjAQBgoJkiaJk/IsZAEZFgJIUTEOMAwGA1UECxMFQWRtaW4xDjAMBgNVBAsTBVVz
# ZXJzMRswGQYDVQQDExJBRC1SaWNoYXJkIEhvcGtpbnMwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQD27AmKoyGFD/6XauJSGQ7XwdTz4hSubACTTekfuzNX
# QzWfrfZoZqA8/VRk7yyNVf9hIRCZlE0wk0+/Tg0rMm0VN2B0IEADmY+Xxer7X7fv
# 7HjxEhDKv1rjBsljSJf3HUN4MmukkiMP/F4B3ishtl7UWaqXJwrSMx/WPtCNRCYe
# y+N+z/LjOEEejkkGDLQzbEseEe/RozyYqulcgG86CictrmKGi9gCJg0wHgnIG/Yr
# vJJyowlVj1rkvuO15+W+Tn7DsMuTt0bO3OdKdP3k8fja124P0TNzZsCMqoWRrt/A
# vlrKhbRZ00R8QlrWQrRE8P4cQUiC5a8T6JGeHbHNn5lZAgMBAAGjggNWMIIDUjA9
# BgkrBgEEAYI3FQcEMDAuBiYrBgEEAYI3FQiH7ZJehcTnJofRiTWD17wxgsWha3KG
# 8bQsg6inbwIBZAIBAjATBgNVHSUEDDAKBggrBgEFBQcDAzALBgNVHQ8EBAMCB4Aw
# GwYJKwYBBAGCNxUKBA4wDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUXJz1u82c/k0Y
# FLpTqPpVhhBOYwgwHwYDVR0jBBgwFoAU1AAFxjWIq+MWifUgDOBfVLJd+kEwggEc
# BgNVHR8EggETMIIBDzCCAQugggEHoIIBA4aBv2xkYXA6Ly8vQ049Q29ycG9yYXRl
# RW50Q0ExLENOPWNhY3JwZGMwMSxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1IUSxEQz1SRU9U
# cmFucyxEQz1jb20/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVj
# dENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50hj9odHRwOi8vY2FjcnBkYzAxLmhx
# LnJlb3RyYW5zLmNvbS9DZXJ0RW5yb2xsL0NvcnBvcmF0ZUVudENBMS5jcmwwggEx
# BggrBgEFBQcBAQSCASMwggEfMIG1BggrBgEFBQcwAoaBqGxkYXA6Ly8vQ049Q29y
# cG9yYXRlRW50Q0ExLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxD
# Tj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPUhRLERDPVJFT1RyYW5zLERD
# PWNvbT9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlv
# bkF1dGhvcml0eTBlBggrBgEFBQcwAoZZaHR0cDovL2NhY3JwZGMwMS5ocS5yZW90
# cmFucy5jb20vQ2VydEVucm9sbC9jYWNycGRjMDEuSFEuUkVPVHJhbnMuY29tX0Nv
# cnBvcmF0ZUVudENBMS5jcnQwPQYDVR0RBDYwNKAyBgorBgEEAYI3FAIDoCQMIkFE
# LVJpY2hhcmQuSG9wa2luc0BIUS5SRU9UcmFucy5jb20wDQYJKoZIhvcNAQEFBQAD
# ggEBAKs3K038FhU/JOqQ4qh9Ad1PbxMFJTbswGSbqFfH5uJVwr2L8M4kqr+J7v55
# d0XfXX/bUiRAAIOlchsCtAoJqa/85tCi6v5iVC6okRJDkVAH8ISpcTgFOj8UOsC/
# qKZMXa//OajLtc/OGU62feeYvcAAiYz5rFfq2uR29buVvN3Q/sQnbuIhzPF3A7+9
# ib2xDAe4Sel1TpiEQZdtWNm52jpzZ4aikmiJXt+Z99zwYmmD3sVBB44rDBFyhiRH
# ocBKEBVek/Vfkeu2Ki0TRJH1P15ZHft2GPBeMkSNU6zcee40TuUwBtKlLkGg7LBC
# ofEvhDKX/mFV93aqZIfGdd+lNE0xggSnMIIEowIBATBrMF0xEzARBgoJkiaJk/Is
# ZAEZFgNjb20xGDAWBgoJkiaJk/IsZAEZFghSRU9UcmFuczESMBAGCgmSJomT8ixk
# ARkWAkhRMRgwFgYDVQQDEw9Db3Jwb3JhdGVFbnRDQTECCjJROQQAAAABh9wwCQYF
# Kw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkD
# MQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJ
# KoZIhvcNAQkEMRYEFGwTm3OzIDTS25IZ6qr6byktsobWMA0GCSqGSIb3DQEBAQUA
# BIIBAMx8OrJIdg6kPKzzc/inTyKYhvxmnXcE6K+f1wIVKJvXjwheJZd79Ci3jkBS
# 3F7IwKQLpOJa6J2cE5i9J266CPFHYyOGeUGK7ycH0gY0Qaka70IITJA4LO8Up5fT
# dwNDerlbWlNkCeq0G8ZgCCDRQ4g+mcU4v94a7NuwvWpFSpX30xjS8zb4wuhZnAgz
# tW4u9QkrH3vrJC/SlfhoUWy+rvE1JDTbIOst06IW2L49X3VoaXvrVMGwGLMTORHp
# G3rMF1KqwSfGZcI/xNThfabiC8YlXhGtVtqAyWvYcEkGgBw6xlqyN+LtCkQFRZ/K
# UVMSts8Wa+sXdKc5GaYHs2F71p6hggKXMIICkwYJKoZIhvcNAQkGMYIChDCCAoAC
# AQEwYzBUMRgwFgYDVQQLEw9UaW1lc3RhbXBpbmcgQ0ExEzARBgNVBAoTCkdsb2Jh
# bFNpZ24xIzAhBgNVBAMTGkdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBAgsBAAAA
# AAElsLTMATAJBgUrDgMCGgUAoIH3MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTEyMTExNDAwMDIwOFowIwYJKoZIhvcNAQkEMRYEFPbC
# w7cZFfwJQAzD2/dDDSQ0z1/1MIGXBgsqhkiG9w0BCRACDDGBhzCBhDCBgTB/BBSu
# 3333a7okENZ9uvGPW6FbQX5JbDBnMFikVjBUMRgwFgYDVQQLEw9UaW1lc3RhbXBp
# bmcgQ0ExEzARBgNVBAoTCkdsb2JhbFNpZ24xIzAhBgNVBAMTGkdsb2JhbFNpZ24g
# VGltZXN0YW1waW5nIENBAgsBAAAAAAElsLTMATANBgkqhkiG9w0BAQEFAASCAQCM
# 6Ed4Ef9/gVkMRiE5Me+BcIjDK39M1/PN0mqEweKM5yxcjtBONDId7HM6g2+LP3Dq
# GRpQ5ks1XtffB8SSnRyg33cK93FrIkHF33AhKRNrSocl+YOD2fJleaVtPD1fDRD0
# n/4u0nUGluXgRW+AhyfL+5zSLlB9fGNKGHgiLoHGBnrNNZrLimNxR1mmhK+fZe8f
# giKfnIoiOaLtlg0b92nkiTn+hcnley6k6N4XB3LMvJCsxIM/nTAM/vgCgIJW7BcT
# 1fqNfhz4MkvZDk3I1E1WIoUUUqX+/5F0Ko8b4nRbx+e52mFFqJvQqszTZDgmBhXO
# OM2zcVKOmAwrGY8EP7uW
# SIG # End signature block