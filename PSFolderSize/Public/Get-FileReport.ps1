function Get-FileReport { #Begin function Get-FileReport
    [cmdletbinding(
        DefaultParameterSetName = 'default'
    )]
    param(
        [Parameter(
            Mandatory = $false,
            Position = 0,
            ParameterSetName = 'default'
        )]
        [Alias('Path')]
        [String[]]
        $BasePath = (Get-Location),        

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'default'
            
        )]
        [String[]]
        $FindExtension = @('.exe','.msi'),

        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'default'
            
        )]
        [String[]]
        $FolderName = 'all',

        [Parameter(
            ParameterSetName = 'default'
        )]
        [String[]]
        $OmitFolders,

        [Parameter(
            ParameterSetName = 'default'
        )]
        [Switch]
        $AddTotal,

        [Parameter(
            ParameterSetName = 'default'
        )]
        [Parameter(
            ParameterSetName = 'outputWithType'
        )]
        [ValidateSet('csv','xml','json')]
        [String]        
        $Output,

        [Parameter(
            ParameterSetName = 'default'
        )]
        [Parameter(
            ParameterSetName = 'outputWithType'
        )]
        [String]
        $OutputPath = (Get-Location),

        [Parameter(
            ParameterSetName = 'default'
        )]
        [String]
        $OutputFile = [string]::Empty
    )

    #Get a list of all the directories in the base path we're looking for.
    if ($folderName -eq 'all') {

        $allFolders = Get-ChildItem $BasePath -Force -Recurse | Where-Object {($_.FullName -notin $OmitFolders) -and ($_.Extension -in $FindExtension)}

    }
    else {

        $allFolders = Get-ChildItem $basePath -Force -Recurse | Where-Object {($_.BaseName -like $FolderName) -and ($_.FullName -notin $OmitFolders) -and ($_.Extension -in $FindExtension)}

    }

    $foundFiles = $null

    #Create array to store folder objects found with size info.
    [System.Collections.ArrayList]$fileList = @()

    #Go through each folder in the base path.
    ForEach ($file in $allFolders) {

        #Clear out the variables used in the loop.        
        $fullPath      = $null        
        $folderObject  = $null
        $fileSize      = $null
        $fileSizeInMB  = $null
        $fileSizeInGB  = $null
        $fileName      = $null

        #Store the full path to the folder and its name in separate variables
        $fullPath = $file.FullName
        $fileName = $file.BaseName     

        Write-Verbose "Working with [$fullPath]..."            

        #Get folder info / sizes
        $fileSize = $file.Length 
            
        #We use the string format operator here to show only 2 decimals, and do some PS Math.
        [double]$fileSizeInMB = "{0:N2}" -f ($fileSize / 1MB)
        [double]$fileSizeInGB = "{0:N2}" -f ($fileSize / 1GB)

        #Here we create a custom object that we'll add to the array
        $folderObject = [PSCustomObject]@{

            PSTypeName    = 'PS.File.List.Result'
            FileName      = $fileName
            'Size(Bytes)' = $fileSize
            'Size(MB)'    = $fileSizeInMB
            'Size(GB)'    = $fileSizeInGB
            FullPath      = $fullPath

        }                        

        #Add the object to the array
        $fileList.Add($folderObject) | Out-Null

    }

    if ($AddTotal) {

        $grandTotal = $null

        if ($fileList.Count -gt 1) {
        
            $fileList | ForEach-Object {

                $grandTotal += $_.'Size(Bytes)'    

            }

            [double]$totalFolderSizeInMB = "{0:N2}" -f ($grandTotal / 1MB)
            [double]$totalFolderSizeInGB = "{0:N2}" -f ($grandTotal / 1GB)

            $folderObject = [PSCustomObject]@{

                FileName      = "GrandTotal for [$fullPath]"
                'Size(Bytes)' = $grandTotal
                'Size(MB)'    = $totalFolderSizeInMB
                'Size(GB)'    = $totalFolderSizeInGB
                FullPath      = 'N/A'

            }

            #Add the object to the array
            $fileList.Add($folderObject) | Out-Null
        }   

    }

    if ($Output -or $OutputFile) {

        if (!$OutputFile) {

            $fileName = "{2}\{0:MMddyy_HHmm}.{1}" -f (Get-Date), $Output, $OutputPath

        } else {

            $fileName = $OutputFile
            $Output   = $fileName.Substring($fileName.LastIndexOf('.') + 1) 


        }
    
        Write-Verbose "Attempting to export results to -> [$fileName]!"

        try {

            switch ($Output) {

                'csv' {

                    $fileList | Sort-Object 'Size(Bytes)' -Descending | Export-Csv -Path $fileName -NoTypeInformation -Force

                }

                'xml' {

                    $fileList | Sort-Object 'Size(Bytes)' -Descending | Export-Clixml -Path $fileName

                }

                'json' {

                    $fileList | Sort-Object 'Size(Bytes)' -Descending | ConvertTo-Json | Out-File -FilePath $fileName -Force

                }

            } 
        } 

        catch {

            $errorMessage = $_.Exception.Message

            Write-Error "Error exporting file to [$fileName] -> [$errorMessage]!"

        }
    
    }

    if (!(Get-TypeData -TypeName 'PS.File.List.Result')) {

        #Change the default view
        $typeInfo = @{

            TypeName = 'PS.File.List.Result'
            DefaultDisplayPropertySet = 'FileName', 'Size(MB)', 'Size(GB)','FullPath'

        }

        Update-TypeData @typeInfo

    }

    #Return the object array with the objects selected in the order specified.
    Return $fileList | Sort-Object 'Size(Bytes)' -Descending

} #End function Get-FileReport